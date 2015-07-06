Rebol [
	Title: "Hardball"
	File: %hardball.r
	Type: 'Module
	Purpose: {
		Allows working with remote modules, by calling their exported functions
		via RPC over a TCP connection.
	}
	Author: "Gabriele Santilli"
	License: {
		=================================
		A message from Qtask about this source code:

		We have selected the MIT license (as of 2010-Jan-1) because
		it is the closest “standard” license to our intent.  If we had our way,
		we would declare this source as public domain, with absolutely no
		strings attached, not even the string that says you have to have
		strings.  We want to help people, so please feel free to contact us
		at API@Qtask.com if you have questions.
		

		(you only need to include the standard license text below in your
		homage to this source code)
		=================================

		Copyright 2010 Qtask, Inc.

		Permission is hereby granted, free of charge, to any person obtaining
		a copy of this software and associated documentation files
		(the "Software"), to deal in the Software without restriction, including
		without limitation the rights to use, copy, modify, merge, publish,
		distribute, sublicense, and/or sell copies of the Software, and to
		permit persons to whom the Software is furnished to do so, subject
		to the following conditions:

		The above copyright notice and this permission notice shall be included
		in all copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
		OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
		THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
		OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
		ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
		OTHER DEALINGS IN THE SOFTWARE.
	}
	Version: 1.0.6
	Imports: [
		%parsers/common-rules.r
		%parsers/rule-arguments.r
		%mezz/messages.r
		%mezz/test-trace.r
		%mezz/logging.r
		%mezz/collect.r
		%mezz/form-error.r
	]
	Exports: [
		configure-hardball
		serve-modules
		make-hardball-configuration
		open-hardball-connection
		list-exported-modules
		list-exported-functions
		call-remote-function
	]
]

config!: context [
	public-key: none
	private-key: none
	allowed-peers: []
]

invalid-arg: func [val][
	throw make error! reduce ['script 'invalid-arg :val]
]

with: func [[throw] object code] [do bind code object]

parse-config: func [template config /local cfg word][
	cfg: make template []
	parse config [
		any [
			set word set-word! do-next (
				unless word: in cfg word [
					invalid-arg word
				]
				set word pop-result
				append-test-trace ['config word mold/all get word]
			)
		] [end | here: (invalid-arg here)]
	]
	cfg
]

throw-error: func [args [block! word!]][
	throw make error! join [Hardball] args
]
system/error/hardball: make system/error/hardball [
	Unexpected-Close: ["Connection unexpectedly closed" :arg1]
	Unexpected-Response: ["Unexpected response from peer:" copy/part mold/only :arg1 15]
	Invalid-Arguments: Unknown-Function: Unknown-Module: Unknown-Command: ["Peer says:" :arg1]
]

configure-hardball: func [
	"Set up default values for Harball's configuration" [catch]
	config [block!]
][
	server-config!: parse-config server-config! config
	client-config!: parse-config client-config! config
	none
]

connections: []

log-errors: func [[throw] code cleanup /local error][
	either error? set/any 'error try code [
		append-log 'fatal ["Fatal error:^/" form-error/all disarm error]
		attempt cleanup
		error
	] cleanup
]
server-config!: make config! [
	modules: none
	port-id: 1025
	logging: [only [fatal error info] to output]
]

listen-awake: func [port /local conn error][
	conn: first port
	append-log 'info ["Hello to" conn/remote-ip ":" conn/remote-port]
	append-test-trace 'got-connection
	conn/locals: context [
		session: make-messages-session
		buffer: copy #{}
	]
	conn/awake: :server-awake
	if error? error: try [
		append-test-trace 'greeting
		greet-messages-peer conn conn/locals/session configuration
		append connections conn
	][
		append-test-trace 'error-sending-greeting
		append-log 'error ["Error sending greeting, closing connection:" form-error disarm error]
		attempt [close conn]
	]
	false
]

server-awake: func [port /local data message error][
	unless data: attempt [copy port] [
		append-log 'info ["Goodbye to" port/remote-ip ":" port/remote-port]
		append-test-trace 'client-close
		close port
		remove find connections port
		return false
	]
	with port/locals [
		append buffer data
		if error? error: try [
			while [message: receive-message buffer session] [
				append-test-trace 'got-message
				if handle-message port session message [
					append-test-trace ['handle-message 'returned 'true]
					return true
				]
			]
		][
			append-test-trace ['error 'during 'receive-message 'or 'handle-message]
			append-log 'error ["Error while receiving/handling message:" form-error disarm error]
			append-log 'info ["Closing connection with" port/remote-ip ":" port/remote-port]
			attempt [close port]
			remove find connections port
		]
	]
	false
]

parse-server-config: func [config /local cfg here word][
	append-test-trace 'parsing-config
	switch type?/word config [
		file! url! [
			append-test-trace 'config-is-one-module
			make server-config! [
				modules: prepare-module load-module config
			]
		]
		object! [
			unless module? config [
				invalid-arg config
			]
			append-test-trace 'config-is-one-module-object
			make server-config! [
				modules: config
			]
		]
		block! [
			append-test-trace 'config-is-block
			cfg: make server-config! []
			parse config [
				some [
					file! opt ['as file!]
					|
					url! 'as file!
					|
					word! 'as file!
				][
					end (append-test-trace 'config-is-list-of-modules cfg/modules: config)
					|
					here: (invalid-arg here)
				]
				| (append-test-trace 'config-is-setting-values)
				any [
					set word set-word! do-next (
						unless word: in cfg word [
							invalid-arg word
						]
						set word pop-result
						append-test-trace ['config word mold/all get word]
					)
				] [end | here: (invalid-arg here)]
			]
			switch/default type?/word cfg/modules [
				file! url! [
					append-test-trace 'modules-is-one-file
					cfg/modules: prepare-module load-module cfg/modules
				]
				object! [
					append-test-trace 'modules-is-one-module
					unless module? cfg/modules [invalid-arg cfg/modules]
				]
				block! [
					append-test-trace 'modules-is-a-block
					cfg/modules: parse-module-list cfg/modules
				]
			][
				invalid-arg cfg/modules
			]
			unless integer? cfg/port-id [invalid-arg cfg/port-id]
			cfg
		]
	]
]

parse-module-list: func [modules /local mod name][
	append-test-trace 'parsing-module-list
	collect [
		parse modules [
			some [
				set mod file! [
					'as set name file! (
						append-test-trace ['file mod 'as name]
						keep name
						keep prepare-module load-module mod
					)
					| (
						append-test-trace ['file mod 'as mod]
						keep mod
						keep prepare-module load-module mod
					)
				]
				|
				set mod url! 'as set name file! (
					append-test-trace ['url mod 'as name]
					keep name
					keep prepare-module load-module mod
				)
				|
				set mod word! 'as set name file! (
					append-test-trace ['word mod 'as name]
					unless module? get/any mod [invalid-arg mod]
					keep name
					keep prepare-module get mod
				)
				|
				here: skip (invalid-arg here)
			]
		]
	]
]

prepare-module: func [module][
	make module [
		callable: use first export-ctx reduce ['bind? to lit-word! first first export-ctx]
		foreach word bind first callable export-ctx [
			if function? get word [set in callable word prepare-function get word]
		]
	]
]

prepare-function: func [f /local spec types ref?][
	make function! collect [
		spec: third :f
		ref?: no
		foreach word first :f [
			if word = /local [break]
			keep to get-word! word
			either refinement? word [
				keep/only [logic! none!]
				ref?: yes
			][
				if block? types: select spec word [
					keep/only either ref? [join types none!] [types]
				]
			]
		]
		if local: find first :f /local [keep local]
	] second :f
]

keep-module: func [name module][
	keep name
	keep/only compose/only [
		Title: (module/title)
		Author: (get in module 'author)
		Version: (get in module 'version)
		Purpose: (module/purpose)
		Exports: (module/exports)
		Globals: (module/globals)
	]
]

handle-message: func [port [port!] session [object!] message [block!] /local module function arguments mod f args res][
	append-test-trace 'handling-message
	append-log 'debug ["Handle message: state:" session/state "message:" mold/only message]
	switch/default session/state [
		data [
			parse message [
				'list set module file! (
					append-test-trace ['list module]
					mod: either block? configuration/modules [
						select configuration/modules module
					][
						configuration/modules
					]
					send-message port session either mod [
						collect [
							keep 'Module keep module keep 'Exports
							foreach word bind first mod/export-ctx mod/export-ctx [
								if function? function: get word [
									keep word
									keep/only copy/part args: third :function any [
										find args /local
										tail args
									]
								]
							]
						]
					] [[Error Unknown-Module "I don't have that module here"]]
				)
				|
				'list (
					append-test-trace ['list 'modules]
					send-message port session collect [
						keep [Modules List]
						either block? configuration/modules [
							foreach [name module] configuration/modules [
								keep-module name module
							]
						][
							keep-module none configuration/modules
						]
					]
				)
				|
				'call set module file! set function word! arguments: to end (
					append-test-trace ['call module function mold/all copy arguments]
					mod: either block? configuration/modules [
						select configuration/modules module
					][
						configuration/modules
					]
					send-message port session either mod [
						append-test-trace 'module-ok
						either f: in mod/callable function [
							either function? f: get f [
								append-test-trace 'function-ok
								args: first :f
								either equal? length? arguments -1 + index? any [find args /local tail args] [
									append-test-trace 'arguments-ok
									either error? set/any 'res try append reduce [:f] arguments [
										append-test-trace 'error-thrown
										res: disarm res
										res/near: none
										res/where: none
										if all [res/type = 'script res/id = 'expect-arg] [
											res/arg1: function
											res/arg2: to word! res/arg2
										]
										reduce ['Error 'Rebol-Error res]
									][
										append-test-trace 'call-ok
										reduce ['Result module function get/any 'res]
									]
								][
									append-test-trace 'invalid-arguments [Error Invalid-Arguments "Invalid argument list for that function"]
								]
							][
								append-test-trace 'unknown-function [Error Unknown-Function "The module does not export that function"]
							]
						][
							append-test-trace 'unknown-function [Error Unknown-Function "The module does not export that function"]
						]
					][
						append-test-trace 'unknown-module [Error Unknown-Module "I don't have that module here"]
					]
				)
				|
				'quit (
					append-test-trace 'quit
					return true
				)
				| (
					append-test-trace 'unknown-command
					append-log 'error ["Unknown command:" copy/part mold/only message 30]
					send-message port session [Error Unknown-Command "I don't know what you're talking about"]
				)
			]
		]
	][
		append-test-trace 'still-handshake
		message: handle-handshake-message session configuration message
		if block? message [
			append-test-trace 'sending-handshake-response
			send-message port session message
		]
	]
	false
]

serve-modules: func [
	{Start the Hardball server, giving access to the given modules} [catch]
	config [file! object! url! block!] {Module or list of modules to export over the network, or list of configuration values}
][
	configuration: parse-server-config config
	setup-logging configuration/logging
	append-log 'info ["Hardball server starting"]
	append-log 'debug [
		"Exporting" either block? configuration/modules [
			divide length? configuration/modules 2
		] [1] "module(s)"
	]
	append-log 'debug ["Public key:^/" mold configuration/public-key]
	append-log 'debug ["Allowed peers:^/" mold/only configuration/allowed-peers]
	log-errors [
		append-log 'debug ["Listening to port" configuration/port-id]
		listen: open/binary/no-wait [scheme: 'tcp port-id: configuration/port-id]
		append-test-trace 'listening
		connections: reduce [listen]
		listen/awake: :listen-awake
		wait connections
	][
		append-log 'info ["Hardball server shutting down"]
		append-test-trace 'quitting
		foreach connection connections [attempt [close connection]]
		clear connections
	]
	none
]
make Root-Protocol [
	port-flags: system/standard/port-flags/pass-thru
	open: func [port][
		setup-logging client-config!/logging
		port/sub-port: open-hardball-connection make client-config! [] [
			scheme: 'tcp
			host: port/host
			port-id: port/port-id
		]
		port/state/tail: 1
		port/state/index: 0
		port/state/flags: port/state/flags or port-flags
	]
	close: func [port][
		close* port/sub-port
	]
	copy: func [port /local module][
		generate-stub-module
		list-exported-functions port/sub-port module: append to file! any [port/path ""] port/target
		port/host port/port-id module
	]
	net-utils/net-install Hardball self 1025
]
client-config!: make config! [
	logging: [only [print-at-all-costs] to output]
]

send-and-receive: func [port message /local data][
	with port/locals [
		send-message port session message
		forever [
			wait port
			unless data: copy port [
				throw-error ['Unexpected-Close "(expecting response)"]
			]
			append buffer data
			if message: receive-message buffer session [
				return message
			]
		]
	]
]
close*: :close
generate-stub-module: func [function-list server-host server-port-id module-name /local arg-name][
	collect [
		keep 'Rebol
		keep/only compose/only [
			Type: Module
			Imports: [%schemes/hardball.r]
			Exports: (extract function-list 2)
		]
		keep [
			_config: make-hardball-configuration []
			_port: open-hardball-connection _config _server-url:
		]
		keep join tcp:// [server-host #":" server-port-id]
		foreach [name spec] function-list [
			keep to set-word! name
			keep 'func
			keep/only spec
			keep/only compose/only [
				unless attempt [copy _port] [
					attempt [close _port]
					_port: open-hardball-connection _config _server-url
				]
				call-remote-function _port (module-name) (
					collect [
						keep name
						parse spec [
							any [string! | block!]
							some [
								set arg-name [word! | refinement!]
								any [string! | block!] (keep to get-word! arg-name)
							]
						]
					]
				)
			]
		]
	]
]

make-hardball-configuration: func [
	"Return a Hardball client configuration object" [catch]
	config [block!]
][
	parse-config client-config! config
]

open-hardball-connection: func [
	"Open a connection to a Hardball server" [catch]
	config [object!] "Client configuration object"
	server [url! port! block!] "TCP URL or port spec"
	/local
	data message
][
	server: open/binary/no-wait server
	with server/locals: context [
		buffer: copy #{}
		session: make-messages-session
		session/role: 'client
		session/max-block-length: 1024 * 1024
		configuration: config
	][
		greet-messages-peer server session configuration
		forever [
			wait server
			unless data: copy server [
				throw-error ['Unexpected-Close "during handshake"]
			]
			append buffer data
			while [message: receive-message buffer session] [
				message: handle-handshake-message session configuration message
				if message = true [break]
				if block? message [
					send-message server session message
				]
			]
			if message = true [break]
		]
	]
	server
]

list-exported-modules: func [
	"List the modules exported by the server" [catch]
	server [port!] "Connection to the Hardball server"
	/local
	list
][
	parse send-and-receive server [List] [
		'Modules 'List list: (return list)
		|
		list: (throw-error ['Unexpected-Response list])
	]
]

list-exported-functions: func [
	"List the functions exported by a remote module" [catch]
	server [port!] "Connection to the Hardball server"
	module [file!] "Module name"
	/local
	list
][
	parse send-and-receive server reduce ['List module] [
		'Module module 'Exports list: (return list)
		|
		list: (throw-error ['Unexpected-Response list])
	]
]

call-remote-function: func [
	"Call a function in a module on a Hardball server" [catch]
	server [port!] "Connection to the Hardball server"
	module [file!] "Module name"
	block [block!] {Function name followed by arguments (will be reduced)}
	/local
	function result
][
	unless parse block [word! to end] [
		invalid-arg block
	]
	function: to lit-word! block/1
	parse send-and-receive server compose [
		Call (module) (block/1) (reduce next block)
	][
		'Result module function set result skip
		|
		'Error 'Rebol-Error set result object! (
			throw make error! next next second result
		)
		|
		'Error copy result [[
				'Invalid-Arguments
				|
				'Unknown-Function
				|
				'Unknown-Module
				|
				'Unknown-Command
			]
			string!
		] (throw-error [result/1 result/2])
		|
		result: (throw-error ['Unexpected-Response result])
	]
	get/any 'result
]
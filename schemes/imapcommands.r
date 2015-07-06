Rebol [
	Title: "imapcommands:// protocol handler"
	File: %imapcommands.r
	Type: 'Module
	Purpose: {
		This program defines the protocol handler for Rebol's imapcommands://
		protocol scheme. The handler allows connecting to a IMAP server and
		communicating with it via an IMAP dialect. This allows full access to
		IMAP's features.
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

		Copyright 2009 Qtask, Inc.

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
	Version: 1.0.0
	Imports: [
		%parsers/imap-parser.r
		%mezz/collect.r
	]
]

pick*: :pick
insert*: :insert
set-modes*: :set-modes
read-line: func [port /local line][
	if line: pick* port/sub-port 1 [
		net-utils/net-log line
		parse-imap-line line port/sub-port
	]
]

send-command: func [port command [block!]][
	command: form-imap reduce [rejoin ["A" port/locals/tagid " "]] command
	net-utils/net-log command
	port/locals/tagid: port/locals/tagid + 1
	foreach line command [
		if binary? line [
			if not parse read-line port ['+ to end] [net-error "Server error: IMAP server not ready"]
			set-modes* port/sub-port [lines: false binary: true]
		]
		insert* port/sub-port line
		if binary? line [
			set-modes* port/sub-port [binary: false lines: true]
		]
	]
]
imap-do-cram-md5: func [port server-data /local send-data][
	server-data: debase/base server-data 64
	send-data: reform [
		port/user
		lowercase enbase/base checksum/method/key server-data 'md5 port/pass 16
	]
	send-data: enbase/base send-data 64
	net-utils/net-log send-data
	insert* port/sub-port send-data
]
make Root-Protocol [
	port-flags: system/standard/port-flags/pass-thru
	open: func [port /local resp auth-done][
		port/locals: context [
			tagid: 1
			capabilities: none
		]
		either port/scheme = 'IMAPScommands [
			open-proto/secure/sub-protocol port 'ssl
		][
			open-proto port
		]
		resp: read-line port
		auth-done: parse resp ['* 'PREAUTH to end]
		if not auth-done [
			send-command port [CAPABILITY]
			either parse copy port [
				into ['* 'CAPABILITY resp: to end]
				into [word! 'OK opt block! string!]
			][
				port/locals/capabilities: copy* resp
			][
				port/locals/capabilities: [AUTH=CRAM-MD5]
			]
			if find port/locals/capabilities 'AUTH=CRAM-MD5 [
				send-command port [AUTHENTICATE CRAM-MD5]
				if parse read-line port ['+ set resp string!] [
					imap-do-cram-md5 port resp
					if parse last copy port [word! 'OK opt block! string!] [
						auth-done: yes
					]
				]
			]
		]
		if not auth-done [
			send-command port compose [LOGIN (form port/user) (form port/pass)]
			if parse last copy port [word! 'OK opt block! string!] [
				auth-done: yes
			]
		]
		if not auth-done [
			net-error "No authentication method available"
		]
		port/state/tail: 1
	]
	close-check: ["Q1 LOGOUT" none]
	insert: func [port value [block!]][
		send-command port value
	]
	pick: func [port][
		read-line port
	]
	copy: func [port /local resp][
		collect [
			while [parse resp: read-line port ['* to end]] [keep/only resp]
			if 'OK <> second resp [
				net-error reform ["Server error: IMAP" next resp]
			]
			keep/only resp
		]
	]
	net-utils/net-install IMAPcommands self 143
	net-utils/net-install IMAPScommands self 993
]
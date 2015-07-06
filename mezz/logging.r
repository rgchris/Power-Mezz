Rebol [
	Title: "Logging functions"
	File: %logging.r
	Type: 'Module
	Purpose: {
		Handles logging messages to standard output, a file, or the system
		log (on Unix).
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
	Version: 1.0.1
	Imports: [
		%mezz/collect.r
	]
	Exports: [
		setup-logging
		append-log
	]
]

filters: none
log-file: none
default-facility: 'daemon
class-map: context []

identity: "Rebol"
append-log*: append-stdout: func [class message][
	prin [now class] prin ": "
	print message
]

append-file: func [class message][
	write/append/lines log-file rejoin [
		now #" " class ": " reform message
	]
]
obj2rule: func [obj][
	obj: next first obj
	collect [
		keep to lit-word! first obj
		foreach w next obj [
			keep '| keep to lit-word! w
		]
	]
]

syslog-priorities: context [
	emergency: 0
	alert: 1
	critical: 2
	error: 3
	warning: 4
	notice: 5
	info: 6
	debug: 7
]

syslog-priority: obj2rule syslog-priorities
syslog-facilities: context [
	kernel: 0
	user: 8
	mail: 16
	daemon: 24
	auth: 32
	printer: 48
	news: 56
	uucp: 64
	cron: 72
	authpriv: 80
	ftp: 88
]

syslog-facility: obj2rule syslog-facilities
load-syslog: does [
	libc: any [attempt [load/library %libc.so] attempt [load/library %libc.so.6]]
	unless libc [make error! "Unable to load libc.so"]
	openlog: make routine! [
		ident [string!]
		option [integer!]
		facility [integer!]
	] libc "openlog"
	syslog: make routine! [
		priority [integer!]
		format [string!]
		class [string!]
		message [string!]
	] libc "syslog"
]

mk-ctx: func [block][
	use block reduce ['bind? 'first block]
]

append-syslog: func [class message /local priority][
	priority: any [
		get in class-map class
		syslog-priorities/info
	]
	class: form class
	message: reform message
	syslog priority "%s: %s" class message
]

setup-logging: func [
	"Change logging configuration"
	config [block!]
	/local
	class facility priority
][
	parse config [[
			'all (filters: none)
			|
			'only set filters into [some word!] (filters: mk-ctx filters)
		]
		'to [
			'output (append-log*: :append-stdout)
			|
			set log-file file! (append-log*: :append-file)
			|
			'syslog any [
				'as set identity string!
				|
				'default set default-facility syslog-facility
				|
				'map into [(class-map: copy [])
					some [
						set class set-word! [
							set priority syslog-priority (repend class-map [class get in syslog-priorities priority])
							|
							into [set facility syslog-facility set priority syslog-priority] (
								repend class-map [
									class (get in syslog-facilities facility) +
									get in syslog-priorities priority
								]
							)
						]
					] (class-map: context class-map)
				]
			] (
				unless value? 'libc [load-syslog]
				openlog identity 1 get in syslog-facilities default-facility
				append-log*: :append-syslog
			)
		]
	]
]

append-log: func [
	"Append a text message to the log"
	class [word!] "Message class (eg. info, error, debug...)"
	message [block!] "Message (will be REFORMed)"
][
	if any [
		not filters
		in filters class
	][
		append-log* class message
	]
]
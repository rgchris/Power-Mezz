Rebol [
	Title: {Common code for "daemons" on Linux}
	File: %linux-daemon.r
	Type: 'Module
	Purpose: {
		Contains all the common code for "daemon" programs on Linux.
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
	Version: 1.0.0
	Imports: [
		%mezz/logging.r
	]
	Exports: [
		start-daemon
	]
]

if not port? system/ports/system [
	system/ports/system: open system://
]
handler!: context [
	title: "Daemon"
	logging: [all to output]
	on-init: none
	on-wakeup: none
	on-quit: none
	on-child-termination: none
	pid-file: none
	wait-loop: none
]

start-daemon: func [
	"Handle signals and basic daemon functionality"
	handlers [block! object!] "Handler functions and other settings"
][
	if block? handlers [handlers: make handler! handlers]
	set-modes system/ports/system [
		signal: [SIGINT SIGTERM SIGUSR1 SIGQUIT]
	]
	setup-logging handlers/logging
	append-log 'info [handlers/title "starting up..."]
	system/ports/system/awake: func [port /local result message pid][
		result: false
		while [message: pick port 1] [
			parse message [
				'signal [
					'SIGUSR1 (
						append-log 'info ["Received SIGUSR1. Process is alive."]
						handlers/on-wakeup
					)
					|
					'SIGINT (
						append-log 'info ["Received SIGINT. Quitting."]
						quit
					)
					| ['SIGTERM | 'SIGQUIT] (
						append-log 'info ["Received " uppercase form message/2 ". Quitting nicely."]
						handlers/on-quit
						if handlers/pid-file [delete handlers/pid-file]
						result: true
					)
				]
				|
				'child set pid integer! integer! (
					handlers/on-child-termination pid
				)
			]
		]
		result
	]
	if file? handlers/pid-file [
		save handlers/pid-file first load/next %/proc/self/stat
	]
	handlers/on-init
	either get in handlers 'wait-loop [
		insert tail system/ports/wait-list system/ports/system
		handlers/wait-loop
	][
		forever [
			if port? wait [system/ports/system 10] [exit]
			system/ports/system/awake system/ports/system
		]
	]
]
Rebol [
	Title: "Chain port scheme for Rebol"
	File: %chain.r
	Purpose: {
		Implements chain://, a port scheme that allows chaining other (filter) ports together
		so that they are seen as a single port.
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

		Copyright 2008 Qtask, Inc.

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
]

net-utils/net-install 'chain make Root-Protocol [
	propagate-data: func [ports data /local filtered][
		while [not tail? next ports] [
			if filtered: copy ports/1 [
				insert ports/2 filtered
			]
			ports: next ports
		]
		ports: head ports
		insert ports/1 data
	]
	update-all: func [ports /local data][
		while [not tail? next ports] [
			system/words/update ports/1
			if data: copy ports/1 [
				insert ports/2 data
			]
			ports: next ports
		]
		system/words/update ports/1
	]
	init: func [port spec][
		if url? spec [
			net-error "Cannot make a chain port from url!"
		]
		port/url: spec
		unless all [block? port/sub-port 1 < length? port/sub-port] [
			net-error {You must specify a list of ports to stream the data through}
		]
	]
	open: func [port][
		port/state/flags: port/state/flags or system/standard/port-flags/direct
	]
	close: func [port][
		port
	]
	write: func [port data][
		propagate-data port/sub-port copy/part data port/state/num
		port/state/num
	]
	read: func [port data][
		read-io last port/sub-port data port/state/num
	]
	update: func [port][
		update-all port/sub-port
	]
] 80
Rebol [
	Title: {"Tee" port scheme for Rebol}
	File: %tee.r
	Purpose: {
		Implements tee://, a port scheme that allows sending a stream to two destinations
		at the same time.
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

net-utils/net-install 'tee make Root-Protocol [
	init: func [port spec][
		port/url: spec
		if url? spec [
			spec: to file! skip spec 4
			if find/match spec %// [remove spec]
			port/sub-port: spec
		]
		if none? port/sub-port [
			net-error "You must specify a sub port to write to"
		]
	]
	open: func [port][
		port/locals: context [
			buffer: make binary! 1024
			close?: no
		]
		if file? port/sub-port [
			port/locals/close?: yes
			port/sub-port: system/words/open/binary/direct/write/new port/sub-port
		]
		port/state/flags: port/state/flags or system/standard/port-flags/direct
	]
	close: func [port][
		if port/locals/close? [
			system/words/close port/sub-port
			port/sub-port: join port/sub-port/path port/sub-port/target
		]
		port/locals: none
	]
	write: func [port data /local
		len
	][
		set/any 'len write-io port/sub-port data port/state/num
		unless value? 'len [len: port/state/num]
		insert/part tail port/locals/buffer data len
		len
	]
	read: func [port data /local
		len
	][
		len: min length? port/locals/buffer port/state/num
		insert/part tail data port/locals/buffer len
		remove/part port/locals/buffer len
		len
	]
	update: func [port][
		attempt [system/words/update port/sub-port]
	]
] 80
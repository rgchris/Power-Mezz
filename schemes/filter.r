Rebol [
	Title: "Filter port scheme for Rebol"
	File: %filter.r
	Purpose: {
		Implements filter://, a port scheme that allows filtering a stream of data thru
		a function.
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

net-utils/net-install 'filter make Root-Protocol [
	filter-block: func [output data f block-length /local len][
		either block-length > 0 [
			len: length? data
			if len >= block-length [
				len: len - (len // block-length)
				insert tail output f take/part data len
			]
		][
			block-length: negate block-length
			while [block-length <= length? data] [
				insert tail output f take/part data block-length
			]
		]
	]
	read-data: func [output input len][
		len: min len length? input
		insert/part tail output input len
		remove/part input len
		len
	]
	init: func [port spec][
		port/locals: context [
			function: block-length: inbuf: outbuf: none
		]
		port/url: spec
		either url? spec [
			parse spec ["filter:" 0 2 #"/" spec:]
			spec: to word! spec
			port/locals/function: get spec
		][
			port/locals: make port/locals spec
		]
		unless any-function? get in port/locals 'function [
			net-error "You must specify a function for filtering"
		]
	]
	open: func [port][
		port/locals/inbuf: make binary! 1024
		port/locals/outbuf: make binary! 1024
		port/state/flags: port/state/flags or system/standard/port-flags/direct
	]
	close: func [port][
		port/locals/inbuf: none
		port/locals/outbuf: none
	]
	write: func [port data][
		either integer? port/locals/block-length [
			insert/part tail port/locals/inbuf data port/state/num
			filter-block port/locals/outbuf port/locals/inbuf get in port/locals 'function port/locals/block-length
		][
			insert tail port/locals/outbuf port/locals/function copy/part data port/state/num
		]
		port/state/num
	]
	read: func [port data][
		read-data data port/locals/outbuf port/state/num
	]
	update: func [port][
		unless empty? port/locals/inbuf [
			insert tail port/locals/outbuf port/locals/function port/locals/inbuf
			clear port/locals/inbuf
		]
	]
] 80
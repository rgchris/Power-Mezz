Rebol [
	Title: "The PIPE function"
	File: %pipe.r
	Purpose: {
		Defines the PIPE function that works as a pipe between two ports, streaming data
		from the first to the second.
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

pipe: func [
	{Create a pipe between two ports and stream all data from source to dest} [catch]
	source [port! file! url!]
	dest [port! file! url!]
	/thru filter [port! url!]
	/part size [integer!]
	/with chunk-size [integer!]
	/local
	condition body
	close-source? close-dest? close-filter?
	data filtered
][
	chunk-size: any [chunk-size 256 * 1024]
	unless any [not size size > 0] [throw make error! compose [script invalid-arg (join size " (size must be greater than zero)")]]
	unless chunk-size > 0 [throw make error! compose [script invalid-arg (join chunk-size " (chunk-size must be greater than zero)")]]
	unless port? source [
		source: open/binary/direct/read source
		close-source?: yes
	]
	unless port? dest [
		dest: open/binary/direct/write/new dest
		close-dest?: yes
	]
	if url? filter [
		filter: open/binary filter
		close-filter?: yes
	]
	condition: either size [[size > 0]] [[data: copy/part source chunk-size]]
	body: compose [(either size [[
					data: copy/part source min size chunk-size
					either data [size: size - length? data] [break]
				]] [[]]) (either filter [[
					if filtered: copy filter [insert dest filtered]
					insert filter data
				]] [[
					insert dest data
				]])]
	while condition body
	if filter [
		update filter
		if data: copy filter [insert dest data]
	]
	attempt [update dest]
	case/all [
		close-source? [close source]
		close-dest? [close dest]
		close-filter? [close filter]
	]
]
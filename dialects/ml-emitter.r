Rebol [
	Title: "Macros to emit [X][HT]ML"
	File: %ml-emitter.r
	Type: 'Module
	Purpose: {
		Defines EMIT macros to generate XML, HTML etc.
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
	Version: 1.4.1
	Imports: [
		%dialects/emit.r
		%parsers/rule-arguments.r
		%parsers/common-rules.r
	]
	Exports: [
		tag text tag-attribute set-ml-encoding cdata
		layout style
	]
]

encoding: 'html-ascii

set-ml-encoding: func [new-encoding [word!]][
	if find [html-ascii html-utf8] new-encoding [encoding: new-encoding]
]

tag-attribute: macro [
	name
	value
][
	#" " either any [path? name set-path? name] [name/1 #":" name/2] [name] {="} either block? :value :value [text :value] #"^""
]

tag-attributes: macro/custom [
	name value
][
	some [
		set name [set-word! | set-path!]
		do-next (if value: pop-result [emit output [tag-attribute name :value]])
		|
		set name [word! | path!]
		set value skip (if value [emit output [tag-attribute name :value]])
	]
]

tag: macro [
	"Emit a tag"
	name
	attributes [block!]
	contents [word! block!] "'open, 'close, 'empty, or block with contents"
	/options
	custom-attributes [logic!]
][
	#"<" if contents = 'close #"/" either path? name [name/1 #":" name/2] [name]
	either custom-attributes [emit attributes] [apply 'tag-attributes attributes]
	if contents = 'empty " /" #">"
	if block? contents [
		emit contents
		tag name [] 'close
	]
]

text: macro [
	"Emit text"
	text
][
	encode-text (form :text) encoding
]

cdata: macro [
	"Emit a CDATA section"
	contents [word! block!] "'open, 'close, or block with contents"
	/options
	commented "Use /* */ comments"
][
	either block? contents [
		either commented [
			cdata/options 'open [commented: yes]
			emit contents
			cdata/options 'close [commented: yes]
		][
			cdata 'open
			emit contents
			cdata 'close
		]
	][
		if commented ["^//* "]
		either contents = 'open [
			"<![CDATA["
		][
			"]]>"
		]
		if commented [" */^/"]
	]
]

style: macro [
	"Emit a <style> tag"
	attributes [block!]
	contents [none! block! string!]
][
	tag 'style attributes switch type?/word contents [
		none! ['empty]
		block! [[emit contents]]
		string! [[cdata/options [(trim/auto copy contents)] [commented: yes]]]
	]
]

span?: func [layspec x y char /local x-span y-span tmp][
	x-span: y-span: 1
	while [layspec/:y/(x + x-span) = char] [x-span: x-span + 1]
	while [all [tmp: layspec/(y + y-span) tmp/:x = char]] [y-span: y-span + 1]
	as-pair x-span y-span
]

make-table: func [spec /local layspec charmap word char style table width height row used][
	charmap: copy []
	layspec: copy []
	parse spec [
		some [
			'repeat set word word! do-next (
				append/only layspec reduce [word make-table pop-result]
			)
			|
			set row string! (append layspec row)
		]
		some [
			set word set-word! copy char some char! copy style any string! (
				foreach ch char [
					insert/only insert tail charmap ch reduce [word style]
				]
			)
		]
	]
	height: length? layspec
	width: 0
	foreach str layspec [if string? str [width: max width length? str]]
	table: make block! 2 + height
	row: head insert/dup clear [] none width
	foreach r layspec [
		append/only table either string? r [copy row] [r]
	]
	used: clear []
	repeat y height [
		if string? layspec/:y [
			repeat x width [
				char: layspec/:y/:x
				unless find used char [
					append used char
					set [word style] select charmap char
					table/:y/:x: reduce [word span? layspec x y char style]
				]
			]
		]
	]
	table
]

cell-contents: 1 cell-span: 2 cell-style: 3

repeat-rows: macro [cells name table /local words block repeated-cells i: -1] [(
		parse cells [
			thru name 'foreach do-next do-next do-next (
				repeated-cells: pop-result
				block: pop-result
				words: pop-result
			)
			| (make error! "Invalid layout cells spec")
		] []
	)
	foreach words block compose/only [
		make-rows table (repeated-cells) i: i + 1
	]
]

make-rows: macro [
	table cells i
][
	foreach 'row table [
		either word? row/1 [
			repeat-rows cells to set-word! row/1 row/2
		][
			tag 'tr [] [
				foreach 'cell row [
					if cell [
						tag 'td [
							colspan: cell/:cell-span/x
							rowspan: cell/:cell-span/y
							class: if cell/:cell-style [cell/:cell-style/(i // (length? cell/:cell-style) + 1)]
						] any [select cells cell/:cell-contents []]
					]
				]
			]
		]
	]
]

layout: macro [
	"Layout using a HTML table"
	spec [block!]
	cells [block!]
	/local table table-style table-class
][
	(parse spec [any ['style set table-style string! | 'class set table-class string!] spec:] table: make-table spec [])

	tag 'table [style: table-style class: table-class] [
		tag 'tbody [] [
			make-rows table cells 0
		]
	]
]
Rebol [
	Title: "[X][HT]ML Parser"
	File: %ml-parser.r
	Type: 'Module
	Name: 'parsers.ml-parser
	Purpose: "^/        Parses XML, XHTML and HTML.^/    "
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
	Version: 1.1.2
	Needs: [
		%parsers/common-rules.r
		%mezz/text-encoding.r ; "For decoding of HTML entities"
	]
	Exports: [
		parse-ml "Parse *ML text"
	]
	Globals: [
		load-markup {Made global because it's a useful LOAD/MARKUP replacement}
	]
]

probe 'parsers.ml-parser

cb: none

html-rule: [
	some [
		comment | declaration | cdata | proc |
		script-style | end-tag | start-empty-tag | text
	]
]

comment: [copy txt ["<!--" thru "-->"] (cb 'comment txt)]

declaration: [copy txt ["<!doctype" space-char thru #">"] (cb 'declaration txt)]

cdata: ["<![CDATA[" copy txt to "]]>" 3 skip (cb 'text any [txt copy ""])]

value-chars: union letter+ charset "/:@%#?,+&=;"
broken-value-chars: union letter+ charset "/:@%#?,+&; "
garbage: union value-chars charset {"'}
text-char: complement charset "< ^/^-"
proc: [copy txt ["<?" name thru "?>"] (cb 'xml-proc txt)]

start-empty-tag: [
	#"<"
	copy nm [name opt [#":" name]] any space-char (attributes: make block! 16) any [attribute | some garbage] [
		"/>" (cb head insert insert make tag! 3 + length? nm nm #"/" attributes)
		|
		#">" (cb to tag! nm attributes)
		|
		pos: #"<" :pos (cb to tag! nm attributes)
	]
	|
	#"<" (cb 'text copy "<")
]

attribute: [[
		copy attnmns name #":" copy attnmtxt name (
			attnm: make path! reduce [to word! attnmns to word! attnmtxt]
		)
		|
		copy attnmtxt name (attnm: to word! attnmtxt)
	] any space-char [
		#"=" any space-char attr-value any space-char (
			insert insert/only tail attributes attnm either attval [
				decode-entities attval
			][
				copy ""
			]
		)
		|
		none (insert insert/only tail attributes attnm attnmtxt)
	]]

attr-value: [
	#"^"" copy attval to #"^"" skip
	|
	#"'" copy attval to #"'" skip
	|
	copy attval some broken-value-chars pos: #">" :pos
	|
	copy attval any value-chars
]

end-tag: ["</" copy nm [name opt [#":" name]] any space-char #">" (cb append copy </> nm none)]

script-style: [
	#"<" copy nm ["script" | "style"] any space-char (attributes: make block! 16) any attribute
	#">" (cb to tag! nm attributes nm: append copy </> nm) [
		any space-char "/*" any space-char "<![CDATA[" any space-char "*/" any space-char
		copy txt to "]]>" 3 skip any space-char "*/" any space-char
		nm (
			txt: any [txt copy ""]
			trim/tail txt
			if "/*" = skip tail txt -2 [
				clear skip tail txt -2
				trim/tail txt
			]
			cb 'text txt
			cb nm none
		)
		|
		any space-char "<!--" copy txt to "-->" 3 skip any space-char
		nm (
			txt: any [txt copy ""]
			trim/tail txt
			if "//" = skip tail txt -2 [
				clear skip tail txt -2
				trim/tail txt
			]
			cb 'text txt
			cb nm none
		)
		|
		copy txt to nm nm (cb 'text any [txt copy ""] cb nm none)
	]
]

text: [
	some [
		copy txt some space-char (cb 'whitespace txt)
		|
		copy txt some text-char (cb 'text decode-text txt 'html)
	]
]

nm: none
attributes: []

attnm: attnmtxt: attnmns: none
attval: none
txt: none
decode-entities: func [attribute][
	decode-text attribute 'html
]

parse-ml: func [
	"Parse *ML text"
	html [string!]
	callback [any-function!]
][
	cb: :callback
	parse html html-rule
]

load-markup: func [
	"LOAD/MARKUP replacement that parses tags and more"
	html [string!]
	/local
	result
][
	result: copy []
	parse-ml html func [cmd data][
		switch/default cmd [
			text whitespace [
				either all [not empty? result string? last result] [
					append last result data
				][
					append result data
				]
			]
			comment declaration xml-proc [
				if tag? data: attempt [load data] [append result data]
			]
		][
			either all [block? data not empty? data] [
				insert data cmd
				append/only result data
			][
				append result cmd
			]
		]
	]
	result
]

probe /parsers.ml-parser

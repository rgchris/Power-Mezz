Rebol [
	Title: "(Simple) CSS Parser"
	File: %css-parser.r
	Type: 'Module
	Purpose: {
		Parses simple CSS strings like those inside a tag's style attribute.
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
		%parsers/common-rules.r "Needed for SPACE-CHAR and NAME"
		%dialects/emit.r
	]
	Exports: [
		parse-css
		form-css
	]
]

non-special: complement charset ":;"
parse-css: func [
	"Parse a simple CSS string"
	css [string!]
	/local result name* value
][
	result: make block! 16
	parse/all css [
		any space-char some [
			copy name* name #":" any space-char copy value any non-special [#";" | end] (insert insert tail result to word! name* if value [trim/lines value])
			any space-char
		]
	]
	result
]

form-css: func [
	"Form a CSS string"
	css [block!]
	/local result
][
	emit make string! 24 [
		foreach [name value] css [
			if value [name ": " value #";"]
		]
	]
]
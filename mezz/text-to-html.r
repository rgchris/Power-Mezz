Rebol [
	Title: "Simple plain text to HTML converter"
	File: %text-to-html.r
	Type: 'Module
	Purpose: {
		Prepares a string of plain text for inclusion into an HTML page;
		makes links clickable, encodes to HTML, and so on.
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
	Version: 2.0.1
	Imports: [
		%parsers/common-rules.r
		%mezz/text-encoding.r
		%parsers/uri-parser.r "Used in case of URL filtering"
	]
	Globals: [
		text-to-html {Made global so that it is easy to use from non-modules}
	]
]

scheme: [
	"http://" | "https://" | "ftp://" | "mailto:"
]

punct-char: charset {.,!()[];:?{}'"<>}
punct: [punct-char | "¿" | "¡"]

unreserved: union alpha-char union digit charset "-_~/$&*+="
unreserved+: union unreserved charset "@%"
name-or-host: [some unreserved any [some punct some unreserved]]

url-rule: [[scheme (add-scheme: "") | "www." (add-scheme: "http://") | "ftp." (add-scheme: "ftp://")]
	some unreserved+ any [some punct some unreserved+]
	|
	name-or-host #"@" name-or-host (add-scheme: "mailto:")
]

non-space: complement space-char
text-rule: [
	some non-space any [space-char | punct]
]

default-options: context [
	utf8: no
	custom-handler: none
]

text-to-html: func [
	"Prepare a plain text string for inclusion in HTML"
	text [string!]
	/with options [block!] "Specify options for the conversion"
	/local
	output str encoding custom-handler? obj
][
	options: make default-options any [options []]
	output: make string! length? text
	encoding: either options/utf8 ['html-utf8] ['html-ascii]
	custom-handler?: any-function? get in options 'custom-handler
	parse/all text [
		copy str any [punct | space-char] (if str [encode-text/to str encoding output])
		any [
			copy str url-rule (
				either custom-handler? [
					options/custom-handler obj: make parse-uri join add-scheme str [
						target: none
						contents: encode-text str encoding
					]
					append output {<a href="}
					encode-text/to form-uri obj encoding output
					append output #"^""
					if string? obj/target [
						append output { target="}
						encode-text/to obj/target encoding output
						append output #"^""
					]
					repend output [
						#">" obj/contents </a>
					]
				][
					insert insert tail output {<a href="} add-scheme
					encode-text/to str encoding output
					append output {">}
					encode-text/to str encoding output
					append output "</a>"
				]
			)
			copy str any [punct | space-char] (if str [encode-text/to str encoding output])
			|
			copy str text-rule (encode-text/to str encoding output)
		]
	]
	output
]
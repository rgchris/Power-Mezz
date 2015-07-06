Rebol [
	Title: "IMAP Parser"
	File: %imap-parser.r
	Type: 'Module
	Purpose: "^/        Parses text from the IMAP protocol.^/    "
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
	Version: 1.0.2
	Imports: [
		%parsers/common-rules.r
		%mezz/logging.r
	]
	Exports: [
		parse-imap-line
		form-imap
	]
]

open-block: func [type][
	append/only stack curr
	append/only curr curr: make type 16
]

close-block: does [
	curr: last stack
	remove back tail stack
]

emit: func [value][
	append/only curr value
]

reset: does [
	stack: make block! 16
	curr: make block! 32
]

atom: [copy value some atom-char (emit if value <> "NIL" [to word! value])]

atom-char: complement charset [#"^@" - #"^_" #"^~" {()[]{} %"\}]
value2: none
special-atom: [
	copy value some atom-char
	#"[" copy value2 to #"]" skip (value: make path! reduce [to word! value value2])
	opt [
		#"<" copy value2 some digit #">" (append value to integer! value2)
	] (emit value)
]

space: #" "
date: [[
		#"^"" opt wday copy value [date-text2 space time opt [space zone]] #"^""
		|
		#"^"" opt wday copy value date-text2 #"^""
		|
		copy value date-text
	] (emit attempt [to date! trim value])]
date-text2: [[space digit | 1 2 digit] [#"-" | #" "] month [#"-" | #" "] [4 digit | 2 digit]]

date-text: [[space digit | 1 2 digit] #"-" month #"-" 4 digit]

month: [
	"Jan" | "Feb" | "Mar" | "Apr" | "May" | "Jun" |
	"Jul" | "Aug" | "Sep" | "Oct" | "Nov" | "Dec"
]

wday: [
	"Mon, " | "Tue, " | "Wed, " | "Thu, " | "Fri, " | "Sat, " | "Sun, "
]

time: [2 digit #":" 2 digit opt [#":" 2 digit]]

zone: [[[#"+" | #"-"] zoneworkaround: 4 digit (
			zoneworkaround: skip insert skip zoneworkaround 2 #":" 2
		) :zoneworkaround
		|
		"GMT"
		|
		"EST"
	]
	opt [space "(" thru ")"]
]

afternumber: charset " )]"
number: [copy value some digit [end | mk1: afternumber :mk1] (emit to integer! value)]

string: [quoted | literal]

quoted: [
	#"^"" (str: make string! 256) any [
		mk1: some quoted-char mk2: (insert/part tail str mk1 mk2)
		|
		#"\" [#"^"" (append str #"^"") | #"\" (append str #"\")]
	] #"^"" (emit str)
]

quoted-char: complement charset {^M
"\}
literal: [
	#"{" copy value some digit #"}" end mk1: (
		emit read-literal port to integer! value
		insert mk1 any [pick port 1 ""]
	)
]

text: [copy value some text-char (emit value)]

text-char: complement charset CRLF
flag: [#"\" copy value some atom-char (emit to refinement! value)]

imap-block: [#"[" (open-block block!) imap-list #"]" (close-block)]

imap-value: [
	imap-block
	|
	#"(" (open-block paren!) imap-list #")" (close-block)
	|
	date | number | string | flag | special-atom | atom
]

imap-list: [any [imap-value any space]]

response: [
	#"+" some space (emit '+) text
	|
	atom some space
	copy value ["OK" | "PREAUTH" | "BYE" | "NO" | "BAD"] some space (emit to word! value)
	opt imap-block text
	| (clear curr) imap-list
]

parse-imap-line: func [line port' /local result][
	port: port'
	reset
	result: curr
	if not parse/all line response [
		append-log 'error ["Unable to parse this line:^/" line]
		net-error "Parse error"
	]
	result
]

read-literal: func [port count][
	set-modes port [lines: false binary: true]
	also copy/part port count
	set-modes port [binary: false lines: true]
]

form-imap: func [output command [block! paren!] /local output-str value mk1 mk2][
	either empty? output [append output output-str: copy ""] [output-str: last output]
	parse command [
		some [[
				set value block! (
					append output-str #"["
					form-imap output value
					append output-str: last output #"]"
				)
				|
				set value paren! (
					append output-str #"("
					form-imap output value
					append output-str: last output #")"
				)
				|
				set value date! (
					repend output-str either value/time [[
							#"^""
							either value/day < 10 [#" "] [""] value/day
							#"-"
							pick [
								"Jan" "Feb" "Mar" "Apr" "May" "Jun"
								"Jul" "Aug" "Sep" "Oct" "Nov" "Dec"
							] value/month
							#"-"
							value/year
							#" "
							form-time value/time
							#" "
							form-zone value/zone
							#"^""
						]] [[
							#"^""
							value/day
							#"-"
							pick [
								"Jan" "Feb" "Mar" "Apr" "May" "Jun"
								"Jul" "Aug" "Sep" "Oct" "Nov" "Dec"
							] value/month
							#"-"
							value/year
							#"^""
						]]
				)
				|
				set value integer! (append output-str value)
				|
				set value string! (
					either find value newline [
						value: to binary! value
						replace/all value newline CRLF
						repend output-str [#"{" length? value #"}"]
						insert insert tail output value output-str: copy ""
					][
						append output-str #"^""
						parse/all value [
							any [
								mk1: some quoted-char mk2: (insert/part tail output-str mk1 mk2)
								|
								#"\" (append output-str "\\")
								|
								#"^"" (append output-str {\"})
								|
								skip
							]
						]
						append output-str #"^""
					]
				)
				|
				set value refinement! (insert insert tail output-str #"\" value)
				|
				set value path! (
					repend output-str [
						first value
						#"[" second value #"]"
					]
					if 3 = length? value [
						repend output-str [
							#"<" third value #">"
						]
					]
				)
				|
				set value [word! | issue!] (append output-str value)
			] [end | (append output-str " ")]]
	]
	output
]
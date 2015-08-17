Rebol [
	Title: "Common PARSE rules"
	File: %common-rules.r
	Type: 'Module
	Name: 'parsers.common-rules
	Purpose: {
		Defines a number of common charsets and PARSE rules.
	}
	Author: "Gabriele Santilli"
	License: {
		=================================
		A message from Qtask about this source code:

		We have selected the MIT license (as of 2010-Jan-1) because
		it is the closest ‚Äústandard‚Äù license to our intent.  If we had our way,
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
	Version: 1.1.1
	Needs: [
		%parsers/rule-arguments.r
	]
	Exports: [
		ascii-char html-special-char alpha-char letter space-char digit hexdigit
		ascii-minus-html-special letter* alphanum letter+ name do-next
	]
]

probe 'parsers.common-rules

ascii-char: charset [#"^@" - #"^~"]

html-special-char: charset {"&<>}
alpha-char: letter: charset [#"A" - #"Z" #"a" - #"z"]

space-char: charset " ^/^-"
digit: charset "1234567890"
hexdigit: charset "1234567890abcdefABCDEF"
ascii-minus-html-special: exclude ascii-char html-special-char
letter*: union letter charset "_"
alphanum: union alpha-char digit
letter+: union union letter digit charset ".-_"
name: [letter* any letter+]

do-next: make-rule [
	"Evaluate the next value, push result to the stack"
	/local here value
][
	here: skip (
		value: do/next here 'here
		push-result :value
	) :here
]

probe /parsers.common-rules

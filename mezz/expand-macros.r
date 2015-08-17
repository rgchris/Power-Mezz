Rebol [
	Title: "Macro expansion"
	File: %expand-macros.r
	Type: 'Module
	Name: 'mezz.expand-macros
	Purpose: "^/        Defines the EXPAND-MACROS function.^/    "
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
	Version: 1.0.1
	Exports: [
		macro
		expand-macros
	]
]

probe 'mezz.expand-macros

macro: func [spec body][
	spec: use spec reduce [spec]
	reduce ['macro spec body]
]

expand-macros: func [
	code [any-block! function!]
	/local next-rule nargs macro mark value
][
	code: either function? :code [
		func spec-of :code expand-macros body-of :code
	][
		head collect/into [
			parse code [
				some [
					set value word! (
						either all [
							value? value
							block? macro: get :value
							parse macro ['macro [2 block! | (probe "Yikes!!")]]
						][
							next-rule: [
								copy value nargs skip (
									keep expand-macro value macro
								)
								| (do make error! "not enough arguments!")
							]
							nargs: length? macro/2
						][
							next-rule: none
							keep value
						]
					)
					next-rule
					|
					set value [block! | paren!] (keep/only expand-macros value)
					|
					set value path! (keep/only :value)
					|
					set value skip (keep :value)
				]
			]
		] make code 0
	]
]

expand-macro: func [args [any-block!] macro [block!] /local value argument here res][
	if block? args [
		parse args [
			some [
				here: paren! (here/1: expand-macros here/1)
				|
				skip
			]
		]
	]

	either empty? macro/2 [
		argument: [end skip]
		args: none
	][
		set macro/2 args
		args: bind? macro/2/1
		argument: collect [
			keep to lit-word! first macro/2
			foreach w next macro/2 [
				keep '| keep to lit-word! w
			]
		]
	]

	expand-macro* macro/3 argument args
]

expand-macro*: func [
	block [block!] argument [block!] args [object! none!]
	/local value
][
	collect [
		parse block [
			some [
				set value argument (
					value: get in args value
					either any-block? value [
						keep/only value
					][
						keep value
					]
				)
				|
				value: path! :value into [set value argument 'only] (
					keep/only get in args value
				)
				|
				/lit set value [block! | paren!] (keep/only value)
				|
				/paren set value paren! (keep/only head collect/into [expand-macro* value argument args :keep] make paren! 0)
				|
				/only set value paren! (keep/only do either args [bind to block! value args] [value])
				|
				set value paren! (keep do either args [bind to block! value args] [value])
				|
				set value block! (
					keep/only collect [expand-macro* value argument args :keep]
				)
				|
				set value skip (keep/only :value)
			]
		]
	]
]

probe /mezz.expand-macros
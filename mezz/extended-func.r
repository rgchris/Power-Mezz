Rebol [
	Title: "Extended version of FUNC"
	File: %extended-func.r
	Type: 'Module
	Purpose: {
		Defines an extended version of FUNC with extra features.
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
	Version: 1.0.0
	Imports: [
		%parsers/common-rules.r
		%parsers/rule-arguments.r
	]
	Exports: [
		func
	]
]

func: make function! [
	{Defines a user function with given spec and body (extended version)} [catch]
	spec [block!] {Help string (opt) followed by arg words (and opt type and string)}
	body [block!] "The body block of the function"
	/local actual-spec actual-body value arglist-name arg-name arg-type arg-help arg-default
	actual-locals
][
	actual-spec: make block! length? spec
	actual-body: make block! length? body
	actual-locals: clear []
	parse spec [
		any [set value [string! | block!] (append/only actual-spec value)]
		any [
			set arglist-name word! into [
				some [
					set arg-name set-word!
					do-next (arg-default: pop-result)
					set arg-type opt block!
					set arg-help opt string! (
						append actual-locals arg-name
						if found? :arg-default [repend actual-body [arg-name :arg-default]]
					)
				]
			] (
				repend actual-spec [arglist-name [block!] "List of named arguments"]
				append actual-body compose/deep/only [
					parse (arglist-name) [
						any [
							set local set-word! (
								to paren! compose/only [
									unless find (copy actual-locals) local [
										make error! reduce ['script 'invalid-arg local]
									]
								]
							)
							do-next (
								to paren! [set bind local 'local pop-result]
							)
							|
							local: skip (to paren! [make error! reduce ['script 'invalid-arg local]])
						]
					]
				]
			)
			|
			set arg-name word!
			set arg-type opt block!
			set arg-help opt string! (
				append actual-spec arg-name
				if arg-type [append/only actual-spec arg-type]
				if arg-help [append actual-spec arg-help]
			)
			|
			/local (
				append actual-spec /local
				foreach word actual-locals [append actual-spec to word! word]
				clear actual-locals
			)
			|
			set arg-name refinement!
			set arg-help opt string! (
				append actual-spec arg-name
				if arg-help [append actual-spec arg-help]
			)
			|
			skip
		]
	]
	unless empty? actual-locals [
		append actual-spec /local
		foreach word actual-locals [append actual-spec to word! word]
	]
	append actual-body body
	throw-on-error [make function! actual-spec actual-body]
]
Rebol [
	Title: "Arguments for PARSE rules"
	File: %rule-arguments.r
	Type: 'Module
	Name: 'parsers.rule-arguments
	Purpose: {
		A way to pass arguments to PARSE rules, so that it becomes possible
		to define parametrized rules.
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
	Version: 1.1.0
	Exports: [
		push-arguments
		push-result
		pop-result
		make-rule
	]
]

probe 'parsers.rule-arguments

stack: []

push-arguments: func [
	"Push values into the arguments/results stack"
	values [block!]
][
	repend stack values
]

push-result: func [
	"Push one value into the arguments/results stack"
	value
][
	append/only stack :value
]

pop-arguments: func [
	{Pop and set values from the arguments/results stack} [catch]
	names [block!] "Words to set to the values from the stack"
][
	if greater? length? names length? stack [
		do make error! "Not enough arguments in the stack"
	]
	set names names: skip tail stack negate length? names
	clear names
]

pop-result: func [
	"Pop one value from the arguments/results stack"
	/local result
][
	either error? result: try [
		also last stack
		remove back tail stack
	][
		do :result
	][
		:result
	]
]

make-rule: func [
	{Create a rule that takes arguments (via PUSH-ARGUMENTS)}
	spec [block!] "Argument spec (similar to function spec)"
	body [block!] "PARSE rule"
	/local
	ctx args word local?
][
	ctx: clear []
	local?: no
	args: copy []
	parse spec [
		some [
			set word word! (
				append ctx to set-word! word
				unless local? [append args word]
			)
			|
			/local (local?: yes)
			|
			skip
		]
	]
	ctx: context append ctx none
	bind args ctx
	bind body ctx
	head insert/only body to paren! reduce ['pop-arguments args]
]

probe /parsers.rule-arguments

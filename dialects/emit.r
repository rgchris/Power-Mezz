Rebol [
	Title: "Dialected EMIT function"
	File: %emit.r
	Type: 'Module
	Purpose: {
		Defines a EMIT function and a dialect that can be extended with "macros".
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
	Version: 1.1.5
	Imports: [
		%mezz/text-encoding.r "Used by the encode-text and decode-text keywords"
		%parsers/common-rules.r "We need DO-NEXT"
		%parsers/rule-arguments.r "We need POP-RESULT for DO-NEXT"
	]
	Exports: [
		macro "Used to create new macros for EMIT"
		emit "Append values to a series according to a dialect"
	]
]

emit: func [
	"Append values to a series according to a dialect"
	output [series! port!]
	values [block!] "EMIT dialect block (see docs)"
	/local
	value here tmp
][
	parse values [
		some [
			set value lit-word! (append output value)
			|
			set value lit-path! (append/only output value)
			|
			here: path! :here into [set value word! 'options] here: (
				value: get value
				either macro? :value [
					here: call-macro/options output here value
				][
					append output value/options
				]
			) :here
			|
			set value path! here: (
				either tmp: in emit-keywords value/1 [
					value/1: tmp
					here: do value output here
				][
					append output do value
				]
			) :here
			|
			set value word! here: (
				either tmp: in emit-keywords value [
					here: do tmp output here
				][
					value: get value
					either macro? :value [
						here: call-macro output here value
					][
						append output :value
					]
				]
			) :here
			|
			set value paren! (append output do value)
			|
			set value skip (append/only output :value)
		]
	]
	output
]

macro: func [
	"Define a macro for the EMIT dialect"
	spec [block!] {Spec for the macro arguments, options and local words}
	body [block!] "Body of the macro (EMIT dialect)"
	/custom "The body is a PARSE rule"
	/local
	spec* name val type types mandatory
][
	spec*: make block! 3 + length? spec
	types: make block! 3 + length? spec
	parse spec [
		some [
			set name set-word! do-next [set type block! | (type: none)] (
				insert/only insert tail spec* name pop-result
				append/only types type
			)
			|
			set name word! [set type block! | (type: none)] (
				insert insert tail spec* to set-word! name none
				append/only types type
			)
			| [/local | /options] (unless mandatory [mandatory: length? types])
			|
			refinement! (make error! "Refinements not supported.")
			|
			skip
		]
	]
	unless mandatory [mandatory: length? types]
	spec*: construct spec*
	bind body spec*
	reduce [
		'macro spec* get spec* mandatory types
		either custom [
			func [output args] compose/deep/only [
				parse args [(body)
					args:
				]
				args
			]
		][
			body
		]
		spec
	]
]
macro?: func [value][
	all [
		block? :value
		parse value ['macro object! block! integer! block! [block! | function!] block!]
	]
]

expect-arg: func [func-name arg-name types near][
	make error! reduce ['script 'expect-arg func-name arg-name types near]
]

no-arg: func [func-name arg-name near][
	make error! reduce ['script 'no-arg func-name arg-name none near]
]

call-macro: func [
	output [series! port!]
	args [block!]
	macro [block!]
	/options
	/local saved values value types name near
][
	saved: get macro/2
	either function? pick macro 6 [
		set macro/2 macro/3
		args: macro/6 output args
	][
		near: copy/part back args 5
		values: copy macro/3
		types: macro/5
		loop macro/4 [
			if empty? args [
				no-arg near/1 pick first macro/2 1 + index? types near
			]
			set [value args] do/next args
			if all [types/1 not find types/1 type?/word :value] [
				expect-arg near/1 pick first macro/2 1 + index? types types/1 near
			]
			values/1: :value
			values: next values
			types: next types
		]
		set macro/2 head values
		if options [
			if empty? args [
				no-arg near/1 'options near
			]
			set [value args] do/next args
			unless block? :value [
				expect-arg near/1 'options [block!] near
			]
			options: copy skip first macro/2 macro/4 + 1
			types: copy types
			parse value [
				some [
					set name set-word! do-next (
						if name: find options to word! name [
							types: at head types index? name
							value: pop-result
							if all [types/1 not find types/1 type?/word :value] [
								expect-arg near/1 name/1 types/1 near
							]
							set in macro/2 name/1 :value
						]
					)
					|
					skip
				]
			]
		]
		emit output macro/6
	]
	set macro/2 saved
	args
]

make-keywords: func [
	keywords [block!]
	/local result name spec body actual-spec actual-body value
][
	result: clear []
	parse keywords [
		some [
			set name set-word! 'keyword block! block! (append result name)
		]
	]
	append result none
	result: context result
	parse keywords [
		some [
			set name set-word! 'keyword set spec block! set body block! (
				actual-spec: copy [
					output [series! port!]
					args [block!]
					/local
				]
				actual-body: make block! 16
				parse spec [
					some [
						set value word! (
							append actual-spec value
							append actual-body compose/deep [
								set [(value) args] do/next args
							]
						)
						|
						/local some [set value word! (append actual-spec value) | skip]
						|
						set value refinement! (
							insert find actual-spec /local value
						)
						|
						skip
					]
				]
				append actual-body body
				append actual-body 'args
				result/(to word! name): func actual-spec actual-body
			)
		]
	]
	result
]

emit-keywords: make-keywords [
	emit: keyword [
		{Emit the argument, evaluating the dialect if it's a block}
		value "If block, contents is interpreted as EMIT dialect"
		/only "When output is block, emit as a sub-block"
	][
		either block? :value [
			either all [only any-block? output] [
				append/only output make block! 8
				emit last output value
			][
				emit output value
			]
		][
			do either only ['append/only] ['append] output :value
		]
	]
	if: keyword [
		{If condition is not false or none, emit the given values}
		condition
		values "Value to emit or emit dialect block"
	][
		if :condition [
			either block? :values [
				emit output values
			][
				append/only output :values
			]
		]
	]
	either: keyword [
		"Depending on condition, emit on-true or on-false"
		condition
		on-true "Value to emit or emit dialect block"
		on-false "Value to emit or emit dialect block"
		/local values
	][
		values: either :condition [:on-true] [:on-false]
		either block? :values [
			emit output values
		][
			append/only output :values
		]
	]
	apply: keyword [
		{Call a macro with the arguments in the supplied block}
		name
		arguments
	][
		name: get name
		if macro? :name [
			call-macro output arguments name
		]
	]
	encode-text: keyword [
		"Encode and emit text"
		text
		encoding
	][
		either any-string? output [
			encode-text/to text encoding output
		][
			append output encode-text text encoding
		]
	]
	decode-text: keyword [
		"Decode and emit text"
		text
		encoding
	][
		either any-string? output [
			decode-text/to text encoding output
		][
			append output decode-text text encoding
		]
	]
	foreach: keyword [
		"Emits values for each value in a series"
		word "Word or block of words to set each time (local)"
		data "The series to traverse"
		body "The values to emit at each iteration"
	][
		foreach :word data compose/only [emit output (body)]
	]
	switch: keyword [
		{Selects a choice and emits the block that follows it}
		value "Value to search for"
		cases [block!] "Block of cases to search"
		/local case
	][
		parse cases [
			to value to block! set case block! (emit output case)
			|
			to /default skip set case block! (emit output case)
		]
	]
]
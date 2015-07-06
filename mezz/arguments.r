Rebol [
	Title: "Command line arguments handling"
	File: %arguments.r
	Type: 'Module
	Purpose: {
		Defines functions to simplify handling of command line arguments.
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
	Exports: [
		parse-arguments
	]
]

parse-arguments: func [
	"Parse command line arguments, return an object"
	spec [block!] "Arguments spec"
	/env env-spec [block!] "Environment variables spec"
	/local
	help-text arguments keywords result action value default-value env-name var-name keyword
	type
][
	unless env [env-spec: []]
	help-text: clear ""
	keywords: [
		"help" (print help-text quit)
	]
	arguments: [
		keywords
	]
	result: clear []
	type-rule: [
		'integer! (
			type: 'integer!
			action: to paren! compose/deep [
				if value: attempt [to integer! value] [
					set in result (to lit-word! var-name) value
				]
			]
		)
		|
		'file! (
			type: 'file!
			action: to paren! compose [set in result (to lit-word! var-name) to-rebol-file value]
		)
		| (type: 'string! action: to paren! compose [set in result (to lit-word! var-name) value])
		'string!
	]
	default-rule: [
		'default set default-value skip
		| (default-value: none)
	]
	get-env*: [
		if all [
			env-name: select env-spec var-name
			value: get-env env-name
		][
			default-value: switch type [
				file! [to-rebol-file value]
				integer! [attempt [to integer! value]]
				string! [value]
			]
		]
	]
	help-rule: [
		'help set value string! (repend help-text [" - " value])
	]
	finish-help: [
		if default-value [
			repend help-text [
				" (default: "
				either file? default-value [to-local-file default-value] [default-value]
				#")"
			]
		]
		append help-text newline
		if env-name [
			repend help-text [
				"^-^-Default can be set with the variable " env-name newline
			]
		]
		repend result [to set-word! var-name default-value]
	]
	parse spec [[
			'title set value string! (insert insert tail help-text value "^/Usage:^/^/")
			| (append help-text "Usage:^/^/")
		]
		any [
			set keyword string! set var-name word!
			opt type-rule
			default-rule (
				do get-env*
				repend help-text [
					#"^-" keyword " <" var-name #">"
				]
			)
			opt help-rule (
				do finish-help
				repend keywords [
					'|
					keyword 'set 'value 'string! action
				]
			)
			|
			set var-name word!
			type-rule
			default-rule (
				do get-env*
				repend help-text [
					"^-<" var-name #">"
				]
			)
			opt help-rule (
				do finish-help
				repend arguments [
					'|
					'set 'value 'string! action
				]
			)
		]
	]
	result: context result
	if system/options/args [parse system/options/args [any arguments]]
	result
]
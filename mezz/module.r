Rebol [
	Title: "Modules for Rebol 2"
	File: %module.r
	Purpose: {
		Defines the MODULE function, that creates encapsulated "modules" that are isolated
		from the rest of the code. Also defines LOAD-MODULE to automate module loading.
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
	Version: 1.1.2
]

use [make-context modules] [
	make-context: func [words][
		use words compose [bind? (to lit-word! first words)]
	]
	module!: context [
		Type: 'module
		Title: "Untitled"
		Purpose: "Undocumented"
		Imports: Exports: Globals: none
		local-ctx: export-ctx: none
	]
	module: func [
		"Create a new module" [catch]
		spec [block! object!] {You can set TITLE, PURPOSE, IMPORTS, EXPORTS, GLOBALS}
		body [block!]
		/local
		result imports' globals'
		rule word
		module
		conflicts
	][
		result: make module! spec
		foreach [src dst cond] bind [
			exports export-ctx [not word? :value]
			globals globals' [not word? :value]
			imports imports' [not any [any-word? :value file? :value url? :value]]
		] result [
			unless 'All = get src [
				set dst unique any [get src []]
				remove-each value get dst cond
			]
		]
		result/local-ctx: clear []
		parse body rule: [
			any [
				set word set-word! (append result/local-ctx to word! word)
				|
				into rule
				|
				skip
			]
		]
		either result/exports = 'All [
			result/export-ctx: exclude result/local-ctx globals'
			clear result/local-ctx
		][
			result/local-ctx: exclude result/local-ctx append copy globals' result/export-ctx
		]
		foreach module-name imports' [
			set/any 'module either word? module-name [
				get/any module-name
			][
				load-module module-name
			]
			either module? get/any 'module [
				if object? module/export-ctx [
					bind body module/export-ctx
					bind result/local-ctx module/export-ctx
				]
			][
				throw make error! join "Not a module: " module-name
			]
		]
		conflicts: clear []
		foreach word result/local-ctx [
			if value? word [append conflicts word]
		]
		foreach ctx bind [local-ctx export-ctx] result [
			either empty? get ctx [
				set ctx none
			][
				bind body set ctx make-context get ctx
			]
		]
		foreach word conflicts [
			set in result/local-ctx word get word
		]
		do body
		result
	]
	module?: func [
		"Returns TRUE for module objects"
		value [any-type!]
	][
		to logic! all [
			object? get/any 'value
			'module = get in value 'type
		]
	]
	load-module: func [
		"Load a Rebol script as a module" [catch]
		script [file! url!]
		/from "Add SCRIPT to the search path"
		/local
		loaded search-path save-dir
	][
		search-path: []
		if from [return append search-path script]
		either any [url? script #"/" = first script] [
			if loaded: select modules script [return loaded]
			parse loaded: load/header script [
				'Rebol block! (
					loaded: next loaded
					loaded/1: construct loaded/1
				)
			]
			unless module? loaded/1 [
				throw make error! rejoin ["Not a module: " mold script]
			]
		][
			loaded: foreach path search-path [
				if loaded: select modules path/:script [return loaded]
				if exists? path/:script [
					loaded: load/header path/:script
					unless module? loaded/1 [
						throw make error! rejoin ["Not a module: " mold script]
					]
					script: path/:script
					break/return loaded
				]
			]
			unless loaded [
				throw make error! rejoin ["Cannot find " mold script]
			]
		]
		if find modules script [
			throw make error! rejoin ["Loading loop detected: aborted at " mold script]
		]
		repend modules [script none]
		unless url? script [
			save-dir: what-dir
			change-dir first split-path script
		]
		loaded: module loaded/1 next loaded
		unless url? script [
			change-dir save-dir
		]
		poke find modules script 2 loaded
		loaded
	]
	modules: []
]
Rebol [
	Title: "Grow trees using constraints"
	File: %niwashi.r
	Type: 'Module
	Name: 'mezz.niwashi
	Purpose: {
		"Grow" a tree data structure using a state machine, constraining
		the result using a set of rules.
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
	Version: 1.1.3
	Needs: [
		%mezz/trees.r
		%mezz/expand-macros.r
		%mezz/macros/trees.r
	]
	Exports: [
		make-niwashi
		append-child
		enter-child
		leave-child
		split-branch
		attach-branch
		define-rules
		leave-all
	]
]

probe 'mezz.niwashi

rules!: context [
	name: #[none]
	debug?: no
	force-node?: [#[none]]
	ignore: []
	only: []
	ignore?: func [type] [#[false]]
	new-rules: []
	do-actions: []
	after-rules: [#[none]]
]

niwashi-prototype: [
	root: current: make-node 'root
	branch: none
	stack: copy []
	current-rules: make rules! [always: none]
	universal-rules: make rules! []
]


!push: macro [niwashi words][
	(compile-push niwashi words)
]

compile-push: func [niwashi words][
	collect [
		foreach word words [keep :insert]
		keep :tail
		keep/only make path! reduce [niwashi 'stack]
		foreach word words [
			keep/only make path! reduce [niwashi word]
		]
	]
]

tmp: none

!pop: macro [niwashi words][
	(:set) (:bind) words/only niwashi
	(to set-word! tmp: use [tmp]['tmp]) (:skip) (:tail) /only (make path! reduce [niwashi 'stack]) (negate length? words)
	(:clear) (tmp)
]

!unless: macro [][
	(:unless)
]

!ensure-block: macro [word][
	(:unless) (:block?) word [
		(to set-word! word) (:reduce) [word]
	]
]

named-rules: []

make-ignore: func [ignore [block!] only [block!]][
	case [
		all [
			empty? ignore
			empty? only
		][
			func [type] [#[false]]
		]
		empty? only [
			func [type] compose/only [
				find (ignore) type
			]
		]
		empty? ignore [
			func [type] compose/only [
				not find (only) type
			]
		]
		/else [
			func [type] compose/deep/only [
				any [
					find (ignore) type
					not find (only) type
				]
			]
		]
	]
]

compile-rules: func [
	rules [block!]
	target [object!]
	/local
		here types value force-node command ignore only last-force ruleset actions
		last-action new-rules after-rules append? foo
][
	ignore: copy target/ignore
	only: copy target/only
	force-node: copy target/force-node?
	remove back tail force-node

	last-force: no
	last-action: no
	actions: copy target/do-actions
	new-rules: copy target/new-rules
	after-rules: head remove back tail copy target/after-rules
	append?: no

	parse rules [
		some [
			'debug (target/debug?: yes)

			| ['on | 'except] node-types here: 'move 'to word! (
				do make error! join "MOVE TO not supported at this time: " mold/only here
			)

			| 'on set types node-types 'force set value word! (
				either last-force [
					append last force-node compose/deep [
						(types) [result: (to lit-word! value)]
					]
				][
					append force-node compose/deep [
						; (:apply) (:switch) (:reduce) [type [(types) [result: (to lit-word! value)]] (none) (none) /all]
						switch/all type [
							(types) [result: (to lit-word! value)]
						]
					]
					last-force: yes
				]
			)

			| 'except set types node-types 'force set value word! (
				last-force: no
				append force-node compose/deep [
					; (:apply) (:switch) [:type [(types) []] /default [result: (to lit-word! value)] (none)]
					switch/default type [
						(types) []
					][
						result: (to lit-word! value)
					]
				]
			)

			| 'on set types node-types [
				set value word! (
					value: get value
				)
				|
 				set value block! (value: func [node] value)
			] (
				either last-action [
					append last actions compose/deep [(types) [(:value) node]]
				][
					append actions compose/deep [
						switch/all type [
							(types) [(:value) node]
						]
					]
					last-action: yes
				]
			)

			| 'except set types node-types [
				set value word! (value: get value)
				|
				set value block! (value: func [node] value)
			] (
				last-action: no
				append actions compose/deep [
					switch/default type [
						(types) []
					][
						(:value) node
					]
				]
			)

			| set command ['ignore | 'only] set types node-types (
				append get bind command 'ignore types
			)

			| here: 'move 'target word! (
				do make error! join "MOVE TARGET not supported at this time: " mold/only here
			)

			| 'inside 'all 'but set types node-types set value word! (
				unless ruleset: select named-rules value [
					ruleset: make rules! [always: none]
					repend named-rules [value ruleset]
					compile-rules get value ruleset
				]

				append new-rules compose/deep [
					switch/default type [
						(types) []
					][
						(:merge-rules) rules (ruleset)
						(
							either all [
								in ruleset 'always
								ruleset/always
							][
								compose [
									(:merge-rules) universal-rules (ruleset/always)
								]
							][
								[]
							]
						)
					]
				]
				append?: no
			)

			| 'inside 'all 'but set types node-types set value block! (
				ruleset: make rules! [always: none]
				compile-rules value ruleset
				append new-rules compose/deep [
					switch/default type [
						(types) []
					][
						(:merge-rules) rules (ruleset)
						(
							either ruleset/always [
								compose [
									(:merge-rules) universal-rules (ruleset/always)
								]
							][
								[]
							]
						)
					]
				]
				append?: no
			)

			| 'inside set types node-types set value word! (
				unless ruleset: select named-rules value [
					ruleset: make rules! [always: none name: envelop :types]
					repend named-rules [value ruleset]
					compile-rules get value ruleset
				]

				either append? [
					append last new-rules compose/deep [
						(types) [
							(:merge-rules) rules (ruleset)
							(
								either all [
									in ruleset 'always
									ruleset/always
								][
									compose [
										(:merge-rules) universal-rules (ruleset/always)
									]
								][
									[]
								]
							)
						]
					]
				][
					append new-rules compose/deep [
						switch/all type [
							(types) [
								(:merge-rules) rules (ruleset)
								(
									either all [
										in ruleset 'always
										ruleset/always
									][
										compose [
											(:merge-rules) universal-rules (ruleset/always)
										]
									][
										[]
									]
								)
							]
						]
					]

					append?: yes
				]
			)

			| 'inside set types node-types set value block! (
				ruleset: compile-rules value make rules! [always: none]
				ruleset/name: envelop types

				either append? [
					append last new-rules compose/deep [
						(types) [
							(:merge-rules) rules (ruleset)
							(
								either ruleset/always [
									compose [
										(:merge-rules) universal-rules (ruleset/always)
									]
								][
									[]
								]
							)
						]
					]
				][
					append new-rules compose/deep [
						switch/all type [
							(types) [
								(:merge-rules) rules (ruleset)
								(
									either ruleset/always [
										compose [
											(:merge-rules) universal-rules (ruleset/always)
										]
									][
										[]
									]
								)
							]
						]
					]

					append?: yes
				]
			)

			| 'after set types node-types set value word! (
				unless ruleset: select named-rules value [
					ruleset: make rules! []
					repend named-rules [value ruleset]
					compile-rules get value ruleset
				]
				either empty? after-rules [
					append after-rules compose/deep [
						switch/all type [
							(types) [
								merge-rules rules (ruleset)
								result: #[true]
							]
						]
					]
				][
					append last after-rules compose/deep [
						(types) [
							merge-rules rules (ruleset)
							result: #[true]
						]
					]
				]
			)

			| 'after set types node-types set value block! (
				ruleset: make rules! []
				compile-rules value ruleset
				either empty? after-rules [
					append after-rules compose/deep [
						switch/all type [
							(types) [
								merge-rules rules (ruleset)
								result: #[true]
							]
						]
					]
				][
					append last after-rules compose/deep [
						(types) [
							merge-rules rules (ruleset)
							result: #[true]
						]
					]
				]
			)

			| here: 'always (
				unless in target 'always [
					do make error! join "ALWAYS inside ALWAYS or AFTER: " mold/only here
				]
			) [
				set value block! (
					ruleset: make rules! []
					compile-rules value ruleset
					either target/always [
						merge-rules target/always ruleset
					][
						target/always: ruleset
					]
				)
				|
				set value word! (
					unless ruleset: select named-rules value [
						ruleset: make rules! []
						repend named-rules [value ruleset]
						compile-rules get value ruleset
					]
					either target/always [
						merge-rules target/always ruleset
					][
						target/always: ruleset
					]
				)
			]

			| here: skip (invalid-arg here)
		]
	]

	new-line/all/skip any [last after-rules []] true 2

	append force-node new-line [result] true
	append after-rules new-line [result] true

	target/force-node?: :force-node
	target/ignore: unique ignore
	target/only: unique only
	target/ignore?: make-ignore target/ignore target/only
	target/new-rules: :new-rules
	target/do-actions: :actions
	target/after-rules: :after-rules

	target
]

merge-rules: func [
	target [object!]
	existing [object!]
][
	target/debug?: any [target/debug? existing/debug?]
	target/force-node?: head insert remove back tail copy target/force-node? copy existing/force-node?
	target/ignore: union target/ignore existing/ignore
	target/only: union target/only existing/only
	target/ignore?: make-ignore target/ignore target/only
	target/new-rules: head insert tail copy target/new-rules copy existing/new-rules
	target/do-actions: head insert tail copy target/do-actions copy existing/do-actions
	target/after-rules: head insert remove back tail copy target/after-rules copy existing/after-rules

	target
]

node-types: [word! | into [some word!]]

invalid-arg: func [value [string!]][
	do make error! compose/only [script invalid-arg (:value)]
]

make-child: func [
	spec [block!]
	/local
		pos word type properties value prop
] expand-macros [
	parse spec [
		any [
			pos:
			set word set-word! (
				unless find [type: properties:] word [invalid-arg pos]
				value: do/next next pos 'pos
				set bind word 'type value
			) :pos
			|
			skip (invalid-arg pos)
		]
	]

	unless word? :type [
		do make error! "No node type specified"
	]

	prop: copy []

	if block? :properties [
		parse properties [
			some [[word! | path!] skip] (append prop properties)
			|
			some [
				pos:
				set word set-word! (
					value: do/next next pos 'pos
					insert/only insert tail prop to word! word :value
				) :pos
				|
				set word set-path! (
					value: do/next next pos 'pos
					insert/only insert tail prop to path! word :value
				) :pos
			]
			|
			pos: skip (invalid-arg pos)
		]
	]

	!make-node-no-copy type prop
]

on-enter: func [
	niwashi [object!]
	node [block!]
	/local
		type force-node ruleset debug? new-alw
] expand-macros [
	type: !get-node-type node
	ruleset: make rules! [always: none]

	case [
		any [
			niwashi/universal-rules/ignore? type
			niwashi/current-rules/ignore? type
		][
			!push niwashi [universal-rules current-rules]
		]

		force-node: any [
			do func [type /local result] niwashi/current-rules/force-node? type
			do func [type /local result] niwashi/universal-rules/force-node? type
		][
			enter-child niwashi [type: force-node]
			on-enter niwashi node
		]

		/else [
			!push niwashi [universal-rules current-rules]
			new-alw: make rules! []
			merge-rules new-alw niwashi/universal-rules
			niwashi/universal-rules: new-alw
			do func [type rules universal-rules] niwashi/universal-rules/new-rules type ruleset niwashi/universal-rules
			do func [type rules universal-rules] niwashi/current-rules/new-rules type ruleset niwashi/universal-rules
			niwashi/current-rules: ruleset
		]
	]
]

on-leave: func [
	niwashi [object!]
	node [block!]
	/local
		type debug? after-rules
] expand-macros [
	type: !get-node-type node
	!pop niwashi [universal-rules current-rules]

	after-rules: make rules! []

	either any [niwashi/universal-rules/ignore? type niwashi/current-rules/ignore? type] [
		unwrap-node node
	][
		if or~
		to logic! do func [type rules /local result] niwashi/universal-rules/after-rules type after-rules
		to logic! do func [type rules /local result] niwashi/current-rules/after-rules type after-rules [
			niwashi/current-rules: after-rules
		]
		do func [type node] niwashi/universal-rules/do-actions type node
		do func [type node] niwashi/current-rules/do-actions type node
	]
]

on-append: func [
	niwashi [object!]
	node [block!]
	/local
		type debug? force-node after-rules
] expand-macros [
	type: !get-node-type node

	after-rules: make rules! []

	; ? niwashi/current-rules

	case [
		any [
			niwashi/universal-rules/ignore? type
			niwashi/current-rules/ignore? type
		][]

		force-node: any [
			do func [type /local result] niwashi/current-rules/force-node? type
			do func [type /local result] niwashi/universal-rules/force-node? type
		][
			enter-child niwashi [type: force-node]
			on-append niwashi node
		]

		/else [
			!set-node-parent-quick node niwashi/current

			if or~
				to logic! do func [type rules /local result] niwashi/universal-rules/after-rules type after-rules
				to logic! do func [type rules /local result] niwashi/current-rules/after-rules type after-rules [
					niwashi/current-rules: after-rules
				]

			do func [type node] niwashi/universal-rules/do-actions type node
			do func [type node] niwashi/current-rules/do-actions type node
		]
	]
]

define-rules: func [
	"Define rules to apply while building the tree" [catch]
	niwashi [object!]
	rules [block!]
][
	clear named-rules
	rules: compile-rules rules niwashi/current-rules
	if niwashi/current-rules/always [
		merge-rules niwashi/universal-rules niwashi/current-rules/always
	]
	rules
]

leave-all: func [
	"Leave all nodes, go back to the root node"
	niwashi [object!]
	/local
	node parent
] expand-macros [
	node: niwashi/current
	while [parent: !get-node-parent node] [
		niwashi/current: parent
		on-leave niwashi node
		node: parent
	]
]

enter-child: func [
	{Append a new child to the current node, and make it the current node} [catch]
	niwashi [object!]
	spec [block!]
	/local
	node
] expand-macros [
	on-enter niwashi node: make-child spec
	!set-node-parent-quick node niwashi/current
	niwashi/current: node
]

append-child: func [
	"Append a new child to the current node" [catch]
	niwashi [object!]
	spec [block!]
][
	on-append niwashi make-child spec
]

leave-child: func [
	{Leave the current node, make its parent the new current node} [catch]
	niwashi [object!]
	/local
	node parent
] expand-macros [
	node: niwashi/current
	unless parent: !get-node-parent node [
		do make error! "Already at the root node"
	]
	niwashi/current: parent
	on-leave niwashi node
]

split-branch: func [
	{Split the current branch into two branches (new branch left detached)} [catch]
	niwashi [object!]
	base [word! block!]
	/knots knot-nodes [word! block!]
	/prune prune-nodes [word! block!]
	/local
	node branch to-leave new-node type
] expand-macros [
	!ensure-block base
	!unless knots [knot-nodes: []]
	!unless prune [prune-nodes: []]
	!ensure-block knot-nodes
	!ensure-block prune-nodes
	node: niwashi/current
	branch: copy []
	to-leave: clear []
	while [not find base type: !get-node-type node] [
		if find knot-nodes type [
			do make error! join "Cannot cut through '" [type "' nodes"]
		]
		unless find prune-nodes type [
			new-node: !make-node type (!get-node-properties node)
			insert/only branch new-node
		]
		insert/only tail to-leave node
		unless node: !get-node-parent node [
			do make error! join "No nodes of type '" [base "' found in the current branch"]
		]
	]
	niwashi/current: node
	foreach node to-leave [
		on-leave niwashi node
	]
	niwashi/branch: branch
]

attach-branch: func [
	"Attach a previously split branch" [catch]
	niwashi [object!]
] expand-macros [
	unless niwashi/branch [
		do make error! "No branch to attach"
	]
	foreach node niwashi/branch [
		on-enter niwashi node
		!set-node-parent-quick node niwashi/current
		niwashi/current: node
	]
	niwashi/branch: none
]

make-niwashi: func [
	"Create an object used to build trees"
][
	make object! niwashi-prototype
]

probe /mezz.niwashi

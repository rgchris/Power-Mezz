Rebol [
	Title: "Grow trees using constraints"
	File: %niwashi.r
	Type: 'Module
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
	Imports: [
		%mezz/trees.r
		%mezz/expand-macros.r
		%mezz/collect.r
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

!push: macro [niwashi words] [(compile-push niwashi words)]

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
!pop: macro [niwashi words] [(:set) (:bind) words/only niwashi (to set-word! tmp: use [tmp] ['tmp]) (:skip) (:tail) /only (make path! reduce [niwashi 'stack]) (negate length? words) (:clear) (tmp)]
!unless: macro [] [(:unless)]
!ensure-block: macro [word] [(:unless) (:block?) word [(to set-word! word) (:reduce) [word]]]

make-niwashi: func [
	"Create an object used to build trees"
][
	context [
		root: current-node: make-node 'root
		branch: none
		stack: copy []
		cn-rules: make rules! [always: none]
		always-rules: make rules! []
	]
]

append-child: func [
	"Append a new child to the current node" [catch]
	niwashi [object!]
	spec [block!]
][
	on-append niwashi make-child spec
]

enter-child: func [
	{Append a new child to the current node, and make it the current node} [catch]
	niwashi [object!]
	spec [block!]
	/local
	node
]
expand-macros [
	on-enter niwashi node: make-child spec
	!set-node-parent-quick node niwashi/current-node
	niwashi/current-node: node
]

leave-child: func [
	{Leave the current node, make its parent the new current node} [catch]
	niwashi [object!]
	/local
	node parent
]
expand-macros [
	node: niwashi/current-node
	unless parent: !get-node-parent node [
		throw make error! "Already at the root node"
	]
	niwashi/current-node: parent
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
]
expand-macros [
	!ensure-block base
	!unless knots [knot-nodes: []]
	!unless prune [prune-nodes: []]
	!ensure-block knot-nodes
	!ensure-block prune-nodes
	node: niwashi/current-node
	branch: copy []
	to-leave: clear []
	while [not find base type: !get-node-type node] [
		if find knot-nodes type [
			throw make error! join "Cannot cut through '" [type "' nodes"]
		]
		unless find prune-nodes type [
			new-node: !make-node type (!get-node-properties node)
			insert/only branch new-node
		]
		insert/only tail to-leave node
		unless node: !get-node-parent node [
			throw make error! join "No nodes of type '" [base "' found in the current branch"]
		]
	]
	niwashi/current-node: node
	foreach node to-leave [
		on-leave niwashi node
	]
	niwashi/branch: branch
]

attach-branch: func [
	"Attach a previously split branch" [catch]
	niwashi [object!]
]
expand-macros [
	unless niwashi/branch [
		throw make error! "No branch to attach"
	]
	foreach node niwashi/branch [
		on-enter niwashi node
		!set-node-parent-quick node niwashi/current-node
		niwashi/current-node: node
	]
	niwashi/branch: none
]

define-rules: func [
	"Define rules to apply while building the tree" [catch]
	niwashi [object!]
	rules [block!]
][
	clear named-rules
	compile-rules rules niwashi/cn-rules
	if niwashi/cn-rules/always [
		merge-rules niwashi/always-rules niwashi/cn-rules/always
	]
]

leave-all: func [
	"Leave all nodes, go back to the root node"
	niwashi [object!]
	/local
	node parent
]
expand-macros [
	node: niwashi/current-node
	while [parent: !get-node-parent node] [
		niwashi/current-node: parent
		on-leave niwashi node
		node: parent
	]
]

named-rules: []
rules!: context [
	debug?: no
	force-node?: func [type /local result] [#[none]]
	ignore: [] only: []
	ignore?: func [type] [#[false]]
	make-new-rules: func [type rules always-rules] []
	do-actions: func [type node] []
	make-after-rules: func [type rules /local result] [#[none]]
]

merge-rules: func [target rules][
	target/debug?: any [target/debug? rules/debug?]
	target/force-node?: func [type /local result]
	head insert remove back tail second get in target 'force-node? second get in rules 'force-node?
	mk-ignore target target/ignore: union target/ignore rules/ignore target/only: union target/only rules/only
	target/make-new-rules: func [type rules always-rules]
	head insert tail second get in target 'make-new-rules second get in rules 'make-new-rules
	target/do-actions: func [type node]
	head insert tail second get in target 'do-actions second get in rules 'do-actions
	target/make-after-rules: func [type rules /local result]
	head insert remove back tail second get in target 'make-after-rules second get in rules 'make-after-rules
]

compile-rules: func [
	rules rules-object
	/local pos types value force-node cmd ignore only last-force new-rules actions
	last-action mk-newrules mk-afterrules last-mkr last-mkar
][
	ignore: copy rules-object/ignore
	only: copy rules-object/only
	force-node: copy second get in rules-object 'force-node?
	remove back tail force-node
	last-force: no
	last-action: no
	actions: copy second get in rules-object 'do-actions
	mk-newrules: copy second get in rules-object 'make-new-rules
	mk-afterrules: head remove back tail copy second get in rules-object 'make-after-rules
	last-mkr: no
	parse rules [
		some [
			'debug (rules-object/debug?: yes)
			| ['on | 'except] node-types pos: ['move 'to word!] (
				throw make error! join "MOVE TO not supported at this time: " mold/only pos
			)
			|
			'on set types node-types 'force set value word! (
				either last-force [
					append last force-node compose/deep [(types) [result: (to lit-word! value)]]
				][
					append force-node compose/deep [
						switch/all type [(types) [result: (to lit-word! value)]]
					]
					last-force: yes
				]
			)
			|
			'except set types node-types 'force set value word! (
				last-force: no
				append force-node compose/deep [
					switch/default type [(types) []] [result: (to lit-word! value)]
				]
			)
			|
			'on set types node-types [
				set value word! (value: get value)
				|
				set value block! (value: func [node] value)
			] (
				either last-action [
					append last actions compose/deep [(types) [(:value) node]]
				][
					append actions compose/deep [
						switch/all type [(types) [(:value) node]]
					]
					last-action: yes
				]
			)
			|
			'except set types node-types [
				set value word! (value: get value)
				|
				set value block! (value: func [node] value)
			] (
				last-action: no
				append actions compose/deep [
					switch/default type [(types) []] [(:value) node]
				]
			)
			|
			set cmd ['ignore | 'only] set types node-types (
				append get bind cmd 'ignore types
			)
			|
			pos: 'move 'target word! (
				throw make error! join "MOVE TARGET not supported at this time: " mold/only pos
			)
			|
			'inside 'all 'but set types node-types set value word! (
				unless new-rules: select named-rules value [
					new-rules: make rules! [always: none]
					repend named-rules [value new-rules]
					compile-rules get value new-rules
				]
				append mk-newrules compose/deep [
					switch/default type [(types) []] [(:merge-rules) rules (new-rules) (either all [in new-rules 'always new-rules/always] [
								compose [(:merge-rules) always-rules (new-rules/always)]
							] [[]])]
				]
				last-mkr: no
			)
			|
			'inside 'all 'but set types node-types set value block! (
				new-rules: make rules! [always: none]
				compile-rules value new-rules
				append mk-newrules compose/deep [
					switch/default type [(types) []] [(:merge-rules) rules (new-rules) (either new-rules/always [
								compose [(:merge-rules) always-rules (new-rules/always)]
							] [[]])]
				]
				last-mkr: no
			)
			|
			'inside set types node-types set value word! (
				unless new-rules: select named-rules value [
					new-rules: make rules! [always: none]
					repend named-rules [value new-rules]
					compile-rules get value new-rules
				]
				either last-mkr [
					append last mk-newrules compose/deep [(types) [(:merge-rules) rules (new-rules) (either all [in new-rules 'always new-rules/always] [
									compose [(:merge-rules) always-rules (new-rules/always)]
								] [[]])]]
				][
					append mk-newrules compose/deep [
						switch/all type [(types) [(:merge-rules) rules (new-rules) (either all [in new-rules 'always new-rules/always] [
										compose [(:merge-rules) always-rules (new-rules/always)]
									] [[]])]]
					]
					last-mkr: yes
				]
			)
			|
			'inside set types node-types set value block! (
				new-rules: make rules! [always: none]
				compile-rules value new-rules
				either last-mkr [
					append last mk-newrules compose/deep [(types) [(:merge-rules) rules (new-rules) (either new-rules/always [
									compose [(:merge-rules) always-rules (new-rules/always)]
								] [[]])]]
				][
					append mk-newrules compose/deep [
						switch/all type [(types) [(:merge-rules) rules (new-rules) (either new-rules/always [
										compose [(:merge-rules) always-rules (new-rules/always)]
									] [[]])]]
					]
					last-mkr: yes
				]
			)
			|
			'after set types node-types set value word! (
				unless new-rules: select named-rules value [
					new-rules: make rules! []
					repend named-rules [value new-rules]
					compile-rules get value new-rules
				]
				either empty? mk-afterrules [
					append mk-afterrules compose/deep [
						switch/all type [(types) [merge-rules rules (new-rules) result: #[true]]]
					]
				][
					append last mk-afterrules compose/deep [(types) [merge-rules rules (new-rules) result: #[true]]]
				]
			)
			|
			'after set types node-types set value block! (
				new-rules: make rules! []
				compile-rules value new-rules
				either empty? mk-afterrules [
					append mk-afterrules compose/deep [
						switch/all type [(types) [merge-rules rules (new-rules) result: #[true]]]
					]
				][
					append last mk-afterrules compose/deep [(types) [merge-rules rules (new-rules) result: #[true]]]
				]
			)
			|
			pos: 'always (
				unless in rules-object 'always [
					throw make error! join "ALWAYS inside ALWAYS or AFTER: " mold/only pos
				]
			) [
				set value block! (
					new-rules: make rules! []
					compile-rules value new-rules
					either rules-object/always [
						merge-rules rules-object/always new-rules
					][
						rules-object/always: new-rules
					]
				)
				|
				set value word! (
					unless new-rules: select named-rules value [
						new-rules: make rules! []
						repend named-rules [value new-rules]
						compile-rules get value new-rules
					]
					either rules-object/always [
						merge-rules rules-object/always new-rules
					][
						rules-object/always: new-rules
					]
				)
			]
			|
			pos: skip (invalid-arg pos)
		]
	]
	append force-node 'result
	append mk-afterrules 'result
	rules-object/force-node?: func [type /local result] force-node
	mk-ignore rules-object rules-object/ignore: unique ignore rules-object/only: unique only
	rules-object/make-new-rules: func [type rules always-rules] mk-newrules
	rules-object/do-actions: func [type node] actions
	rules-object/make-after-rules: func [type rules /local result] mk-afterrules
]

mk-ignore: func [rules-object ignore only][
	rules-object/ignore?: case [
		all [empty? ignore empty? only] [
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
		'else [
			func [type] compose/deep/only [
				any [find (ignore) type not find (only) type]
			]
		]
	]
]

node-types: [word! | into [some word!]]

invalid-arg: func [val] [throw make error! compose/only [script invalid-arg (:val)]]

make-child: func [spec /local pos word type properties value prop] expand-macros [
	parse spec [
		any [
			pos:
			set word set-word! (
				unless find [type: properties:] word [invalid-arg pos]
				set [value pos] do/next next pos
				set bind word 'type value
			) :pos
			|
			skip (invalid-arg pos)
		]
	]
	unless word? :type [
		throw make error! "No node type specified"
	]
	prop: copy []
	if block? :properties [
		parse properties [
			some [[word! | path!] skip] (append prop properties)
			|
			some [
				pos:
				set word set-word! (
					set [value pos] do/next next pos
					insert/only insert tail prop to word! word :value
				) :pos
				|
				set word set-path! (
					set [value pos] do/next next pos
					insert/only insert tail prop to path! word :value
				) :pos
			]
			|
			pos: skip (invalid-arg pos)
		]
	]
	!make-node-no-copy type prop
]

on-enter: func [niwashi node /local type force-node new-rules debug? new-alw] expand-macros [
	type: !get-node-type node
	new-rules: make rules! [always: none]
	case [
		any [niwashi/always-rules/ignore? type niwashi/cn-rules/ignore? type] [
			!push niwashi [always-rules cn-rules]
		]
		force-node: any [niwashi/cn-rules/force-node? type niwashi/always-rules/force-node? type] [
			enter-child niwashi [type: force-node]
			on-enter niwashi node
		]
		'else [
			!push niwashi [always-rules cn-rules]
			new-alw: make rules! []
			merge-rules new-alw niwashi/always-rules
			niwashi/always-rules: new-alw
			niwashi/always-rules/make-new-rules type new-rules niwashi/always-rules
			niwashi/cn-rules/make-new-rules type new-rules niwashi/always-rules
			niwashi/cn-rules: new-rules
		]
	]
]

on-leave: func [niwashi node /local type debug? after-rules] expand-macros [
	type: !get-node-type node
	!pop niwashi [always-rules cn-rules]
	after-rules: make rules! []
	either any [niwashi/always-rules/ignore? type niwashi/cn-rules/ignore? type] [
		unwrap-node node
	][
		if or~ to logic! niwashi/always-rules/make-after-rules type after-rules
		to logic! niwashi/cn-rules/make-after-rules type after-rules [
			niwashi/cn-rules: after-rules
		]
		niwashi/always-rules/do-actions type node
		niwashi/cn-rules/do-actions type node
	]
]

on-append: func [niwashi node /local type debug? force-node after-rules] expand-macros [
	type: !get-node-type node
	after-rules: make rules! []
	case [
		any [niwashi/always-rules/ignore? type niwashi/cn-rules/ignore? type] []
		force-node: any [niwashi/cn-rules/force-node? type niwashi/always-rules/force-node? type] [
			enter-child niwashi [type: force-node]
			on-append niwashi node
		]
		'else [
			!set-node-parent-quick node niwashi/current-node
			if or~ to logic! niwashi/always-rules/make-after-rules type after-rules
			to logic! niwashi/cn-rules/make-after-rules type after-rules [
				niwashi/cn-rules: after-rules
			]
			niwashi/always-rules/do-actions type node
			niwashi/cn-rules/do-actions type node
		]
	]
]
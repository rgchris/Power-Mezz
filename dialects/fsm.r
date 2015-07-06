Rebol [
	Title: "Finite State Machine interpreter"
	File: %fsm.r
	Type: 'Module
	Purpose: {
		Implements a FSM interpreter; it can run stack-based FSMs defined
		with a simple Rebol dialect.
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
	Version: 2.1.0
	Exports: [
		make-fsm
		reset-fsm
		process-event
		inherit "Just a handy shortcut"
	]
]

fsm-proto: context [
	state: event: data: none
	initial-state: []
	state-stack: []
	tracing: no
]

goto-state: func [fsm [object!] new-state [word!] retact [paren! none!]][
	insert/only insert/only fsm/state-stack: tail fsm/state-stack fsm/state :retact
	fsm/state: get in fsm new-state
]

return-state: func [fsm [object!] /local state retact][
	set [state retact] fsm/state-stack
	fsm/state: any [state fsm/initial-state]
	if fsm/tracing [prin ["return, retact:" mold :retact ""]]
	do retact
	fsm/state-stack: skip clear fsm/state-stack -2
]

rewind-state: func [fsm [object!] up-to [word!] /local retact stack][
	if empty? fsm/state-stack [return false]
	stack: tail fsm/state-stack
	retact: make block! 128
	up-to: get in fsm up-to
	until [
		stack: skip stack -2
		append retact stack/2
		if same? up-to stack/1 [
			fsm/state: up-to
			do retact
			fsm/state-stack: skip clear stack -2
			return true
		]
		head? stack
	]
	false
]

process-event: func [
	"Process one event"
	fsm [object!]
	event [any-string! word!]
	data "Any data related to the event"
	/local
	done?
	val ovr retact
][
	fsm/event: event
	if word? event [event: to set-word! event]
	fsm/data: :data
	until [
		if fsm/tracing [print ["*** event" mold event]]
		done?: yes
		local: any [find fsm/state event find fsm/state [default:]]
		if local [
			parse local [
				some [any-string! | set-word!]
				set val opt paren! (if all [:val fsm/tracing] [prin [mold :val ""]] do val) [
					'continue (if fsm/tracing [prin "continue "] done?: no)
					|
					'override set ovr word! (
						event: to set-word! fsm/event: ovr
						if fsm/tracing [prin ["override" mold ovr ""]]
						done?: no
					)
					|
					none
				][
					set val opt integer! 'return (loop any [val 1] [return-state fsm])
					|
					'rewind? copy val some word! (
						if fsm/tracing [prin ["rewind?" mold/only val]]
						if not foreach word val [
							if block? get in fsm word [
								if rewind-state fsm word [break/return true]
							]
							false
						][
							done?: yes
						]
					)
					|
					set val word! set retact opt paren! (
						if block? get in fsm val [
							if fsm/tracing [prin ["go to" val "then" mold :retact ""]]
							goto-state fsm val :retact
						]
					)
					|
					none (done?: yes)
				]
			]
		]
		if fsm/tracing [ask ""]
		done?
	]
]

make-fsm: func [
	"Create a new Finite State Machine object"
	spec [block!]
][
	spec: make fsm-proto spec
	spec/state: spec/initial-state
	spec/state-stack: copy []
	spec
]

reset-fsm: func [
	"Reset a FSM object"
	fsm [object!]
	/only
][
	unless only [
		foreach [retact state] head reverse head fsm/state-stack [do retact]
	]
	clear fsm/state-stack: head fsm/state-stack
	fsm/state: fsm/initial-state
]

inherit: func [
	{Handy shortcut that simulates inheritance between FSM state blocks}
	parent [block!]
	child [block!]
][
	append child parent
]
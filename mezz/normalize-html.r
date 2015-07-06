Rebol [
	Title: "HTML Normalizer"
	File: %normalize-html.r
	Type: 'Module
	Purpose: {
		Normalizes a HTML tag stream (that is, balances start and end tags, fixes missing
		end tags, and so on).
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
	Version: 1.1.7
	Imports: [
		%dialects/fsm.r "Finite State Machine dialect"
	]
	Exports: [
		normalize-html "Normalize HTML text"
		init-normalizer "Initialize HTML normalizer state machine"
		process-tag "Process a HTML tag"
		reset-normalizer "Reset HTML normalizer state machine"
	]
]

fsm: make-fsm [
	initial-state: [
		comment: declaration: xml-proc: (cb event data nl)
		whitespace: ()
		<html> (cb <html> data nl) in-html-prehead (cb </html> none)
		default: (cb <html> none nl) continue in-html-prehead (cb </html> none)
	]
	in-html-prehead: [
		comment: (cb 'comment data)
		whitespace: ()
		<head> (cb <head> none nl) in-head
		<title> <isindex> <isindex/> <base> <base/> <script> <script/>
		<style> <meta> <meta/> <link> <link/> <object> (cb <head> none nl) continue in-head
		default: (foreach tag [<head> <title> </title> </head>] [cb tag none] nl) continue in-html-prebody
	]
	in-head: [
		comment: (cb 'comment data)
		whitespace: ()
		<head> ()
		</head> (cb </head> none nl) in-html-prebody
		default: (cb </head> none nl) continue in-html-prebody
		<title> (cb <title> none) in-title (cb </title> none nl)
		<isindex> <isindex/> ()
		<base> <base/> (cb <base/> data)
		<script> in-script
		<script/> ()
		<style> (cb <style> data) in-style (cb </style> none nl)
		<meta> <meta/> ()
		<link> <link/> (cb <link/> data nl)
		<object> in-hobject
	]
	in-title: [
		comment: ()
		text: (cb 'text data)
		whitespace: (sp) ignore-whitespace
		</title> return
		default: continue return
	]
	ignore-whitespace: [
		whitespace: ()
		default: continue return
	]
	in-script: [
		comment: text: whitespace: ()
		</script> return
		default: continue return
	]
	in-hobject: [
		</object> return
	]
	in-style: [
		comment: ()
		text: whitespace: (cb event data)
		</style> return
		default: continue return
	]
	in-html-prebody: [
		comment: (cb 'comment data)
		whitespace: ()
		<body> (cb <body> data nl) in-block (close-all block-stack cb </body> none nl)
		default: (cb <body> none nl) continue in-block (close-all block-stack cb </body> none nl)
	]
	in-block: [
		comment: (cb 'comment data)
		whitespace: ()
		<h1> <h2> <h3> <h4> <h5> <h6> <address> <p> <li> <dt> <dd>
		<td> <th> <legend> <caption> (open-tag block-stack event data) in-inline (close-all inline-stack)
		<pre> (open-tag block-stack event data) in-pre (close-all inline-stack)
		<ul> <ol> <dl> <div> <center>
		<blockquote> <form> <fieldset> <table> <noscript>
		<tr> <colgroup> <thead> <tfoot> <tbody> <ins> <del> (open-tag block-stack event data nl)
		<isindex> <isindex/> ()
		<iframe> </iframe> ()
		<script> in-script
		<script/> ()
		<style> (cb <style> data) in-style (cb </style> none nl)
		<hr> <hr/> (
			foreach tag [
				</h1> </h2> </h3> </h4> </h5> </h6> </address>
				</p> </dt>
			][
				close-tag block-stack tag
			]
			cb <hr/> data nl
		)
		<col> <col/> (cb <col/> data nl)
		<br> <br/> (cb <br/> data nl)
		</h1> </h2> </h3> </h4> </h5> </h6> </address> </p> </ul> </ol>
		</li> </dl> </dt> </dd> </pre> </div> </center>
		</blockquote> </form> </fieldset> </legend> </table> </noscript>
		</tr> </td> </th> </caption> </colgroup> </thead>
		</tfoot> </tbody> </ins> </del> (close-tag block-stack event)
		</body> </html> ()
		<tt> <i> <b> <u> <strike> <s> <big> <small> <sub> <sup>
		<em> <strong> <dfn> <code> <samp> <kbd> <var> <cite>
		<a> <img> <img/> <applet> <font> <basefont> <basefont/>
		<map> <input> <input/> <select> <textarea> <span>
		<abbr> <acronym> <q> <label> text: (open-tag block-stack <p> none) continue in-inline (close-all inline-stack)
	]
	in-inline: [
		comment: (cb 'comment data)
		<tt> <i> <b> <u> <strike> <s> <big> <small> <sub> <sup>
		<em> <strong> <dfn> <code> <samp> <kbd> <var> <cite>
		<a> <font> <map> <select> <textarea> <option> <button>
		<optgroup> <label> <span>
		<abbr> <acronym> <q> <ins> <del> <object> (open-tag inline-stack event data)
		<applet> </applet> <param> </param> ()
		</tt> </i> </b> </u> </strike> </s> </big> </small> </sub> </sup>
		</em> </strong> </dfn> </code> </samp> </kbd> </var> </cite>
		</a> </font> </map> </select> </textarea> </button> </option>
		</optgroup> </label> </span>
		</abbr> </acronym> </q> </object>
		</ins> </del> (close-tag inline-stack event)
		<basefont> <basefont/> <br> <br/> <area> <area/>
		<input> <input/> (cb either #"/" = last event [event] [append event "/"] data if event = <br/> [nl])
		<img> <img/> <image> <image/> (cb <img/> data)
		text: (cb 'text data)
		whitespace: (sp) ignore-whitespace
		default: continue return
	]
	in-pre: append [
		whitespace: (cb 'whitespace data)
		<br> <br/> (nl)
	] in-inline
]

nl: does [cb 'whitespace copy "^/"]

sp: does [cb 'whitespace copy " "]

block-stack: []

inline-stack: []

nesting: [
	<h1> <h2> <h3> <h4> <h5> <h6> <address>
	<p> <ul> <ol> <dl> <pre> <dt> <dd>
	<div> <center> <blockquote> <table> [
		</h1> </h2> </h3> </h4> </h5> </h6> </address>
		</p> </dt> </dd>
	]
	<li> [
		never [<ul> <ol>] </li> </h1> </h2> </h3> </h4> </h5>
		</h6> </address> </p> </dt> </dd>
	]
	<form> [</form>]
	<tr> [never <table> </tr> </td> </th> </colgroup>]
	<td> <th> [never <table> </td> </th>]
	<thead> <tfoot> <tbody> [
		never <table> </thead> </tfoot> </tbody> </tr>
		</td> </th> </colgroup>
	]
	<colgroup> [never <table> </colgroup>]
	<a> [</a>]
	<map> [</map>]
	<option> [</option>]
]
select*: func [block value /local res][
	parse block [to value to block! set res block!]
	res
]

open-tag: func [stack starttag attributes /local nestrules upto tag][
	if nestrules: select* nesting starttag [
		parse nestrules [
			some [
				'never [copy upto tag! | set upto into [some tag!]]
				|
				set tag tag! (close-tag/upto stack tag upto)
			]
		]
	]
	insert tail stack starttag
	cb starttag attributes
]

close-tag: func [stack endtag /upto tags /local pos][
	endtag: remove copy endtag
	if pos: find/last stack endtag [
		if tags [
			foreach tag tags [
				if all [tag: find/last stack tag greater? index? tag index? pos] [
					exit
				]
			]
		]
		foreach tag head reverse copy pos [
			cb head insert copy tag "/" none
			if same? stack block-stack [nl]
		]
		clear pos
	]
]

close-all: func [stack][
	foreach tag head reverse stack [
		cb head insert copy tag "/" none
		if same? stack block-stack [nl]
	]
	clear stack
]

init-normalizer: func [
	"Initialize HTML normalizer state machine"
	callback [any-function!] "Callback used during processing"
][
	cb: :callback
	clear block-stack
	clear inline-stack
	reset-fsm/only fsm
]

process-tag: func [
	"Process a HTML tag"
	command command-data
][
	process-event fsm command command-data
]

reset-normalizer: func [
	"Reset HTML normalizer state machine"
][
	process-event fsm 'end none
	reset-fsm fsm
]

normalize-html: func [
	"Normalize HTML text"
	html [block!] "Result of LOAD-MARKUP"
	/local -nh-locals-
][
	result: make block! length? html
	init-normalizer func [cmd data][
		switch/default cmd [
			text whitespace [
				either all [not empty? result string? last result] [
					append last result data
				][
					append result data
				]
			]
			comment declaration xml-proc [
				append result data
			]
		][
			either all [block? data not empty? data] [
				insert data cmd
				append/only result data
			][
				append result cmd
			]
		]
	]
	non-space: complement space: charset " ^/^-"
	foreach element html [
		switch type?/word element [
			string! [
				parse/all element [
					any [
						copy txt some space (process-tag 'whitespace txt)
						|
						copy txt some non-space (process-tag 'text txt)
					]
				]
			]
			block! [
				process-tag first element copy next element
			]
			tag! [
				parse/all element [
					"!--" (process-tag 'comment element)
					|
					"!doctype" (process-tag 'declaration element)
					|
					"?" (process-tag 'xml-proc element)
					| (process-tag copy element none)
				]
			]
		]
	]
	reset-normalizer
	result
]
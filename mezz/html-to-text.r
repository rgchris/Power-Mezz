Rebol [
	Title: "HTML to plain text converter"
	File: %html-to-text.r
	Type: 'Module
	Purpose: {
		Defines a function that can convert a HTML text string into a plain
		text string.
	}
	Author: "Gabriele Santilli"
	License: {
		=================================
		A message from Qtask about this source code:

		We have selected the MIT license (as of 2010-Jan-1) because
		it is the closest ‚Äústandard‚Äù license to our intent.  If we had our way,
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
	Version: 1.0.0
	Imports: [
		%dialects/fsm.r "Used for the state machine"
		%parsers/ml-parser.r "Used to parse the HTML text"
		%mezz/normalize-html.r "Used to normalize the HTML before converting it"
	]
	Globals: [
		html-to-text {Made global so that it's easy to use in non-modules}
	]
]

stage3: func [command command-data][
	process-event stage3-fsm command command-data
]
init-stage3: does [
	out: make string! 1024
	uri-base: none
	clear links
	clear indent
	reset-fsm/only stage3-fsm
]
end-stage3: does [
	reset-fsm stage3-fsm
	emit newline
	forall links [
		emit [#"[" index? links "] "]
		emit-uri links/1
		emit newline
	]
	out
]

links: []

para-buffer: ""
stage3-fsm: make-fsm [
	initial-state: [
		<html> in-html
	]
	in-html: [
		<head> in-head (unless empty? out [emit newline])
		<body> in-body
		</html> return
	]
	in-head: [
		</head> return
		<title> in-title
		<base/> (uri-base: any [select data 'href uri-base])
		<style> in-style
	]
	in-style: [
		</style> return
	]
	in-title: [
		</title> return
	]
	in-body: [
		</body> return
		<style> in-style
		<h1> (clear para-buffer) in-para (
			uppercase para-buffer
			emit-para
			emit [
				indent copy/part {======================================================================} 70 - length? indent
				newline
				indent newline
			]
		)
		<h2> <h3> <h4> <h5> <h6> (clear para-buffer) in-para (
			uppercase para-buffer
			emit-para
			emit [indent newline]
		)
		<address> <p> <legend> (clear para-buffer) in-para (emit-para emit [indent newline])
		<pre> (clear para-buffer) in-pre (emit para-buffer)
		<ul> (increase-indent) in-ulist (decrease-indent emit [indent newline])
		<ol> (increase-indent count: any [if count*: select data 'start [attempt [to integer! count*]] 1]) in-olist (decrease-indent emit [indent newline])
		<dl> (increase-indent) in-dlist (decrease-indent emit [indent newline])
		<blockquote> (increase-indent) in-blockquote (decrease-indent)
		<table> (
			emit [
				indent copy/part {== TABLE =============================================================} 70 - length? indent
				newline
			]
		) in-table (
			emit [
				indent copy/part {======================================================================} 70 - length? indent
				newline
				indent newline
			]
		)
		<hr/> (emit [
				indent copy/part {----------------------------------------------------------------------} 70 - length? indent
				newline
				indent newline
			])
	]
	in-blockquote: inherit in-body [
		</blockquote> return
	]
	in-para: [
		</h1> </h2> </h3> </h4> </h5> </h6> </address> </p>
		</dt> </pre> </caption> </legend>
		return
		<a> (append links select data 'href) in-link (repend para-buffer [" [" length? links "] "])
		<select> in-select
		<q> (record #{E2809C})
		</q> (record #{E2809D})
		<img/> (record "[IMAGE]")
		<br/> (emit-para)
		whitespace: (record " ")
		text: (record data)
	]
	in-pre: inherit in-para [
		text: whitespace: (record data)
		<br/> (record newline)
	]
	in-link: inherit in-para [
		</a> return
	]
	in-item: inherit in-para [
		</li> </dt> </dd> </td> </th> return
	]
	in-ulist: [
		<li> (clear para-buffer) in-item (emit-para/with " * ")
		<ul> (increase-indent) in-ulist (decrease-indent)
		<ol> (increase-indent) in-olist (decrease-indent)
		</ul> </ol> return
	]
	in-olist: inherit in-ulist [
		<li> (
			clear para-buffer
			if all [
				count*: select data 'value
				attempt [count*: to integer count*]
			][
				count: count*
			]
		) in-item (emit-para/with rejoin [#" " count ". "] count: count + 1)
	]
	in-dlist: [
		<dt> (clear para-buffer) in-item (record #":" emit-para)
		<dd> (clear para-buffer) in-item (emit-para emit [indent newline])
		</dl> return
	]
	in-table: [
		<caption> (clear para-buffer emit [indent "Table caption:" newline]) in-para (emit-para emit [indent newline])
		<thead> <tfoot> <tbody> (emit [
				indent copy/part {----------------------------------------------------------------------} 70 - length? indent
				newline
			]) in-rows
		<tr> continue in-rows
		</table> return
	]
	in-rows: [
		<tr> (
			emit [indent "--" newline]
		) in-cells
		</thead> </tfoot> </tbody> return
		</table> 2 return
	]
	in-cells: [
		<td> <th> (append indent "   || " emit [indent "||" newline]) in-cell (decrease-indent)
		</tr> return
	]
	in-cell: inherit in-body [
		</td> </th> return
		text: (clear para-buffer) continue in-cell-para (emit-para)
	]
	in-cell-para: inherit in-para [
		</td> </th> 2 return
	]
	in-select: [
		</select> return
	]
]

emit: func [value] [repend out value]

indent: ""
increase-indent: does [append indent "      "]

decrease-indent: does [clear skip tail indent -6]

break-at: complement charset [#"0" - #"9" #"A" - #"Z" #"a" - #"z" {"'#$%&([^{@} #"Ä" - #"ˇ"]

emit-para: has [pos /with bullet] [
	emit indent
	if bullet [
		change skip tail out negate length? bullet bullet
		bullet: none
	]
	while [(length? para-buffer) > (70 - length? indent)] [
		pos: skip para-buffer 71 - length? indent
		pos: find/reverse pos break-at
		if any [not pos (index? pos) <= index? para-buffer] [
			pos: skip para-buffer 71 - length? indent
			pos: any [find pos break-at tail pos]
		]
		pos: next pos
		insert/part tail out para-buffer para-buffer: pos
		emit newline
		emit indent
	]
	emit para-buffer
	emit newline
	clear para-buffer: head para-buffer
]

record: func [text][
	append para-buffer text
]

emit-uri: func [uri][
	if uri-base [emit uri-base]
	emit uri
]

html-to-text: func [
	"Convert HTML to plain text"
	html [string!]
][
	init-stage3
	init-normalizer :stage3
	parse-ml html :process-tag
	reset-normalizer
	end-stage3
]
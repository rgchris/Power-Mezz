Rebol [
	Title: "Parse HTML text into a tree"
	File: %load-html.r
	Type: 'Module
	Purpose: {
		Given an HTML text string, produces a tree representation of the document.
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
	Version: 1.1.4
	Imports: [
		%parsers/ml-parser.r
		%mezz/niwashi.r
		%mezz/trees.r
		%mezz/expand-macros.r
		%mezz/text-encoding.r
		%mezz/macros/trees.r
	]
	Exports: [
		load-html
		form-html
	]
]

load-html: func [
	"Load HTML text into a tree"
	html [string!]
	/with niwashi-rules [block!] "Use transformation rules for the niwashi"
	/local
	attach? result html-node head-node body-node title-node
][
	niwashi: make-niwashi
	define-rules niwashi html-rules
	if niwashi-rules [
		define-rules niwashi niwashi-rules
	]
	parse-ml html func [cmd data][
		switch cmd [
			text whitespace comment declaration xml-proc [
				append-child niwashi [type: cmd properties: [value: data]]
			]
			<html> <head> <title> <script> <style> <object> [
				enter-child niwashi [type: tag-to-word cmd properties: data]
			]
			<body> <legend> <caption> <fieldset> <noscript> <ins> <del> <iframe> <tt> <i> <b> <u>
			<strike> <s> <big> <small> <sub> <sup> <em> <strong> <dfn> <code> <samp> <kbd> <var>
			<cite> <font> <select> <textarea> <button> <optgroup> <label> <span> <abbr>
			<acronym> <q> <applet> [
				attempt [
					split-branch niwashi 'head
					leave-child niwashi
				]
				enter-child niwashi [type: tag-to-word cmd properties: data]
			]
			<isindex> <isindex/> <base> <base/> <script/> <meta> <meta/> <link> <link/> <param> <param/> [
				append-child niwashi [type: tag-to-word cmd properties: data]
			]
			<col> <col/> <br> <br/> <basefont> <basefont/> <area> <area/> <input> <input/> [
				attempt [
					split-branch niwashi 'head
					leave-child niwashi
				]
				append-child niwashi [type: tag-to-word cmd properties: data]
			]
			<h1> <h2> <h3> <h4> <h5> <h6> <address> <p> <ul> <ol> <dl> <pre> <dt> <dd>
			<div> <center> <blockquote> [
				open-tag tag-to-word cmd data [h1 h2 h3 h4 h5 h6 address p dt dd] [table]
			]
			<table> [
				open-tag 'table data [h1 h2 h3 h4 h5 h6 address dt dd] []
			]
			<li> [
				open-tag 'li data [li h1 h2 h3 h4 h5 h6 address p dt dd] [ul ol]
			]
			<form> [
				open-tag 'form data 'form []
			]
			<tr> [
				open-tag 'tr data [tr td th colgroup] 'table
			]
			<td> <th> [
				open-tag tag-to-word cmd data [td th] 'table
			]
			<thead> <tfoot> <tbody> [
				open-tag tag-to-word cmd data [thead tfoot tbody tr td th colgroup] 'table
			]
			<colgroup> [
				open-tag 'colgroup data 'colgroup 'table
			]
			<hr> <hr/> [
				attach?: no
				unless attempt [
					split-branch niwashi 'head
					leave-child niwashi
					true
				][
					attempt [
						split-branch/knots niwashi [h1 h2 h3 h4 h5 h6 address p dt] 'table
						leave-child niwashi
						attach?: yes
					]
				]
				append-child niwashi [type: 'hr properties: data]
				if attach? [attach-branch niwashi]
			]
			<a> <map> <option> [
				open-tag cmd: tag-to-word cmd data cmd []
			]
			</tt> </i> </b> </u> </strike> </s> </big> </small> </sub> </sup>
			</em> </strong> </dfn> </code> </samp> </kbd> </var> </cite>
			</a> </font> </map> </label> </span> </abbr> </acronym> </q> [
				attempt [
					split-branch niwashi tag-to-word cmd
					leave-child niwashi
					attach-branch niwashi
				]
			]
			<img> <img/> <image> <image/> [
				attempt [
					split-branch niwashi 'head
					leave-child niwashi
				]
				append-child niwashi [type: 'img properties: data]
			]
			</head> </title> </script> </style> </object> </legend> </caption>
			</fieldset> </noscript> </ins> </del> </iframe>
			</h1> </h2> </h3> </h4> </h5> </h6> </address> </ul> </ol> </li> </dl> </dt>
			</dd> </pre> </div> </center> </blockquote> </form> </table>
			</tr> </td> </th> </colgroup> </thead> </tfoot> </tbody>
			</select> </textarea> </button> </option> </optgroup> [
				attempt [
					split-branch niwashi tag-to-word cmd
					leave-child niwashi
				]
			]
			</p> [
				attempt [
					split-branch/knots niwashi 'p 'table
					leave-child niwashi
				]
			]
		]
	]
	leave-all niwashi
	result: niwashi/root
	either html-node: get-node result/childs/html [
		unless body-node: get-node html-node/childs/body [
			body-node: make-node 'body
			set-node body-node/parent: html-node
		]
		unless head-node: get-node html-node/childs/head [
			head-node: make-tree [head [] [title []]]
			set-node body-node/previous: head-node
		]
		unless get-node head-node/childs/title [
			either empty? get-node head-node/childs [
				title-node: make-node 'title
				set-node title-node/parent: head-node
			][
				set-node head-node/childs/1/previous: make-node 'title
			]
		]
	][
		enter-child niwashi [type: 'html]
		enter-child niwashi [type: 'head]
		append-child niwashi [type: 'title]
		leave-child niwashi
		append-child niwashi [type: 'body]
		leave-child niwashi
	]
	result
]

form-html: func [
	{Forms a HTML tree (eg. from LOAD-HTML) into HTML text}
	html [block!]
	/with options "Specify format options"
][
	options: make default-fh-options any [options []]
	emit-childs copy "" html copy "" pick [html-utf8 html-ascii] to logic! options/utf8? to logic! options/pretty?
]

inside-flow: [
	on whitespace add-space
	on text merge-text
	ignore [td th caption tr thead tbody tfoot col colgroup]
	after [
		p h1 h2 h3 h4 h5 h6 ul ol dir menu pre dl div center noscript noframes
		blockquote form isindex hr table fieldset address
	] outside-flow
]

outside-flow: [
	ignore [td th caption tr thead tbody tfoot col colgroup whitespace]
	after [
		text tt i b u s strike big small em strong dfn code samp kbd var cite abbr acronym
		a font q sub sup span bdo
	] inside-flow
]

html-rules: [
	except [html comment declaration xml-proc] force html
	ignore whitespace
	inside html [
		except [comment head body] force body
		ignore [whitespace html declaration xml-proc]
		on [title isindex base script style meta link object] force head
		inside head [
			ignore [whitespace head html declaration xml-proc]
			inside title [
				on text merge-text
				after text [
					on text merge-text
					on whitespace add-space
					ignore [declaration xml-proc html head title script style object]
				]
				ignore [whitespace declaration xml-proc html head title script style object]
			]
			inside object [
				only param
			]
		]
		inside body outside-flow
		inside body [
			always [
				ignore [declaration xml-proc html head body]
				on legend force fieldset
				on style move-to-head
				inside [pre textarea] [
					always [
						ignore [td th caption tr thead tbody tfoot col colgroup]
						on [text whitespace] preserve-whitespace
						on br add-newline
					]
				]
				inside all but [table thead tbody tfoot tr td th caption colgroup select] [
					ignore [td th caption tr thead tbody tfoot col colgroup option optgroup]
				]
				inside table [
					only [thead tfoot tbody tr td caption th col colgroup]
					on tr force tbody
					on [td th] force tr
					inside caption inside-flow
					inside [thead tfoot tbody] [
						only [tr td th]
						on [td th] force tr
						inside tr [
							only [td th]
							inside [td th] inside-flow
						]
					]
					inside colgroup [
						only col
					]
				]
				inside select [
					only [option optgroup]
				]
				inside optgroup [
					only option
				]
				inside [
					blockquote center dd del div dl fieldset form ins legend li noscript ol
					ul
				] outside-flow
				inside [
					h1 h2 h3 h4 h5 h6 p address dt caption td th
					tt i b u s strike big small em strong dfn code samp kbd var cite abbr acronym
					a applet object font map q sub sup span bdo iframe
					option textarea label button
				] inside-flow
			]
		]
	]
]
!set-node-value-quick: macro [node val] [(:poke) node 3 (:reduce) ['value val]]

merge-text: func [node /local prev] expand-macros [
	if all [prev: !get-node-previous node 'text = !get-node-type prev] [
		insert tail !get-node-property prev 'value !get-node-property node 'value
		!remove-node-quick node
	]
]

add-space: func [node /local prev text] expand-macros [
	either all [prev: !get-node-previous node 'text = !get-node-type prev] [
		text: !get-node-property prev 'value
		unless #" " = last text [insert tail text #" "]
		!remove-node-quick node
	][
		!set-node-type node 'text
		!set-node-value-quick node (copy " ")
	]
]

preserve-whitespace: func [node] expand-macros [
	!set-node-type node 'text
	merge-text node
]

add-newline: func [node] expand-macros [
	!set-node-properties node (copy/deep [value "^/"])
	preserve-whitespace node
]

move-to-head: func [node /local head-node root][
	root: niwashi/root
	unless head-node: get-node root/childs/html/childs/head [
		head-node: make-node 'head
		set-node root/childs/html/childs/body/previous: head-node
	]
	set-node node/parent: head-node
]

default-fh-options: context [
	pretty?: false
	utf8?: false
]

tag-to-word: func [tag] compose [(:to) (word!) (:lowercase) trim/with (:to) (string!) tag #"/"]

open-tag: func [type prop split knots /local attach?][
	unless attempt [
		split-branch niwashi 'head
		leave-child niwashi
		true
	][
		attach?: attempt [
			split-branch/knots niwashi split knots
			leave-child niwashi
			true
		]
	]
	enter-child niwashi [type: type properties: prop]
	if attach? [attach-branch niwashi]
]
!emit: macro [value] [(:insert) (:tail) output value]
!indent: macro [] [(:head) (:insert) (:tail) (:copy) indent "    "]
!emit-attributes: macro [attributes encoding] [(:foreach) [attrname attrvalue] attributes [(:if) :attrvalue [(:either) (:word?) attrname [(:insert) (:insert) (:insert) (:tail) output #" " attrname {="}
				encode-text/to :attrvalue encoding output (:insert) (:tail) output #"^""
			] [(:insert) (:insert) (:insert) (:insert) (:insert) (:tail) output
				#" " (:pick) attrname 1 #":" (:pick) attrname 2 {="}
				encode-text/to :attrvalue encoding output (:insert) (:tail) output #"^""
			]]]]
!open-tag: macro [name attributes encoding] expand-macros [(:insert) (:insert) (:tail) output #"<" name
	!emit-attributes attributes encoding (:insert) (:tail) output #">"
]
!empty-tag: macro [name attributes encoding] expand-macros [(:insert) (:insert) (:tail) output #"<" name
	!emit-attributes attributes encoding (:insert) (:tail) output " />"
]
!close-tag: macro [name] [(:insert) (:insert) (:insert) (:tail) output "</" name #">"]
!emit-cdata: macro [text] [(:insert) (:insert) (:insert) (:tail) output
	"^//* <![CDATA[ */^/"
	text
	"^//* ]]> */^/"
]
!get-inside-text: macro [node] expand-macros [(:either) (:empty?) !get-node-childs node [""] [(:select) (:third) (:fourth) node 'value]]

emit-childs: func [output node indent encoding pretty? /local type] expand-macros [
	foreach child !get-node-childs node [
		switch/default type: !get-node-type child [
			text whitespace [
				encode-text/to !get-node-property child 'value encoding output
			]
			xml-proc declaration [
				!emit (!get-node-property child 'value)
				if pretty? [
					insert !emit #"^/" indent
				]
			]
			comment [
				!emit (!get-node-property child 'value)
			]
			style [
				!open-tag 'style (!get-node-properties child) encoding
				!emit-cdata (!get-inside-text child)
				if pretty? [!emit indent]
				!close-tag 'style
				if pretty? [insert !emit #"^/" indent]
			]
		][
			either find [
				base link hr area input img br col isindex script meta
				basefont
			] type [
				!empty-tag type (!get-node-properties child) encoding
			][
				!open-tag type (!get-node-properties child) encoding
				if all [
					pretty?
					find [
						html head script style object body noscript
						ul ol dl div center blockquote
						table form tr thead tfoot tbody
					] type
				][
					insert !emit "^/    " indent
				]
				emit-childs output child !indent encoding pretty?
				!close-tag type
			]
			if all [
				pretty?
				find [
					html head title script style object body legend caption
					fieldset noscript iframe isindex base meta link br basefont
					h1 h2 h3 h4 h5 h6 address p ul ol dl pre dt dd div center blockquote
					table li form tr td th thead tfoot tbody hr
				] type
			][
				insert !emit #"^/" indent
			]
		]
	]
	output
]
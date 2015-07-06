Rebol [
	Title: "HTML Filter"
	File: %filter-html.r
	Type: 'Module
	Purpose: {
		Filters HTML text removing any potential security treat;
		allows embedding some HTML coming from an untrusted source
		in a web page without creating security holes for the web site.
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
	Version: 4.1.0
	Imports: [
		%parsers/common-rules.r "We need the NAME rule"
		%mezz/load-html.r "Used to load the HTML text and to form the result"
		%parsers/uri-parser.r "Used to check and normalize the URLs"
		%mezz/trees.r "Used to represent the HTML document"
		%mezz/expand-macros.r "Used for optimizations"
		%mezz/macros/trees.r "Used for optimizations"
	]
	Globals: [
		filter-html {Made global so that it's easy to use in non-modules}
	]
]

filter-rules: [
	always [
		ignore [object param applet comment meta]
		on script remove-script
		except [text whitespace xml-proc declaration] check-attributes
		inside style [
			on text sanitize-style
		]
		on [i u b em strong span strike] unwrap-empty-fmt
		on [i u b em strong span strike] merge-with-previous
		on a remove-empty-a
		on span unwrap-noattrs
	]
]

xhtml: {<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">}
html4: {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">}
default-options: context [
	all: no
	id-prefix: none
	emit-utf8: no
	filter-uris: none
	pretty-print: no
]

attributes-map: [
	body [
		background [style* uri "background-image"] none
		text [style* color "color"] none
		link color none
		vlink color none
		alink color none
	]
	title []
	base [
		href uri none
		target [enum "_blank"] none
	]
	style [
		type force "text/css"
		media media-desc none
	]
	link [
		href uri none
		hreflang name* none
		type cdata none
		rel name-list none
		rev name-list none
		charset cdata none
		target [enum "_blank"] none
		media media-desc none
	]
	ul [
		type [style* [enum "disc" "circle" "square"] "list-style-type"] none
	]
	ol [
		type [style* list-style "list-style-type"] none
		start number none
	]
	blockquote [cite uri none]
	form [
		action force "#"
		method force "GET"
		name name* none
	]
	table [
		summary cdata none
		align [enum "left" "center" "right"] none
		width [style* lengthpx "width"] none
		frame [
			enum "void" "above" "below" "hsides"
			"lhs" "rhs" "vsides" "box" "border"
		] none
		rules [
			enum "none" "groups" "rows" "cols" "all"
		] none
		border [style* pixels "border-width"] none
		cellspacing length none
		cellpadding length none
	]
	ins [
		cite uri none
		datetime cdata none
	]
	del [
		cite uri none
		datetime cdata none
	]
	hr [
		align [enum "left" "right" "center"] none
		noshade [bool "noshade"] none
		size number none
		width length none
	]
	br [clear brclear none]
	a [
		name cdata none
		href uri none
		hreflang name* none
		type cdata none
		rel name-list none
		rev name-list none
		charset cdata none
		target [enum "_blank"] none
		shape [enum "default" "rect" "circle" "poly"] none
		coords cdata none
	]
	map [name name* none]
	area [
		shape [enum "default" "rect" "circle" "poly"] none
		coords cdata none
		nohref [bool "nohref"] none
		alt cdata none
		href uri none
		target [enum "_blank"] none
	]
	select [
		name name* none
		size number none
		multiple [bool "multiple"] none
		disabled force "disabled"
	]
	textarea [
		name name* none
		rows number none
		cols number none
		readonly [bool "readonly"] none
		disabled force "disabled"
	]
	button [
		name name* none
		value cdata none
		type [enum "submit" "button" "reset"] none
		disabled force "disabled"
	]
	label [for name* none]
	input [
		type [
			enum "text" "password" "checkbox" "radio"
			"submit" "reset" "file" "hidden"
			"image" "button"
		] none
		name name* none
		value cdata none
		size number none
		maxlength number none
		checked [bool "checked"] none
		src uri none
		alt cdata none
		accept cdata none
		readonly [bool "readonly"] none
		disabled force "disabled"
		usemap uri none
		ismap [bool "ismap"] none
	]
	q [cite uri none]
	img [
		src uri none
		alt cdata none
		longdesc uri none
		name name* none
		usemap uri none
		ismap [bool "ismap"] none
		width length none
		height length none
		hspace [imgmargin "left" "right"] none
		vspace [imgmargin "top" "bottom"] none
		border [style* pixels "border-width"] none
		align imgalign none
	]
	li [
		type [style* list-style "list-style-type"] none
		value number none
	]
	colgroup [
		span number none
		width multi-length none
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
	]
	col [
		span number none
		width multi-length none
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
	]
	thead [
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
	]
	tfoot [
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
	]
	tbody [
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
	]
	tr [
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
	]
	td [
		headers name-list none
		scope [enum "row" "col" "rowgroup" "colgroup"] none
		abbr cdata none
		axis cdata none
		rowspan number none
		colspan number none
		nowrap [style* [bool "nowrap"] "white-space"] none
		width [style* lengthpx "width"] none
		height [style* lengthpx "height"] none
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
		background [style* uri "background-image"] none
	]
	th [
		headers name-list none
		scope [enum "row" "col" "rowgroup" "colgroup"] none
		abbr cdata none
		axis cdata none
		rowspan number none
		colspan number none
		nowrap [style* [bool "nowrap"] "white-space"] none
		width [style* lengthpx "width"] none
		height [style* lengthpx "height"] none
		valign [style* [enum "baseline" "top" "bottom" "middle"] "vertical-align"] none
		background [style* uri "background-image"] none
	]
	option [
		selected [bool "selected"] none
		value cdata none
		label cdata none
		disabled force "disabled"
	]
	optgroup [
		label cdata none
		disabled force "disabled"
	]
	font [
		size font-size none
		color [style* color "color"] none
		face [style* cdata "font-family"] none
	]
]
!set-assoc: macro [assoc word value] [(:either) _pos: (:find) assoc word [(:poke) _pos 2 value/only] [
		insert/only (:insert) (:tail) assoc word value/only
	]]

check-attributes: func [node /local attributes valid-attributes value uris name node-properties pos] expand-macros [
	name: !get-node-type node
	attributes: !get-node-properties node
	node-properties: reduce [
		'lang any [
			process-attr select attributes 'xml/lang 'name* none
			process-attr select attributes 'lang 'name* none
		]
	]
	style: copy ""
	uris: clear []
	valid-attributes: any [
		select attributes-map name []
	]
	foreach [attr-name type defvalue] union/skip valid-attributes global-attrs 3 [
		insert/only insert tail node-properties attr-name
		value: process-attr select attributes attr-name type defvalue
		if all [type = 'uri value] [
			append uris attr-name
		]
	]
	foreach uri uris [
		pos: find node-properties uri
		either filter-uris? [
			value: current-options/filter-uris make pick pos 2 [
				tag-name: name
				attribute-name: uri
				target: get-node node/prop/target
			]
			either object? value [
				poke pos 2 form-uri value
				!set-assoc node-properties 'target value/target
			][
				poke pos 2 value
			]
		][
			value: pick pos 2
			poke pos 2 either find [#[none] "http" "https" "ftp" "telnet" "news" "mailto" "nntp" "gopher"] value/scheme [
				form-uri value
			][
				none
			]
		]
	]
	if value: select attributes 'style [
		append style value
	]
	if not empty? style [
		!set-assoc node-properties 'style (sanitize-css style)
	]
	fix-attrs node-properties
	!set-node-properties node node-properties
]

fix-attrs: func [attributes /local lang id val pos][
	if lang: select attributes 'lang [
		insert insert/only tail attributes 'xml/lang lang
	]
	if all [pos: find attributes 'id current-options/id-prefix] [
		poke pos 2 join current-options/id-prefix pick pos 2
	]
	forskip attributes 2 [
		if all [string? val: pick attributes 2 empty? val] [poke attributes 2 #[none]]
	]
	attributes
]

non-paren: complement charset "()"

parens: [
	#"(" any non-paren any [parens any non-paren] #")"
]

sanitize-css: func [css-text [string! none!] /local mk1 mk2][
	if string? css-text [
		parse/all css-text [
			any [
				to "/*" mk1: thru "*/" mk2: (mk1: remove/part mk1 mk2) :mk1
			]
		]
		parse/all css-text [
			any [
				to "expression" mk1: "expression" [
					any space-char parens mk2: (mk1: remove/part mk1 mk2) :mk1
					|
					none
				]
			]
		]
		css-text
	]
]

process-attr: func [value type defvalue /local opts][
	switch defvalue [none [defvalue: none]]
	unless value [return defvalue]
	if block? type [opts: next type type: first type]
	type: get in attr-types type
	value: any [type value opts defvalue]
]

attr-types: context [
	enum: func [value opts][
		if value: find opts value [value/1]
	]
	name*: func [value opts][
		if parse/all trim/lines value [name] [value]
	]
	name-list: func [value opts][
		if parse/all trim/lines value [name any [" " name]] [
			value
		]
	]
	force: func [value opts] [none]
	style*: func [value opts][
		if value: process-attr value opts/1 none [
			repend style either opts/1 = 'uri [[opts/2 ": url('" form-uri value "');"]] [[opts/2 ": " value ";"]]
		]
		none
	]
	color: func [value opts][
		if parse/all trim/lines value [
			"#" 3 6 hexdigit
			|
			"aliceblue" | "antiquewhite" | "aqua" | "aquamarine" | "azure" |
			"beige" | "bisque" | "black" | "blanchedalmond" | "blue" |
			"blueviolet" | "brown" | "burlywood" | "cadetblue" | "chartreuse" |
			"chocolate" | "coral" | "cornflowerblue" | "cornsilk" | "crimson" |
			"cyan" | "darkblue" | "darkcyan" | "darkgoldenrod" | "darkgray" |
			"darkgreen" | "darkkhaki" | "darkmagenta" | "darkolivegreen" |
			"darkorange" | "darkorchid" | "darkred" | "darksalmon" |
			"darkseagreen" | "darkslateblue" | "darkslategray" | "darkturquoise" |
			"darkviolet" | "deeppink" | "deepskyblue" | "dimgray" |
			"dodgerblue" | "feldspar" | "firebrick" | "floralwhite" |
			"forestgreen" | "fuchsia" | "gainsboro" | "ghostwhite" | "gold" |
			"goldenrod" | "gray" | "green" | "greenyellow" | "honeydew" |
			"hotpink" | "indianred" | "indigo" | "ivory" | "khaki" | "lavender" |
			"lavenderblush" | "lawngreen" | "lemonchiffon" | "lightblue" |
			"lightcoral" | "lightcyan" | "lightgoldenrodyellow" | "lightgreen" |
			"lightgrey" | "lightpink" | "lightsalmon" | "lightseagreen" |
			"lightskyblue" | "lightslateblue" | "lightslategray" |
			"lightsteelblue" | "lightyellow" | "lime" | "limegreen" | "linen" |
			"magenta" | "maroon" | "mediumaquamarine" | "mediumblue" |
			"mediumorchid" | "mediumpurple" | "mediumseagreen" |
			"mediumslateblue" | "mediumspringgreen" | "mediumturquoise" |
			"mediumvioletred" | "midnightblue" | "mintcream" | "mistyrose" |
			"moccasin" | "navajowhite" | "navy" | "oldlace" | "olive" |
			"olivedrab" | "orange" | "orangered" | "orchid" | "palegoldenrod" |
			"palegreen" | "paleturquoise" | "palevioletred" | "papayawhip" |
			"peachpuff" | "peru" | "pink" | "plum" | "powderblue" | "purple" |
			"red" | "rosybrown" | "royalblue" | "saddlebrown" | "salmon" |
			"sandybrown" | "seagreen" | "seashell" | "sienna" | "silver" |
			"skyblue" | "slateblue" | "slategray" | "snow" | "springgreen" |
			"steelblue" | "tan" | "teal" | "thistle" | "tomato" | "turquoise" |
			"violet" | "violetred" | "wheat" | "white" | "whitesmoke" | "yellow" |
			"yellowgreen" | "transparent"
		][
			value
		]
	]
	uri: func [value opts][
		make parse-uri/relative value [
			source-uri: value
		]
	]
	cdata: func [value opts] [if value [trim/lines value]]
	media-desc: func [value opts /local names nm][
		names: clear []
		if all [value parse/all trim/lines value [
				copy nm name (append names nm)
				any [
					thru "," opt " " copy nm name (append names nm)
				]
				to end
			]] [
			names: intersect names [
				"screen" "tty" "tv" "projection" "handheld"
				"print" "braille" "aural" "all"
			]
			if empty? names [return none]
			value: copy first names
			foreach name next names [
				repend value [", " name]
			]
			value
		]
	]
	list-style: func [value opts][
		if find ["disc" "circle" "square"] value [return value]
		select/case [
			"1" "decimal" #[none]
			"a" "lower-alpha" #[none]
			"A" "upper-alpha" #[none]
			"i" "lower-roman" #[none]
			"I" "upper-roman" #[none]
		] value
	]
	number: func [value opts][
		if parse/all trim/lines value [some digit] [value]
	]
	pixels: func [value opts][
		if parse/all trim/lines value [some digit] [append value "px"]
	]
	bool: func [value opts][
		opts/1
	]
	length: func [value opts][
		if parse/all trim/lines value [some digit opt "%"] [value]
	]
	lengthpx: func [value opts][
		if parse/all trim/lines value [some digit ["%" | (append value "px") to end]] [value]
	]
	multi-length: func [value opts][
		if parse/all trim/lines value [some digit ["%" | "*" | none]] [value]
	]
	font-size: func [value opts][
		trim/lines value
		any [
			if find [
				"1" "2" "3" "4" "5" "6" "7" "+1" "+2" "+3" "+4" "+5" "+6" "+7"
				"-1" "-2" "-3" "-4" "-5" "-6" "-7"
			] value [value]
			length value none
		]
	]
	imgmargin: func [value opts][
		if value: number value none [
			repend style [
				"margin-" opts/1 ": " value "px;"
				"margin-" opts/2 ": " value "px;"
			]
		]
		none
	]
	imgalign: func [value opts][
		append style any [select [
				"bottom" "vertical-align: bottom;" #[none]
				"middle" "vertical-align: middle;" #[none]
				"top" "vertical-align: top;" #[none]
				"left" "float: left;" #[none]
				"right" "float: right;" #[none]
			] value ""]
		none
	]
	brclear: func [value opts][
		append style any [select [
				"none" "clear: none;" #[none]
				"left" "clear: left;" #[none]
				"right" "clear: right;" #[none]
				"all" "clear: both;" #[none]
			] value ""]
		none
	]
]

global-attrs: [
	dir [enum "LTR" "RTL"] none
	id name* none
	class name-list none
	title cdata none
	bgcolor [style* color "background-color"] none
	align [enum "left" "center" "middle" "right" "justify"] none
]

sanitize-style: func [node] expand-macros [
	sanitize-css !get-node-property node 'value
]

unwrap-empty-fmt: func [node /local childs] expand-macros [
	if !get-node-parent node [
		childs: !get-node-childs node
		if any [
			empty? childs
			br-only? childs
		][
			unwrap-node node
		]
	]
]
br-only?: func [childs /local node] expand-macros [
	all [1 = length? childs
		node: first childs
		'br = !get-node-type node
	]
]

remove-empty-a: func [node] expand-macros [
	if all [
		empty? !get-node-childs node
		not !get-node-property node 'name
	][
		!remove-node-quick node
	]
]

unwrap-noattrs: func [node] expand-macros [
	if !get-node-parent node [
		unless foreach [name value] !get-node-properties node [
			unless none? value [break/return true]
		][
			unwrap-node node
		]
	]
]

merge-with-previous: func [node /local prev] expand-macros [
	if all [
		prev: !get-node-previous node
		equal? !get-node-type node !get-node-type prev
		equal? !get-node-properties node !get-node-properties prev
	][
		set-node node/parent: prev
		unwrap-node node
	]
]

remove-script: func [node] expand-macros [
	!remove-node-quick node
]

filter-html: func [
	"Sanitize HTML text"
	html [string!]
	/all {Return a complete HTML document (including <html> tag, <head> etc.)}
	/with options [block!] "Specify options for the filter"
	/local
	tree result node lang doctype
][
	options: make default-options any [options []]
	if all [options/all: yes]
	current-options: options
	filter-uris?: any-function? get in options 'filter-uris
	tree: load-html/with html filter-rules
	either options/all [
		result: make-node 'root
		doctype: get-node tree/childs/declaration
		doctype: case [
			none? doctype ['none]
			xhtml = get-node doctype/prop/value [
				node: make-node 'xml-proc
				set-node node/prop/value: <?xml version="1.0" encoding="UTF-8"?>
				set-node node/parent: result
				node: make-node 'declaration
				set-node node/prop/value: xhtml
				set-node node/parent: result
				'xhtml
			]
			html4 = get-node doctype/prop/value [
				node: make-node 'declaration
				set-node node/prop/value: html4
				set-node node/parent: result
				'html4
			]
			'else ['none]
		]
		html: make-node 'html
		if doctype = 'xhtml [
			set-node html/prop/xmlns: http://www.w3.org/1999/xhtml
		]
		set-node html/parent: result
		if lang: get-node tree/childs/html/prop/lang [
			set-node html/properties: [lang: lang xml/lang: lang]
		]
		node: get-node tree/childs/html/childs/head
		set-node node/parent: html
		node: get-node tree/childs/html/childs/body
		set-node node/parent: html
	][
		result: get-node tree/childs/html/childs/body
	]
	form-html/with result [
		utf8?: options/emit-utf8
		pretty?: options/pretty-print
	]
]
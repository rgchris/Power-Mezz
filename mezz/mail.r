Rebol [
	Title: "EMail related functions"
	File: %mail.r
	Type: 'Module
	Purpose: {
		This module exports a number of functions useful to handle e-mail messages.
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
	Version: 1.0.0
	Imports: [
		%mezz/text-encoding.r
	]
	Exports: [
		decode-email-field
		encode-email-field
		parse-email-address
		form-email-address
		build-attach-body
	]
]

parser: context [
	encoded-field: [
		any [
			copy mk1 some normal-chars (decode-text/to mk1 'latin1 result)
			|
			"=?"
			copy ew-charset some ew-chars #"?"
			copy ew-encoding some ew-chars #"?"
			copy ew-text any ew-chars
			"?=" (decode-text* result ew-charset ew-encoding any [ew-text ""])
			|
			skip (append result #"=")
		]
	]
	result: none
	normal-chars: complement charset "="
	mk1: mk2: none
	ew-charset: ew-encoding: ew-text: none
	ew-chars: complement charset { ^-^M
?}
	do-parse: func [field][
		result: make string! 256
		parse/all field encoded-field
		result
	]
	decode-text*: func [
		output [string!]
		charset [string!]
		encoding [string!]
		text [string!]
	][
		switch/default encoding [
			"Q" [
				text: decode-text text 'quoted-printable+
			]
			"B" [
				text: as-string debase/base text 64
			]
		][
			charset: "utf-8"
			text: rejoin ["[Unsupported encoding: " encoding "] " text]
		]
		conv-chset output charset text
	]
	conv-chset: func [output charset text][
		charset: to block! charset
		unless all [
			parse charset [word!]
			not error? try [decode-text/to text charset/1 output]
		][
			repend output ["[Unsupported charset: " charset "]" either find text newline [newline] [#" "] text]
		]
		output
	]
]

decode-email-field: func [text][
	parser/do-parse text
]

printable-ascii: charset [#" " - #"^~"]

encode-email-field: func [text /local output][
	either parse/all text [any printable-ascii] [
		text
	][
		output: copy "=?UTF-8?Q?"
		encode-text/to text 'quoted-printable+ output
		append output "?="
	]
]

address-parser: context [
	focus: result: []
	address-list: [any space address any [any space #"," any space address]]
	address: [mailbox | group]
	mailbox: [
		name-addr | addr-name
		|
		addr-spec (insert insert tail focus copy "" addr)
		|
		display-name (insert insert tail focus name noaddress@nowhere.net)
	]
	name-addr: [[display-name | (name: copy "")] angle-addr (insert insert tail focus name addr)]
	name: none
	addr: none
	addr-name: [addr-spec any space #"(" display-name #")" any space (insert insert tail focus name addr)]
	angle-addr: [any space #"<" addr-spec #">" any space]
	space: charset " ^-^M^/"
	group: [
		display-name #":" (
			insert/only insert tail result name focus: make block! 16
		) opt mailbox-list any space #";" any space (
			focus: result
		)
		| (focus: result)
	]
	display-name: [quoted-string | copy name some atom (trim name)]
	atom: [any space some [atom-chars | #"\" skip] any space]
	atom-chars: complement charset { ^-^M
()<>[]:;@,"\}
	quoted-string: [any space #"^"" copy name any [quoted-chars | #"\" skip] (name: any [name copy ""]) #"^"" any space]
	quoted-chars: complement charset {"\}
	mailbox-list: [mailbox any [#"," mailbox]]
	addr-spec: [copy addr [some email-chars #"@" some email-chars] (addr: to email! addr)]
	email-chars: complement charset {@ ^-^M
<>,}
	reset: does [
		focus: result: make block! 16
	]
]

parse-email-address: func [
	address [string!]
	/nodecode
][
	unless nodecode [
		address: decode-email-field address
	]
	address-parser/reset
	parse/all address address-parser/address-list
	address-parser/result
]

form-email-address: func [address /all /header /local res][
	if string? address [return address]
	if empty? address [return ""]
	res: copy ""
	either all [
		foreach [name email] address [
			if system/words/all [not empty? res any [name email]] [append res ", "]
			repend res [
				any [if name [either header [encode-email-field name] [name]] ""]
				either name [" <"] [""]
				any [email ""] either name [">"] [""]
			]
		]
	][
		foreach [name email] address [
			name: all [name not empty? name name]
			name: any [all name email ""]
			if system/words/all [not empty? res name <> ""] [append res ", "]
			append res name
		]
	]
	res
]

build-attach-body: func [
	"Return an email body with attached files."
	bodytype [string!] {The message body Content-Type (only text/* actually supported)}
	body [string!] "The message body"
	files [block!] {List of files to send [%file1.r [%file2.r "data"]]}
	boundary [string!] "The boundary divider"
	/local make-mime-header break-lines file val ct part-header
][
	make-mime-header: func [_Content-type file][
		if none? _Content-type [_Content-type: "application/octet-stream"]
		net-utils/export context [
			Content-Type: rejoin [_Content-type {; name="} file {"}]
			Content-Transfer-Encoding: "base64"
			Content-Disposition: join {attachment; filename="} [file {"
}]
		]
	]
	break-lines: func [mesg data /at num][
		num: any [num 72]
		while [not tail? data] [
			append mesg join copy/part data num #"^/"
			data: skip data num
		]
		mesg
	]
	body: encode-quoted-printable body
	if not empty? files [
		insert body reduce [
			boundary
			"^/Content-type: " bodytype "^/Content-Transfer-Encoding: quoted-printable^/^/"
		]
		append body "^/^/"
		if not parse files [
			some [(file: none ct: none part-header: false) [
					set file file! (val: read/binary file)
					| into [
						set file file!
						set val skip
						set ct skip
						to end
					]
					| into [
						set file file!
						set val skip
						to end
					]
					| into [
						set part-header skip
						set val skip
						to end
					]
				] (
					either file [
						repend body [
							boundary "^/"
							make-mime-header ct any [find/last/tail file #"/" file]
						]
						val: either any-string? val [val] [mold :val]
						break-lines body enbase val
					][
						if part-header [
							repend body [
								boundary "^/"
								part-header
								"^/"
							]
							val: either any-string? val [val] [mold :val]
							break-lines body val
						]
					]
				)]
		] [net-error "Cannot parse file list."]
		append body join boundary "--^/"
	]
	body
]
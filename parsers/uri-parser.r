Rebol [
	Title: "A standards-compliant URI parser"
	File: %uri-parser.r
	Type: 'Module
	Purpose: {
		Defines the PARSE-URI function, that can parse both absolute
		and relative URIs.
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
	Version: 2.0.1
	Imports: [
		%parsers/common-rules.r
		%mezz/text-encoding.r
	]
	Exports: [
		parse-uri "Parse a URI into its components"
		form-uri "Form an URI string from its components"
		decode-uri-fields "Decode the fields of a URI object"
		encode-uri-fields "Encode the fields of a URI object"
	]
]

uri-rule: [copy seg scheme-rule #":" (scheme: seg) hier-part opt [#"?" query-rule] opt [#"#" fragment-rule]]

hier-part: ["//" authority path-abempty | path-absolute | path-rootless | none]

uri-reference: [uri-rule | relative-ref]

absolute-uri: [copy seg scheme-rule #":" (scheme: seg) hier-part opt [#"?" query-rule]]

relative-ref: [relative-part opt [#"?" query-rule] opt [#"#" fragment-rule]]

relative-part: ["//" authority path-abempty | path-absolute | path-noscheme | none]

scheme-rule: [alpha-char any [alpha-char | digit | #"+" | #"-" | #"."]]

authority: [opt [copy seg userinfo-rule #"@" (userinfo: seg)] host-rule opt [#":" port-rule]]

userinfo-rule: [any [relaxed | pct-encoded | sub-delims | #":"]]

host-rule: [copy host [ip-literal | ipv4address | reg-name]]

port-rule: [copy port any digit]

ip-literal: [#"[" [ipvfuture | ipv6address] #"]"]

ipvfuture: [#"v" some hexdigit #"." some [unreserved | sub-delims | #":"]]
ipv6address: [
	6 [h16 #":"] ls32
	| "::" 5 [h16 #":"] ls32
	| opt h16 "::" 4 [h16 #":"] ls32
	| opt [h16 opt [#":" h16]] "::" 3 [h16 #":"] ls32
	| opt [h16 1 2 [#":" h16]] "::" 2 [h16 #":"] ls32
	| opt [h16 1 3 [#":" h16]] "::" h16 #":" ls32
	| opt [h16 1 4 [#":" h16]] "::" ls32
	| opt [h16 1 5 [#":" h16]] "::" h16
	| opt [h16 1 6 [#":" h16]] "::"
]
h16: [1 4 hexdigit]
ls32: [h16 #":" h16 | ipv4address]
ipv4address: [dec-octet #"." dec-octet #"." dec-octet #"." dec-octet]

dec-octet: ["25" digit0-5 | #"2" digit0-4 digit | #"1" 2 digit | digit1-9 digit | digit]

reg-name: [any [unreserved | pct-encoded | sub-delims]]

path-abempty: [any [#"/" segment (append path seg)]]

path-absolute: [#"/" (append path 'root) [segment-nz (append path seg) any [#"/" segment (append path seg)] | (append path "")]]

path-noscheme: [segment-nz-nc (append path seg) any [#"/" segment (append path seg)]]

path-rootless: [segment-nz (append path seg) any [#"/" segment (append path seg)]]

segment: [copy seg any pchar (seg: any [seg ""])]

segment-nz: [copy seg some pchar]

segment-nz-nc: [copy seg some [relaxed | pct-encoded | sub-delims | #"@"]]

pchar: [relaxed | pct-encoded | sub-delims | #":" | #"@"]

query-rule: [copy query any [pchar | #"/" | #"?"]]

fragment-rule: [copy fragment any [pchar | #"/" | #"?"]]

pct-encoded: [#"%" 2 hexdigit]
digit0-5: charset "012345"
digit0-4: charset "01234"
digit1-9: charset "123456789"
unreserved: union alpha-char union digit charset "-._~"
gen-delims: charset ":/?#[]@"
sub-delims: charset "!$&'()*+,;="
reserved: union gen-delims sub-delims
relaxed: exclude complement reserved charset "%"
scheme: userinfo: host: port: seg: query: fragment: none
path: []

vars: [scheme userinfo host port path query fragment]

query-chars: complement charset "&="
percent-decode: func [
	string [any-string!]
][
	decode-text/to string 'url string
]

percent-encode: func [
	string [any-string!]
][
	encode-text/to string 'url string
]

parse-uri: func [
	"Parse a URI into its components"
	uri [any-string!]
	/relative "Allow relative URIs"
	/local
	obj
][
	set vars none
	path: make block! 8
	if parse/all uri either relative [uri-reference] [uri-rule] [
		set obj: context [
			scheme: userinfo: host: port: path: query: fragment: none
		] reduce vars
		obj
	]
]

decode-uri-fields: func [
	"Decode the fields of a URI object (see docs)"
	obj [object!]
	/local
	name val fragments
][
	if obj/userinfo [
		parse/all obj/userinfo [(obj/userinfo: make block! 3)
			any [
				copy name to #":" skip (append obj/userinfo percent-decode any [name ""])
			]
			copy name to end (append obj/userinfo percent-decode any [name ""])
		]
	]
	if obj/host [percent-decode obj/host]
	foreach segment obj/path [if string? segment [percent-decode segment]]
	if obj/query [
		parse/all obj/query [(obj/query: make block! 16)
			some [
				copy name some query-chars [
					#"=" copy val some query-chars
					|
					#"=" (val: copy "")
					| (val: copy "")
				] (append/only obj/query reduce [percent-decode name percent-decode val]) [#"&" | end]
				|
				some [#"&" | #"="]
			]
		]
	]
	if obj/fragment [
		either parse/all obj/fragment [(fragments: make block! 5)
			copy name to #"?" skip (append fragments percent-decode name)
			some [
				copy name some query-chars [
					#"=" copy val some query-chars
					|
					#"=" (val: copy "")
					| (val: copy "")
				] (append/only fragments reduce [percent-decode name percent-decode val]) [#"&" | end]
				|
				some [#"&" | #"="]
			]
		][
			obj/fragment: fragments
		][
			percent-decode obj/fragment
		]
	]
	obj
]

encode-uri-fields: func [
	"Encode the fields of a URI object (see docs)"
	obj [object! block!]
	/local
	result
][
	if block? obj [
		obj: make context [
			scheme: userinfo: host: port: path: query: fragment: none
		] obj
	]
	if all [block? obj/userinfo not empty? obj/userinfo] [
		result: percent-encode copy obj/userinfo/1
		foreach value next obj/userinfo [
			insert insert tail result #":" percent-encode value
		]
		obj/userinfo: result
	]
	if obj/host [
		unless parse/all obj/host ip-literal [
			percent-encode obj/host
		]
	]
	foreach segment obj/path [
		if string? segment [percent-encode segment]
	]
	if all [block? obj/query not empty? obj/query] [
		result: percent-encode copy obj/query/1/1
		insert insert tail result #"=" percent-encode obj/query/1/2
		foreach pair next obj/query [
			repend result [
				#"&" percent-encode pair/1 #"=" percent-encode pair/2
			]
		]
		obj/query: result
	]
	case [
		all [block? obj/fragment 1 < length? obj/fragment] [
			result: percent-encode copy obj/fragment/1
			repend result [
				#"?" percent-encode obj/fragment/2/1 #"=" percent-encode obj/fragment/2/2
			]
			foreach pair next next obj/fragment [
				repend result [
					#"&" percent-encode pair/1 #"=" percent-encode pair/2
				]
			]
			obj/fragment: result
		]
		string? obj/fragment [percent-encode obj/fragment]
	]
	obj
]

form-uri: func [
	"Form an URI string from its components"
	obj [object! block!] {URI components (scheme, userinfo, host, port, path, query, fragment)}
	/local
	result path
][
	if block? obj [
		obj: make context [
			scheme: userinfo: host: port: path: query: fragment: none
		] obj
	]
	result: make string! 256
	if obj/scheme [
		insert insert result obj/scheme #":"
	]
	if any [obj/userinfo obj/host obj/port] [
		append result "//"
		if obj/userinfo [
			insert insert tail result obj/userinfo #"@"
		]
		if obj/host [
			append result obj/host
		]
		if obj/port [
			insert insert tail result #":" obj/port
		]
	]
	if not empty? obj/path [
		path: obj/path
		if not any [
			obj/userinfo obj/host obj/port
		][
			if string? path/1 [append result path/1]
			path: next path
		]
		foreach segment path [
			if string? segment [insert insert tail result #"/" segment]
		]
	]
	if obj/query [
		insert insert tail result #"?" obj/query
	]
	if obj/fragment [
		insert insert tail result #"#" obj/fragment
	]
	result
]
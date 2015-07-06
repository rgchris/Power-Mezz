Rebol [
	Title: {Functions to send and receive encrypted message packets}
	File: %messages.r
	Type: 'Module
	Purpose: {
		Defines functions to send and receive encrypted message packets, as
		well as establishing secure communication between peers (eg. via TCP).
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
	Version: 1.0.4
	Imports: [
		%mezz/sequences.r
		%mezz/test-trace.r
		%mezz/logging.r
	]
	Exports: [
		make-messages-session
		send-message
		receive-message
		greet-messages-peer
		handle-handshake-message
	]
]

random-seed: either all [system/version/4 <> 3 exists? %/dev/urandom] [
	p: open/direct/binary/read %/dev/urandom
	also
	copy/part p 20 (close p unset 'p)
][
	random/seed now
	checksum/secure form random/secure 2 ** 48
]

master-sequence: make-sequence random-seed
magic-number: #{FD6BF3E23DB9A5317FAF36B2A5779B63D2225D22}
max-header-length: 64
system/error: make system/error [
	Hardball: context [
		code: 1000
		type: "Hardball Error"
		Invalid-Header: ["Invalid message header:" mold :arg1]
		Header-Too-Long: ["Message header too long (" :arg1 "bytes)"]
		Block-Too-Short: ["Message too short (" :arg1 "bytes)"]
		Block-Too-Long: ["Message too long (" :arg1 "bytes)"]
		Can't-Decrypt: "Unable to decrypt message"
		Not-Welcome: ["Peer" mold copy/part :arg1 5 "is not welcome"]
		Rude: "Peer is being rude (expected Hello message)"
		Key-Length: ["Invalid random number length" :arg1 "(expected 20)"]
		Key-Expected: {Unexpected message (expected 160 bit random number)}
		Liar: ["Peer attempted to deceive us (received" mold copy/part :arg1 5 ", expected" mold copy/part :arg2 5 ")"]
		Verification-Expected: "Unexpected message (expected verification number)"
		Handshake-Complete: {Handshake phase already complete, please don't call handle-handshake-message}
	]
]

throw-error: func [args [block! word!]][
	throw make error! join [Hardball] args
]

encrypt-message: func [session data /local port hmac-key hmac][
	append-log 'debug ["Encrypting" length? data "bytes message"]
	port: open [
		scheme: 'crypt
		algorithm: 'blowfish
		direction: 'encrypt
		strength: 160
		key: (next-number session/output-sequence)
		padding: true
		init-vector: #{48E1041BB8D358D79B3D6D5B6C21A73C90D7B88E}
	]
	append-log 'debug-secret ["Encrypting message using key:" mold port/key]
	insert port data
	update port
	data: copy port
	close port
	append-log 'debug ["Encrypted message:" length? data "bytes"]
	hmac-key: next-number session/output-sequence
	append-log 'debug-secret ["HMAC key:" mold hmac-key]
	hmac: checksum/secure/key data hmac-key
	append-log 'debug ["HMAC:" mold hmac]
	head insert data hmac
]
header!: context [
	hardball: 'Hardball
	version: 1
	block-length: 0
	payload-length: 0
]

send-hdr: make header! []

header-rule: ['Hardball 1 1 1 integer! integer!]

recv-hdr: make header! []

reset-session: func [session][
	session/header: session/block: session/payload: none
]

decrypt-message: func [session data /local port hmac d-key hmac-key comp-hmac][
	hmac: copy/part data 20
	data: skip data 20
	d-key: next-number session/input-sequence
	hmac-key: next-number session/input-sequence
	append-log 'debug ["Received HMAC:" mold hmac]
	append-log 'debug-secret ["HMAC key:" mold hmac-key]
	comp-hmac: checksum/secure/key data hmac-key
	append-log 'debug ["Computed HMAC:" mold comp-hmac]
	if hmac <> comp-hmac [
		append-log 'error ["Message HMAC mismatch"]
		return none
	]
	append-log 'debug-secret ["Decrypting using key:" mold d-key]
	port: open [
		scheme: 'crypt
		algorithm: 'blowfish
		direction: 'decrypt
		strength: 160
		key: d-key
		padding: true
		init-vector: #{48E1041BB8D358D79B3D6D5B6C21A73C90D7B88E}
	]
	insert port data
	update port
	also
	copy port
	close port
]

encrypt-rsa: func [key value /local key'][
	either object? key [
		rsa-encrypt/private key value
	][
		key': rsa-make-key
		key'/e: 3
		key'/n: key
		rsa-encrypt key' value
	]
]

decrypt-rsa: func [key value /local key'][
	either object? key [
		rsa-encrypt/decrypt/private key value
	][
		key': rsa-make-key
		key'/e: 3
		key'/n: key
		rsa-encrypt/decrypt key' value
	]
]

make-messages-session: func [
	"Create a messages session object"
][
	context [
		output-sequence: make-sequence magic-number
		header: block: payload: none
		max-block-length: 64 * 1024
		max-payload-length: 0
		input-sequence: make-sequence magic-number
		state: 'hello
		peer-public-key: session-key: none
		role: 'server
		verification: none
	]
]

send-message: func [
	"Send a message securely"
	output [port! any-string!] "Message destination"
	session [object!]
	message [block!] "Contents"
][
	append-log 'debug ["Sending message:" mold/all/only message]
	message: encrypt-message session mold/all/only message
	send-hdr/block-length: length? message
	append-log 'debug ["Sending message header:" mold get send-hdr]
	insert insert insert tail output
	mold/only get send-hdr
	#"^@"
	message
]

receive-message: func [
	"Receive a message sent by SEND-MESSAGE" [catch]
	buffer [any-string!] {Input buffer (may contain many messages, is MODIFIED)}
	session [object!]
	/local
	mark
][
	append-log 'debug ["receive-message:" length? buffer "bytes in the buffer"]
	unless session/header [
		append-log 'debug ["Scanning for message header"]
		remove/part buffer any [find buffer 'Hardball tail buffer]
		either mark: find buffer #"^@" [
			session/header: to block! as-string buffer
			append-log 'debug ["Received message header:" mold/all session/header]
			remove/part buffer next mark
			unless parse session/header header-rule [
				mark: session/header
				reset-session session
				throw-error ['Invalid-Header mark]
			]
		][
			append-log 'debug ["Message header not found or not complete"]
			if max-header-length < length? buffer [
				reset-session session
				remove/part buffer 8
				throw-error ['Header-Too-Long length? buffer]
			]
		]
	]
	if all [session/header not session/block] [
		append-log 'debug ["Receiving message block"]
		set recv-hdr session/header
		case [
			recv-hdr/block-length < 3 [
				reset-session session
				throw-error ['Block-Too-Short recv-hdr/block-length]
			]
			recv-hdr/block-length > session/max-block-length [
				reset-session session
				remove/part buffer recv-hdr/block-length
				remove/part buffer recv-hdr/payload-length
				throw-error ['Block-Too-Long recv-hdr/block-length]
			]
			'else [
				append-log 'debug ["Block length:" recv-hdr/block-length "bytes. Received:" length? buffer "bytes."]
				either recv-hdr/block-length <= length? buffer [
					session/block: copy/part buffer recv-hdr/block-length
					if session/block: decrypt-message session session/block [
						session/block: attempt [to block! as-string session/block]
					]
					append-log 'debug ["Received message:" mold/all session/block]
					remove/part buffer recv-hdr/block-length
					unless session/block [
						reset-session session
						throw-error 'Can't-Decrypt
					]
				][
					append-log 'debug ["Message block not complete"]
				]
			]
		]
		if recv-hdr/payload-length <> 0 [
			throw make error! "Expand/compand not supported yet"
		]
	]
	append-log 'debug [length? buffer "bytes still in the buffer"]
	if session/block [
		append-log 'debug ["We have the full message"]
		also
		session/block
		reset-session session
	]
]

greet-messages-peer: func [
	"Send the Hardball greeting to the other peer"
	output [port! any-string!]
	session [object!]
	config [object!]
][
	send-message output session reduce ['Hello config/public-key]
]

handle-handshake-message: func [
	{Handle Hardball messages during the protocol handshake phase} [catch]
	session [object!]
	config [object!]
	message [block!]
	/local
	key
][
	append-test-trace session/state
	switch session/state [
		hello [
			either parse message ['Hello set key binary!] [
				either find config/allowed-peers key [
					append-test-trace 'allowed
					append-log 'debug ["Accepted peer:" mold key]
					session/peer-public-key: key
					session/session-key: next-number master-sequence
					append-log 'debug-secret ["Generated random number:" mold session/session-key]
					message: encrypt-rsa key session/session-key
					append-log 'debug ["Sending encrypted random number:" mold message]
					session/state: 'key
					reduce ['Key message]
				][
					append-log 'error ["Peer is not welcome:" mold key]
					throw-error ['Not-Welcome key]
				]
			][
				append-log 'error ["Peer is being rude:^/" copy/part mold/only/all message 30]
				throw-error 'Rude
			]
		]
		key [
			either parse message ['Key set key binary!] [
				append-test-trace ['got-key length? key]
				append-log 'debug ["Got peer's random number:" length? key "bytes"]
				key: decrypt-rsa config/private-key key
				append-log 'debug-secret ["Peer's random number:" mold key]
				append-log 'debug-secret ["My random number:" mold session/session-key]
				append-test-trace ['decrypted length? key]
				either 20 = length? key [
					append-test-trace 'key-ok
					key: key xor session/session-key
					append-log 'debug-secret ["Session secret:" mold key]
					key: make-sequence key
					append-test-trace ['role session/role]
					either session/role = 'server [
						session/input-sequence: make-sequence next-number key
						session/output-sequence: make-sequence next-number key
					][
						session/output-sequence: make-sequence next-number key
						session/input-sequence: make-sequence next-number key
					]
					append-log 'debug-secret ["Input sequence:^/" mold/all session/input-sequence]
					append-log 'debug-secret ["Output sequence:^/" mold/all session/output-sequence]
					session/verification: next-number key
					append-log 'debug ["Verification number:" mold session/verification]
					key: encrypt-rsa config/private-key session/verification
					session/state: 'verify
					append-test-trace ['encrypted-ver-number length? key]
					reduce ['Verify key]
				][
					append-log 'error ["Peer's random number is not 20 bytes long"]
					throw-error ['Key-Length length? key]
				]
			][
				append-log 'error [
					{Unexpected message (expecting peer's random number):
} copy/part mold/only/all message 30
				]
				throw-error 'Key-Expected
			]
		]
		verify [
			either parse message ['Verify set key binary!] [
				append-test-trace ['got-ver-number length? key]
				append-log 'debug ["Got verification number:" length? key "bytes"]
				key: decrypt-rsa session/peer-public-key key
				append-test-trace ['decrypted-ver-number length? key]
				append-log 'debug [
					"My verification number:" mold session/verification
					"Peer's verification number:" mold key
				]
				either key = session/verification [
					append-test-trace 'all-good
					append-log 'debug ["All is good! Session established"]
					session/state: 'data
					true
				][
					append-log 'error ["Verification number does not match"]
					throw-error ['Liar key session/verification]
				]
			][
				append-log 'error [
					{Unexpected message (expecting verification number):
} copy/part mold/only/all message 30
				]
				throw-error 'Verification-Expected
			]
		]
		data [
			throw-error 'Handshake-Complete
		]
	]
]
Rebol [
	Title: "IMAP access functions"
	File: %imap.r
	Type: 'Module
	Purpose: {
		This module exports a number of functions to access mail on a IMAP server.
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
	Version: 1.7.0
	Imports: [
		%mezz/mail.r "We need decode-email-field"
		%mezz/text-encoding.r "utf-7-imap encoding"
	]
	Exports: [
		open-mail-db
		valid-mail-db?
		check-mail-db
		refresh-mail-db
		close-mail-db
		list-mail-folders
		get-message-counts
		list-mail-messages
		move-mail-message
		copy-mail-message
		compact-mail-folder
		create-mail-folder
		empty-mail-folder
		delete-mail-folder
		move-mail-folder
		rename-mail-folder
		create-mail-message
		get-mail-message
		change-message-flags
		search-mail-messages
	]
]

load-module %schemes/imapcommands.r
append-email: func [output address][
	insert insert tail output
	if address/1 [decode-email-field address/1]
	if all [address/3 address/4 not empty? address/3 not empty? address/4] [
		repend to email! address/3 ["@" address/4]
	]
]

ok-response: [word! 'OK opt block! string!]

select-mailbox: func [db mailbox][
	if db/selected-mailbox <> mailbox [
		insert db/imap-port compose [SELECT (mailbox)]
		db/select-response: copy db/imap-port
		db/selected-mailbox: mailbox
	]
]

from-imap-flags: func [flags][
	flags: intersect to block! flags [/Seen /Answered /Deleted /Flagged /Draft]
	forall flags [
		flags/1: select [
			/Seen read
			/Answered replied
			/Deleted deleted
			/Flagged flagged
			/Draft draft
		] flags/1
	]
	flags
]

to-imap-flags: func [flags /local res][
	res: make paren! length? flags
	foreach flag flags [
		switch flag [
			read [append res /Seen]
			replied [append res /Answered]
			deleted [append res /Deleted]
			flagged [append res /Flagged]
			draft [append res /Draft]
			forwarded [append res #$Forwarded]
		]
	]
	res
]

parse-bodystructure: func [structure /local result value mk1 mk2][
	result: copy [#[none]]
	parse structure [
		copy value [string! string!] (
			if any [empty? value/1 empty? value/2] [
				value: ["text" "plain"]
			]
			value/1: to word! value/1
			value/2: to word! value/2
			append/only result to path! value
		) [
			set value paren! (
				value: to block! value
				forskip value 2 [value/1: to word! value/1]
				append/only result value
			)
			|
			skip (append result none)
		]
		mk1: [string! | none!] [string! | none!]
		string!
		integer!
		mk2: (insert/part tail result mk1 mk2)
		|
		some [
			set value paren! (append/only result parse-bodystructure value)
		]
		set value string! (result/1: to word! value)
	]
	result
]
has-attachments?: func [structure][
	switch/default structure/1 [#[none] [false]
		alternative [
			foreach part next structure [
				if has-attachments? part [return true]
			]
			false
		]
		related [false]
	][
		true
	]
]

append-tree: func [tree path folderid flags only /local pos][
	either pos: find/skip tree path/1 4 [
		either tail? next path [
			either only [
				remove find pos/3 'Hidden
			][
				pos/2: folderid
				pos/3: flags
			]
		][
			append-tree pos/4 next path folderid flags only
		]
	][
		unless only [
			either tail? next path [
				repend tree [path/1 folderid flags copy []]
			][
				repend tree [path/1 none copy [children] pos: copy []]
				append-tree pos next path folderid flags only
			]
		]
	]
]

mk-folder-flags: func [flags /to result][
	unless result [result: make block! 4]
	unless find flags /NoInferiors [append result 'children]
	unless find flags /NoSelect [append result 'messages]
	if find flags /Marked [append result 'new]
	result
]

remove-hidden: func [folders][
	remove-each [name id flags sub-folders] folders [
		remove-hidden sub-folders
		all [find flags 'hidden empty? sub-folders id <> "INBOX"]
	]
]

get-delimiter: func [port parent /local delimiter][
	insert port reduce [
		'list parent ""
	]
	unless all [
		parse copy port [
			into ['* 'LIST skip set delimiter [word! | string! | none!] skip]
			into ok-response
		]
		delimiter
	][
		make error! "Unknown hierarchy delimiter for folder"
	]
	delimiter
]

do-list: func [port cmd only parent result /unhide /local flags delimiter folder][
	if parent [
		delimiter: get-delimiter port parent
		parent: join parent delimiter
	]
	insert port reduce [
		cmd any [parent ""] either only ["%"] ["*"]
	]
	unless parse copy port [
		any [
			into [
				'* ['LIST | 'LSUB] set flags [paren! | none!] set delimiter [word! | string! | none!] [
					set folder [word! | integer!] (folder: form folder)
					|
					set folder string!
					|
					set folder binary! (folder: as-string folder)
				]
			] (
				if all [delimiter delimiter/1 = last folder] [remove back tail folder]
				append-tree
				result
				either delimiter [
					parse/all
					decode-text either parent [find/match folder parent] [folder] 'utf-7-imap
					form delimiter
				][
					reduce [decode-text folder 'utf-7-imap]
				]
				folder
				append mk-folder-flags flags 'Hidden
				unhide
			)
		]
		into ok-response
	][
		make error! "Can't parse folder list"
	]
]

alter-subscription: func [
	port
	folders
	action
][
	foreach [name id flags sub-folders] folders [
		insert port compose [(action) (id)]
		copy port
		alter-subscription port sub-folders action
	]
]

make-id-map: func [
	map
	from
	to
	sub-folders
][
	insert insert map from to
	foreach [name id flags sub-folders] sub-folders [
		make-id-map map id join to skip id length? from sub-folders
	]
	map
]

node-types: context [
	and: or: subject: from: to: cc: bcc: body: unread: unforwarded: none
]
node-types/and: func [output args][
	foreach node args [
		compile-node output node
	]
]
node-types/or: func [output args /local paren][
	paren: make paren! 8
	append/only output paren
	append paren 'OR
	foreach node args [
		compile-node paren node
	]
]
node-types/subject: func [output args][
	repend output ['SUBJECT args/1]
]
node-types/from: func [output args][
	repend output ['FROM args/1]
]
node-types/to: func [output args][
	repend output ['TO args/1]
]
node-types/cc: func [output args][
	repend output ['CC args/1]
]
node-types/bcc: func [output args][
	repend output ['BCC args/1]
]
node-types/body: func [output args][
	repend output ['BODY args/1]
]
node-types/unread: func [output args][
	append output 'UNSEEN
]
node-types/unforwarded: func [output args][
	append output [UNKEYWORD #$Forwarded]
]

compile-node: func [output node /local type][
	unless type: in node-types node/1 [
		make error! "Invalid search criteria"
	]
	do type output next node
]

compile-search-criteria: func [criteria /local res][
	res: copy [UID SEARCH UNDELETED]
	compile-node res criteria
	res
]

mail-db-store: []

select-mail-db: func [db /bump /local pos][
	db: all [
		pos: find mail-db-store reduce [db/host db/port db/user]
		3 + index? pos
	]
	if all [db bump] [
		pos/4/refcount: pos/4/refcount + 1
	]
	db
]

append-mail-db: func [db][
	append mail-db-store reduce [
		db/imap-port/host db/imap-port/port-id db/imap-port/user
		db
	]
	length? mail-db-store
]

open-port: func [db][
	open compose [
		scheme: (either db/secure [['imapscommands]] [['imapcommands]])
		host: db/host
		user: db/user
		pass: db/pass
		port-id: db/port
	]
]

pick-mail-db: func [db][
	pick mail-db-store db
]

open-mail-db: func [
	"Open/initialize a mail database"
	db "Object with [host: user: pass: secure: port:]"
][
	unless db/port [
		db/port: either db/secure [993] [143]
	]
	any [
		select-mail-db/bump db
		append-mail-db context [
			imap-port: open-port db
			selected-mailbox: none
			select-response: none
			refcount: 1
		]
	]
]
valid-mail-db?: func [
	"Validate IMAP settings"
	db "Object with [host: user: pass: secure: port:]"
][
	not error? try [
		check-mail-db db
	]
]

check-mail-db: func [
	"Attempt connection, throw error or return true"
	db "Object with [host: user: pass: secure: port:]"
][
	unless db/port [
		db/port: either db/secure [993] [143]
	]
	unless select-mail-db db [
		db: open-port db
		insert db [LIST "" "*"]
		copy db
		close db
	]
	true
]

refresh-mail-db: func [
	{Make sure the mail database is still available, otherwise reopen it}
	db "Result of open-mail-db"
][
	unless db: pick-mail-db db [return false]
	if error? try [
		insert db/imap-port [NOOP]
		copy db/imap-port
	][
		attempt [close db/imap-port]
		db/selected-mailbox: db/select-response: none
		db/imap-port: open compose [
			scheme: (to lit-word! db/imap-port/scheme)
			host: db/imap-port/host
			user: db/imap-port/user
			pass: db/imap-port/pass
			port-id: db/imap-port/port-id
		]
	]
	true
]

close-mail-db: func [
	"Close a mail database"
	db "Result of open-mail-db"
][
	db: pick-mail-db db
	if 0 = db/refcount: max 0 db/refcount - 1 [
		attempt [close db/imap-port]
	]
	none
]

list-mail-folders: func [
	"List the existing mail folders"
	db "Result of open-mail-db"
	/all "Return all folders (including hidden folders)"
	/only parent-id {Return only the childs of the specified folder (none for root)}
	/local
	result
][
	db: pick-mail-db db
	result: make block! 16
	do-list db/imap-port 'list only parent-id result
	do-list/unhide db/imap-port 'lsub only parent-id result
	unless all [
		remove-hidden result
	]
	result
]

get-message-counts: func [
	"Return the number of messages in a folder"
	db "Result of open-mail-db"
	folder-id
	/local
	value total unseen
][
	db: pick-mail-db db
	select-mailbox db folder-id
	parse db/select-response [
		any [
			into [
				'* set value integer! 'EXISTS (total: value)
			]
			|
			skip
		]
	]
	insert db/imap-port [SEARCH UNDELETED UNSEEN]
	parse copy db/imap-port [
		any [
			into ['* 'SEARCH unseen: some integer!]
			|
			skip
		]
	]
	unless block? unseen [make error! "Unable to get number of unread messages"]
	reduce [total length? unseen]
]

list-mail-messages: func [
	"List the messages contained in a folder"
	db "Result of open-mail-db"
	folder-id
	columns [block!] "List of columns to return (must be non-empty)"
	/only only-uids "Only list specified messages"
	/local
	result message address message-count uidvalidity non-deleted list
	start-index end-index list-part fetch-columns list-end
][
	db: pick-mail-db db
	select-mailbox db folder-id
	message-count: 0
	parse db/select-response [
		any [
			into ['* integer! 'EXISTS message-count: (message-count: message-count/-2) to end]
			|
			into [word! 'OK into ['UIDVALIDITY set uidvalidity integer!] string!]
			|
			skip
		]
	]
	result: make block! 256
	if message-count < 1 [return result]
	either block? only-uids [
		if empty? only-uids [return result]
		non-deleted: copy only-uids
		sort non-deleted
	][
		insert db/imap-port [SEARCH UNDELETED]
		parse copy db/imap-port [
			any [
				into ['* 'SEARCH non-deleted: some integer!]
				|
				skip
			]
		]
		if any [not block? non-deleted empty? non-deleted] [return result]
	]
	list: make issue! 256
	parse non-deleted [
		some [
			set start-index integer! (end-index: start-index) [
				some [(end-index: end-index + 1) 1 1 end-index] (repend list [start-index #":" end-index - 1 #","])
				| (repend list [start-index #","])
			]
		]
	]
	remove back tail list
	message: context [
		id: 'UID
		from: 'ENVELOPE
		to: 'ENVELOPE
		cc: 'ENVELOPE
		subject: 'ENVELOPE
		size: 'RFC822.SIZE
		flags: 'FLAGS
		date: 'ENVELOPE
		received: 'INTERNALDATE
		sender: 'ENVELOPE
		reply-to: 'ENVELOPE
		bcc: 'ENVELOPE
		in-reply-to: 'ENVELOPE
		message-id: 'ENVELOPE
		has-attachments: 'BODY
		structure: 'BODY
	]
	columns: use columns reduce [columns]
	set columns none
	bind columns message
	fetch-columns: to paren! replace unique reduce columns none []
	while [not empty? list] [
		list-end: at list 256
		either empty? list-end [
			list-part: list
			list: list-end
		][
			list-end: any [find list-end #"," tail list-end]
			list-part: copy/part list list-end
			list: next list-end
		]
		insert db/imap-port
		head insert compose/only [FETCH (list-part) (fetch-columns)] either block? only-uids ['UID] [[]]
		parse copy db/imap-port bind [
			any [(
					set message none
					foreach w [from to cc sender reply-to bcc] [
						set w make block! 4
					]
				)
				into [
					'* integer! 'FETCH into [
						any [
							'ENVELOPE into [[set date [string! | date! | binary! | none!]] [
									set subject [string! | binary!] (subject: decode-email-field as-string subject)
									|
									none! (subject: copy "")
								] [into [any [set address paren! (append-email from address)]] | none!] [into [any [set address paren! (append-email sender address)]] | none!] [into [any [set address paren! (append-email reply-to address)]] | none!] [into [any [set address paren! (append-email to address)]] | none!] [into [any [set address paren! (append-email cc address)]] | none!] [into [any [set address paren! (append-email bcc address)]] | none!] [set in-reply-to string! (in-reply-to: decode-email-field in-reply-to) | none!] [set message-id string! (message-id: decode-email-field message-id) | none!]
								to end
							]
							|
							'RFC822.SIZE set size integer!
							|
							'UID set id integer! (id: reduce [folder-id uidvalidity id])
							|
							'FLAGS set flags paren! (flags: from-imap-flags flags)
							|
							'INTERNALDATE set received date!
							|
							'BODY set structure paren! (
								has-attachments: has-attachments? structure: parse-bodystructure structure
							)
						]
					]
				] (repend/only result columns)
				|
				into [
					'* 'OK into ['PARSE] string!
				]
			]
			into ok-response
		] message
	]
	result
]

move-mail-message: func [
	{Move a message from its current folder to another one}
	db "Result of open-mail-db"
	message-id
	dest-folder-id
	/local
	new-id
][
	new-id: copy-mail-message db message-id dest-folder-id
	change-message-flags db message-id [+ Deleted]
	new-id
]

copy-mail-message: func [
	"Copy a message to another folder"
	db "Result of open-mail-db"
	message-id
	dest-folder-id
	/local
	uidvalidity uid
	dest-uidvalidity old-uid new-uid
][
	db: pick-mail-db db
	if not find db/imap-port/locals/capabilities 'UIDPLUS [
		select-mailbox db dest-folder-id
		parse db/select-response [
			any [
				into [
					'* 'OK into ['UIDVALIDITY set dest-uidvalidity integer!] string!
				]
				|
				into [
					'* 'OK into ['UIDNEXT set new-uid integer!] string!
				]
				|
				skip
			]
		]
	]
	select-mailbox db message-id/1
	old-uid: message-id/3
	insert db/imap-port compose [UID COPY (old-uid) (dest-folder-id)]
	either all [dest-uidvalidity new-uid] [
		copy db/imap-port
	][
		parse copy db/imap-port [
			any [
				into [
					word! 'OK into ['COPYUID set dest-uidvalidity integer! 1 1 old-uid set new-uid integer!] string!
				]
				|
				skip
			]
		]
	]
	reduce [dest-folder-id dest-uidvalidity new-uid]
]

compact-mail-folder: func [
	{Physically remove all the messages marked as deleted from a folder}
	db "Result of open-mail-db"
	folder-id "Folder to compact"
][
	db: pick-mail-db db
	select-mailbox db folder-id
	insert db/imap-port [EXPUNGE]
	copy db/imap-port
	true
]

create-mail-folder: func [
	"Create a new mail folder"
	db "Result of open-mail-db"
	parent-id "ID of parent folder, none for root folder"
	folder-name [string!]
	/with flags [block! none!] {Set desired flags for the new folder (only CHILDREN really matters)}
	/local
	delimiter name children serv-flags
][
	db: pick-mail-db db
	delimiter: if any [children: all [flags find flags 'children] parent-id] [get-delimiter db/imap-port any [parent-id ""]]
	folder-name: encode-text folder-name 'utf-7-imap
	name: either parent-id [
		rejoin [parent-id delimiter folder-name]
	][
		folder-name
	]
	insert db/imap-port compose [CREATE (either children [append copy name delimiter] [name])]
	copy db/imap-port
	if flags [
		insert db/imap-port compose [LIST "" (name)]
		if parse copy db/imap-port [
			into ['* 'LIST set serv-flags [paren! | none!] skip [word! | string! | integer!]]
			into ok-response
		][
			clear flags
			if serv-flags [mk-folder-flags/to serv-flags flags]
		]
	]
	attempt [
		insert db/imap-port compose [SUBSCRIBE (name)]
		copy db/imap-port
	]
	name
]

empty-mail-folder: func [
	"Destroy the contents of a folder"
	db "Result of open-mail-db"
	folder-id
][
	db: pick-mail-db db
	insert db/imap-port compose [DELETE (folder-id)]
	copy db/imap-port
	insert db/imap-port compose [CREATE (folder-id)]
	copy db/imap-port
	true
]

delete-mail-folder: func [
	"Delete a mail folder"
	db "Result of open-mail-db"
	folder-id
][
	db: pick-mail-db db
	insert db/imap-port compose [UNSUBSCRIBE (folder-id)]
	copy db/imap-port
	insert db/imap-port compose [DELETE (folder-id)]
	copy db/imap-port
	true
]

move-mail-folder: func [
	"Move a mail folder"
	db "Result of open-mail-db"
	folder-id
	dest-folder-id
	/local
	delimiter name subfolders id-map
][
	db: pick-mail-db db
	delimiter: get-delimiter db/imap-port folder-id
	name: last parse/all folder-id delimiter
	if dest-folder-id [
		delimiter: get-delimiter db/imap-port dest-folder-id
		name: rejoin [dest-folder-id delimiter name]
	]
	subfolders: copy []
	do-list db/imap-port 'lsub false folder-id subfolders
	alter-subscription db/imap-port subfolders 'UNSUBSCRIBE
	insert db/imap-port compose [UNSUBSCRIBE (folder-id)]
	copy db/imap-port
	insert db/imap-port compose [RENAME (folder-id) (name)]
	copy db/imap-port
	id-map: copy []
	make-id-map id-map folder-id name subfolders
	foreach [from to] id-map [
		insert db/imap-port compose [SUBSCRIBE (to)]
		copy db/imap-port
	]
	id-map
]

rename-mail-folder: func [
	"Rename a mail folder"
	db "Result of open-mail-db"
	folder-id
	new-folder-name [string!]
	/local
	delimiter parent subfolders id-map
][
	db: pick-mail-db db
	delimiter: get-delimiter db/imap-port folder-id
	parent: copy/part folder-id any [find/last/tail folder-id delimiter 0]
	encode-text/to new-folder-name 'utf-7-imap parent
	subfolders: copy []
	do-list db/imap-port 'lsub false folder-id subfolders
	alter-subscription db/imap-port subfolders 'UNSUBSCRIBE
	insert db/imap-port compose [UNSUBSCRIBE (folder-id)]
	copy db/imap-port
	insert db/imap-port compose [RENAME (folder-id) (parent)]
	copy db/imap-port
	id-map: copy []
	make-id-map id-map folder-id parent subfolders
	foreach [from to] id-map [
		insert db/imap-port compose [SUBSCRIBE (to)]
		copy db/imap-port
	]
	id-map
]

create-mail-message: func [
	"Create a new mail message in a folder"
	db "Result of open-mail-db"
	folder-id
	message [string!] "Message text"
	/local
	uidvalidity uid
	dest-uidvalidity old-uid new-uid
][
	db: pick-mail-db db
	if not find db/imap-port/locals/capabilities 'UIDPLUS [
		select-mailbox db folder-id
		parse db/select-response [
			any [
				into [
					'* 'OK into ['UIDVALIDITY set uidvalidity integer!] string!
				]
				|
				into [
					'* 'OK into ['UIDNEXT set uid integer!] string!
				]
				|
				skip
			]
		]
	]
	insert db/imap-port compose/only [APPEND (folder-id) (to-imap-flags message/flags) (message)]
	either all [uidvalidity uid] [
		copy db/imap-port
	][
		parse copy db/imap-port [
			some [
				into [word! 'OK into ['APPENDUID set uidvalidity integer! set uid integer!] string!]
				|
				skip
			]
		]
	]
	reduce [folder-id uidvalidity uid]
]

get-mail-message: func [
	"Get the contents of a mail message"
	db "Result of open-mail-db"
	message-id
	/part "Return a specific part of the message"
	part-name [word! path! block!] "Message part to return"
	/local
	message flags structure i type result
][
	db: pick-mail-db db
	select-mailbox db message-id/1
	either part [
		switch/default part-name [
			source [part-name: to path! [BODY.PEEK ""] result: 'message]
			header [part-name: 'RFC822.HEADER result: 'message]
			structure [part-name: 'BODY result: 'structure]
		][
			if path? part-name [
				part-name/1: 'BODY.PEEK
				part-name: form part-name
				replace/all find/tail part-name "/" "/" "."
				part-name: load part-name
				result: 'message
			]
		]
	][
		part-name: to path! [BODY.PEEK ""]
		result: 'message
	]
	insert db/imap-port compose [UID FETCH (message-id/3) (part-name)]
	parse copy db/imap-port [
		some [
			into [
				'* integer! 'FETCH into [
					any [['RFC822 | 'RFC822.HEADER | path!] set message [string! | binary!]
						|
						'FLAGS set flags paren! (flags: from-imap-flags flags)
						|
						'BODY set structure paren! (structure: parse-bodystructure structure)
						|
						'UID integer!
					]
				]
			]
			|
			into [
				'* 'OK into ['PARSE] string!
			]
		]
		into ok-response
	]
	get result
]

change-message-flags: func [
	"Change the flags for a message"
	db "Result of open-mail-db"
	message-id
	flags [block!]
	/local
	command
][
	db: pick-mail-db db
	select-mailbox db message-id/1
	command: switch/default flags/1 [
		+ ['+FLAGS.SILENT]
		- ['-FLAGS.SILENT]
	][
		'FLAGS.SILENT
	]
	insert db/imap-port compose/only [UID STORE (message-id/3) (command) (to-imap-flags flags)]
	copy db/imap-port
	true
]

search-mail-messages: func [
	"List the messages matching the search criteria"
	db "Result of open-mail-db"
	folder-id
	criteria [block!] "Search criteria (see documentation)"
	/local
	result message-count uidvalidity uids
][
	db: pick-mail-db db
	select-mailbox db folder-id
	message-count: 0
	parse db/select-response [
		any [
			into ['* integer! 'EXISTS message-count: (message-count: message-count/-2) to end]
			|
			into [word! 'OK into ['UIDVALIDITY set uidvalidity integer!] string!]
			|
			skip
		]
	]
	result: reduce [uidvalidity]
	if message-count < 1 [return result]
	insert db/imap-port compile-search-criteria criteria
	parse copy db/imap-port [
		any [
			into ['* 'SEARCH uids: some integer!]
			|
			skip
		]
	]
	if not block? uids [return result]
	append result uids
]
Rebol [
	Title: "Test trace"
	File: %test-trace.r
	Type: 'Module
	Purpose: {
		Allows creating test traces to simplify automated testing of systems
		(like network servers / protocols etc.) which are not "functional" in
		nature and thus not easy to "unit test".
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
	Version: 1.0.1
	Exports: [
		start-test
		append-test-trace
		end-test
	]
]

append-test-trace: func [
	"Add a value to the current test trace"
	value
] []

start-test: func [
	"Start a test session (create test trace)"
][
	test-trace: clear []
	append-test-trace: :actual-append-test-trace
]

end-test: func [
	"End a test session and return test trace"
][
	append-test-trace: :fake-append-test-trace
	copy test-trace
]

fake-append-test-trace: :append-test-trace
actual-append-test-trace: func [
	"Add a value to the current test trace"
	value
][
	repend test-trace :value
]
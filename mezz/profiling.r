Rebol [
	Title: "Rebol functions profiler"
	File: %profiling.r
	Type: 'Module
	Purpose: {
		Defines functions that allow profiling (measuring relative performance) of functions
		in a Rebol program.
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
	Exports: [
		in-func
		out-func
		reset-profiler
		show-profiler-results
	]
]

profiler-table: context []

profiler-call-stack: []

in-func: func [name /local w stats][
	if not word? name [exit]
	if not empty? profiler-call-stack [
		if w: in profiler-table last profiler-call-stack [
			stats: get w
			if stats/start [
				stats/time: stats/time + difference now/precise stats/start
				stats/start: none
			]
		]
	]
	append profiler-call-stack name
	either w: in profiler-table name [
		stats: get w
		stats/start: now/precise
	][
		profiler-table: make profiler-table reduce [
			to set-word! name context [
				start: now/precise
				time: 0:00 count: 0
			]
		]
	]
]

out-func: func [name /local t w stats][
	t: now/precise
	if not word? name [exit]
	stats: get w: in profiler-table name
	if stats/start [
		stats/time: stats/time + difference t stats/start
		stats/count: stats/count + 1
		stats/start: none
	]
	remove back tail profiler-call-stack
	if not empty? profiler-call-stack [
		if w: in profiler-table last profiler-call-stack [
			stats: get w
			stats/start: now/precise
		]
	]
]

-left: func [str n] [head insert/dup tail str " " n - length? str]

-right: func [str n] [head insert/dup str " " n - length? str]

reset-profiler: does [
	foreach stats next second profiler-table [
		stats/time: 0:00
		stats/count: 0
	]
]

show-profiler-results: has [res stats str total-time total-calls] [
	res: clear []
	str: copy {
Top ten functions by total time:
+------------------------------+------------------+---------+
| Name                         |             Time |   Calls |
+------------------------------+------------------+---------+
}
	foreach w next first profiler-table [
		stats: get in profiler-table w
		append/only res reduce [stats/time stats/count w]
	]
	sort/reverse res
	foreach row copy/part res 10 [
		append str reduce [
			"| " -left form row/3 28 " | " -right form row/1 16 " | " -right form row/2 7 " |^/"
		]
	]
	clear res
	foreach w next first profiler-table [
		stats: get in profiler-table w
		if stats/count > 0 [append/only res reduce [stats/time / stats/count w]]
	]
	sort/reverse res
	append str {+------------------------------+------------------+---------+

Top ten functions by average time:
+------------------------------+------------------+
| Name                         |             Time |
+------------------------------+------------------+
}
	foreach row copy/part res 10 [
		append str reduce [
			"| " -left form row/2 28 " | " -right form row/1 16 " |^/"
		]
	]
	append str {+------------------------------+------------------+

Total execution time: }
	total-time: 0:00
	total-calls: 0
	foreach stats next second profiler-table [
		if stats/time [total-time: total-time + stats/time]
		if stats/count [total-calls: total-calls + stats/count]
	]
	repend str [total-time " for " total-calls " function calls."]
]
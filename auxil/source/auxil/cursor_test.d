module auxil.cursor_test;

import std;

import unit_threaded;

import auxil.cursor;

//     128 118  97  85  72  48  33  17    0
//           0  10  31  43  56  80  95  111 128
auto seq = [10, 21, 12, 13, 24, 15, 16, 17];

struct LogRecord
{
	float pos;
	float value;
}

auto test(bool forward, R)(ref Cursor a, R r, ref LogRecord[] log)
{
	static if (forward)
		auto data = r;
	else
		auto data = r.retro;
	foreach(e; data)
	{
		log ~= LogRecord(a.calcPosition!forward(e), e);
		a.next(e);
		if (a.complete)
			break;
	}
}

@Name("Basics")
unittest
{
	LogRecord[] posLog;

	// scroll from the start to the end in forward direction
	auto a = Cursor();
	test!true(a, seq, posLog);
	assert(a.fixedPosition == 128);
	assert(a.fixedPosition == sum(seq));
	assert(posLog.map!"a.pos".equal([0, 10, 31, 43, 56, 80, 95, 111]));
	assert(a.phase == 0);

	// scroll from the start for destinationShift in forward direction
	posLog = null;
	a = Cursor();
	a.scroll(40);
	test!true(a, seq, posLog);
	assert(a.fixedPosition == 31);
	assert(a.fixedPosition == sum(seq[0..2]));
	assert(posLog.map!"a.pos".equal([0, 10, 31]));
	assert(a.phase == 9);

	// scroll from the start for destinationShift in forward direction
	// destinationShift is equal to the start position of the element
	posLog = null;
	a = Cursor();
	a.scroll(43);
	test!true(a, seq, posLog);
	assert(a.fixedPosition == 43);
	assert(posLog.map!"a.pos".equal([0, 10, 31, 43]));
	assert(a.phase == 0);

	// scroll from the end to the start in backward direction
	posLog = null;
	a = Cursor(sum(seq));
	test!false(a, seq, posLog);
	assert(a.fixedPosition == 128);
	assert(posLog.map!"a.pos".equal([111, 95, 80, 56, 43, 31, 10, 0]));
	assert(a.phase == 0);

	// scroll from the end to the start for destinationShift in backward direction
	posLog = null;
	a = Cursor(sum(seq));
	a.scroll(83);
	test!false(a, seq, posLog);
	assert(a.fixedPosition == 72);
	assert(posLog.map!"a.pos".equal([111, 95, 80, 56, 43]));
	assert(a.phase == 11);

	// scroll from the end to the start for destinationShift in backward direction
	// destinationShift is equal to the start position of the element
	posLog = null;
	a = Cursor(sum(seq));
	a.scroll(85);
	test!false(a, seq, posLog);
	assert(a.fixedPosition == 85);
	assert(posLog.map!"a.pos".equal([111, 95, 80, 56, 43, 31]));
	assert(a.phase == 0);

	// working with subsequence
	// scroll from the end to the start for destinationShift in backward direction
	auto subseq = seq[0..5];

	posLog = null;
	a = Cursor(sum(subseq));
	a.scroll(85);
	test!false(a, subseq, posLog);
	assert(a.fixedPosition == 80);
	assert(posLog.map!"a.pos".equal([56, 43, 31, 10, 0]));
	assert(a.phase == 5);

	posLog = null;
	a = Cursor(sum(subseq));
	a.scroll(38);
	test!false(a, subseq, posLog);
	assert(a.fixedPosition == 37);
	assert(posLog.map!"a.pos".equal([56, 43, 31]));
	assert(a.phase == 1);
}
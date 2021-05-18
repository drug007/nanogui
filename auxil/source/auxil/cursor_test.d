module auxil.cursor_test;

import std;

import unit_threaded;

import auxil.cursor;

//     128 118  97  85  72  48  33  17    0
//           0  10  31  43  56  80  95  111 128
enum sequence = [10, 21, 12, 13, 24, 15, 16, 17];

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

@Name("start2end")
unittest
{
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the start to the end in forward direction
	auto a = Cursor();
	test!true(a, seq, posLog);
	a.fixedPosition.should.be == 128;
	a.fixedPosition.should.be == sum(seq);
	posLog.map!"a.pos".should.be == [0, 10, 31, 43, 56, 80, 95, 111];
	a.phase.should.be == 0;

	a.fixUp;
	a.fixedPosition.should.be == 111;
}

@Name("start2endFor40")
unittest
{
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the start for destinationShift in forward direction
	auto a = Cursor();
	a.scroll(40);
	test!true(a, seq, posLog);
	a.fixedPosition.should.be == 31;
	a.fixedPosition.should.be == sum(seq[0..2]);
	posLog.map!"a.pos".should.be == [0, 10, 31];
	a.phase.should.be == 9;
}

@Name("start2endFor43")
unittest
{
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the start for destinationShift in forward direction
	// destinationShift is equal to the start position of the element
	auto a = Cursor();
	a.scroll(43);
	test!true(a, seq, posLog);
	a.fixedPosition.should.be == 43;
	posLog.map!"a.pos".should.be == [0, 10, 31, 43];
	a.phase.should.be == 0;
}

@Name("end2start")
unittest
{
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start in backward direction
	auto a = Cursor(sum(seq));
	test!false(a, seq, posLog);
	a.fixedPosition.should.be == 128;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43, 31, 10, 0];
	a.phase.should.be == 0;
}

@Name("end2startFor83")
unittest
{
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start for destinationShift in backward direction
	auto a = Cursor(sum(seq));
	a.scroll(83);
	test!false(a, seq, posLog);
	a.fixedPosition.should.be == 72;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43];
	a.phase.should.be == 11;
}

@Name("end2startFor85")
unittest
{
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start for destinationShift in backward direction
	// destinationShift is equal to the start position of the element
	auto a = Cursor(sum(seq));
	a.scroll(85);
	test!false(a, seq, posLog);
	a.fixedPosition.should.be == 85;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43, 31];
	a.phase.should.be == 0;
}

@Name("end2startSubSequence")
unittest
{
	LogRecord[] posLog;

	// working with subsequence
	// scroll from the end to the start for destinationShift in backward direction
	auto subseq = sequence.dup[0..5];

	auto a = Cursor(sum(subseq));
	a.scroll(85);
	test!false(a, subseq, posLog);
	a.fixedPosition.should.be == 80;
	posLog.map!"a.pos".should.be == [56, 43, 31, 10, 0];
	a.phase.should.be == 5;
}
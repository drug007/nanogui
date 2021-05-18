module auxil.cursor_test;

import std;

version(unittest)
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

auto test(Cursor.Order order, R)(ref Cursor a, R r, ref LogRecord[] log)
{
	static if (order == Cursor.Order.forward)
		auto data = r;
	else
		auto data = r.retro;
	foreach(e; data)
	{
		a.begin(e);
		log ~= LogRecord(a.calcPosition!order, e);
		a.next(e);
		if (a.complete)
			break;
	}
}

version(unittest)
@Name("start2end")
unittest
{
	const order = Cursor.Order.forward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the start to the end in forward direction
	auto a = Cursor();
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 128;
	a.fixedPosition.should.be == sum(seq);
	posLog.map!"a.pos".should.be == [0, 10, 31, 43, 56, 80, 95, 111];
	a.phase.should.be == 0;

	a.fixUp!order;
	a.fixedPosition.should.be == 111;
}

version(unittest)
@Name("start2endPosition50")
unittest
{
	const order = Cursor.Order.forward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the start to the end in forward direction from
	// non zero position
	auto init_pos = 50;
	auto a = Cursor(init_pos);
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 128;
	a.fixedPosition.should.be == sum(seq);
	posLog.map!"a.pos".should.be == [0, 10, 31, 43, 56, 80, 95, 111].map!(a=>a+init_pos);
	a.phase.should.be == 0;

	a.fixUp!order;
	a.fixedPosition.should.be == 111;
}

version(unittest)
@Name("start2endFor40")
unittest
{
	const order = Cursor.Order.forward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the start for destinationShift in forward direction
	auto a = Cursor();
	a.scroll(40);
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 31;
	a.fixedPosition.should.be == sum(seq[0..2]);
	posLog.map!"a.pos".should.be == [0, 10, 31];
	a.phase.should.be == 9;
}

version(unittest)
@Name("start2endFor43")
unittest
{
	const order = Cursor.Order.forward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the start for destinationShift in forward direction
	// destinationShift is equal to the start position of the element
	auto a = Cursor();
	a.scroll(43);
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 43;
	posLog.map!"a.pos".should.be == [0, 10, 31, 43];
	a.phase.should.be == 0;
}

version(unittest)
@Name("end2start")
unittest
{
	const order = Cursor.Order.backward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start in backward direction
	auto a = Cursor(sum(seq));
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 128;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43, 31, 10, 0];
	a.phase.should.be == 0;
}

version(unittest)
@Name("end2startFor83")
unittest
{
	const order = Cursor.Order.backward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start for destinationShift in backward direction
	auto a = Cursor(sum(seq));
	a.scroll(83);
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 72;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43];
	a.phase.should.be == 11;
}

version(unittest)
@Name("end2startFor85")
unittest
{
	const order = Cursor.Order.backward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start for destinationShift in backward direction
	// destinationShift is equal to the start position of the element
	auto a = Cursor(sum(seq));
	a.scroll(85);
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 85;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43, 31];
	a.phase.should.be == 0;
}

version(unittest)
@Name("end2startFor128")
unittest
{
	const order = Cursor.Order.backward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start for destinationShift in backward direction
	// destinationShift is equal to the start position of the element
	auto a = Cursor(sum(seq));
	a.scroll(128);
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 128;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43, 31, 10, 0];
	a.phase.should.be == 0;
}

version(unittest)
@Name("end2startFor300")
unittest
{
	const order = Cursor.Order.backward;
	LogRecord[] posLog;
	auto seq = sequence.dup;

	// scroll from the end to the start for destinationShift in backward direction
	// destinationShift is equal to the start position of the element
	auto a = Cursor(sum(seq));
	a.scroll(300);
	test!order(a, seq, posLog);
	a.fixedPosition.should.be == 128;
	posLog.map!"a.pos".should.be == [111, 95, 80, 56, 43, 31, 10, 0];
	a.phase.should.be == 172;
}

version(unittest)
@Name("end2startSubSequence")
unittest
{
	const order = Cursor.Order.backward;
	LogRecord[] posLog;

	// working with subsequence
	// scroll from the end to the start for destinationShift in backward direction
	auto subseq = sequence.dup[0..5];

	auto a = Cursor(sum(subseq));
	a.scroll(85);
	test!order(a, subseq, posLog);
	a.fixedPosition.should.be == 80;
	posLog.map!"a.pos".should.be == [56, 43, 31, 10, 0];
	a.phase.should.be == 5;
}
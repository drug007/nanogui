module auxil.test2;

import std;

//     128 118  97  85  72  48  33  17    0
//           0  10  31  43  56  80  95  111 128
auto seq = [10, 21, 12, 13, 24, 15, 16, 17];

struct Location
{
	float loc;
	void next(float v)
	{
		loc += v;
	}
	@disable this();
	this(float v) { loc = v; }
}

struct Automata
{
	// sum of all previous elements
	// it can have only fixed set of values so it is called `fixed`
	float fixedValue = 0;
	// the value we should iterate over given sequence and
	// can be any value
	float destinationShift;
	Location loc;
	float init_value;

	this(float v) { loc = Location(0); init_value = v; }

	private bool _complete;
	bool complete() { return _complete; }
	void next(int v)
	{
		if (fixedValue + v > destinationShift)
		{
			_complete = true;
		}
		else
		{
			doNext(v);
		}
	}

	package void doNext(int v)
	{
		fixedValue += v;
		loc.next(v);
	}

	auto position(bool forward)(float e)
	{
		static if (forward)
			return init_value + loc.loc;
		else
			return init_value - loc.loc - e;
	}
}

struct LogRecord
{
	float pos;
	float value;
}

auto test(R)(ref Automata a, R data)
{
	LogRecord[] log;
	test(a, data, log);
}

auto test(bool forward, R)(ref Automata a, R r, ref LogRecord[] log)
{
	static if (forward)
		auto data = r;
	else
		auto data = r.retro;
	foreach(e; data)
	{
		log ~= LogRecord(a.position!forward(e), e);
		a.next(e);
		if (a.complete)
			break;
	}
}

void testBasics()
{
	LogRecord[] posLog;

	// scroll from the start to the end in forward direction
	auto a = Automata(0);
	test!true(a, seq, posLog);
	assert(a.fixedValue == 128);
	assert(a.fixedValue == sum(seq));
	assert(posLog.map!"a.pos".equal([0, 10, 31, 43, 56, 80, 95, 111]));

	// scroll from the start for destinationShift in forward direction
	posLog = null;
	a = Automata(0);
	a.destinationShift = 40;
	test!true(a, seq, posLog);
	assert(a.destinationShift == 40);
	assert(a.fixedValue == 31);
	assert(a.fixedValue == sum(seq[0..2]));
	assert(posLog.map!"a.pos".equal([0, 10, 31]));

	// scroll from the start for destinationShift in forward direction
	// destinationShift is equal to the start position of the element
	posLog = null;
	a = Automata(0);
	a.destinationShift = 43;
	test!true(a, seq, posLog);
	assert(a.fixedValue == 43);
	assert(a.destinationShift == 43);
	assert(posLog.map!"a.pos".equal([0, 10, 31, 43]));

	// scroll from the end to the start in backward direction
	posLog = null;
	a = Automata(sum(seq));
	test!false(a, seq, posLog);
	assert(a.fixedValue == 128);
	const total_sum = sum(seq);

	assert(posLog.map!"a.pos".equal([111, 95, 80, 56, 43, 31, 10, 0]));

	// scroll from the end to the start for destinationShift in backward direction
	posLog = null;
	a = Automata(sum(seq));
	a.destinationShift = 83;
	test!false(a, seq, posLog);
	assert(a.fixedValue == 72);
	assert(a.destinationShift == 83);
	assert(posLog.map!"a.pos".equal([111, 95, 80, 56, 43]));

	// scroll from the end to the start for destinationShift in backward direction
	// destinationShift is equal to the start position of the element
	posLog = null;
	a = Automata(sum(seq));
	a.destinationShift = 85;
	test!false(a, seq, posLog);
	assert(a.fixedValue == 85);
	assert(a.destinationShift == 85);
	assert(posLog.map!"a.pos".equal([111, 95, 80, 56, 43, 31]));

	// working with subsequence
	// scroll from the end to the start for destinationShift in backward direction
	auto subseq = seq[0..5];

	posLog = null;
	a = Automata(sum(subseq));
	a.destinationShift = 85;
	test!false(a, subseq, posLog);
	assert(a.fixedValue == 80);
	assert(a.destinationShift == 85);
	assert(posLog.map!"a.pos".equal([56, 43, 31, 10, 0]));

	posLog = null;
	a = Automata(sum(subseq));
	a.destinationShift = 38;
	test!false(a, subseq, posLog);
	assert(a.fixedValue == 37);
	assert(a.destinationShift == 38);
	assert(posLog.map!"a.pos".equal([56, 43, 31]));
}

void testSequentialScrollingForward()
{
	LogRecord[] posLog;
	auto a = Automata(0);

	// scroll from the start for destinationShift in forward direction
	a.destinationShift = 40;
	test!true(a, seq, posLog);
	assert(a.destinationShift == 40);
	assert(a.fixedValue == 31);
	assert(a.fixedValue == sum(seq[0..2]));
	assert(posLog.map!"a.pos".equal([0, 10, 31]));
}
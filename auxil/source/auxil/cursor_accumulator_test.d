module auxil.cursor_accumulator_test;

import std;

version(unittest)
import unit_threaded;

import auxil.cursor_accumulator;
import auxil.cursor_test : sequence, LogRecord;

version(unittest)
@Name("testForward")
unittest
{
	import auxil.cursor : Cursor;

	const order = Cursor.Order.forward;
	LogRecord[] posLog;
	CursorAccumulator ca;

	ca.start;

	auto seq = sequence.dup;
	foreach(e; seq)
	{
		ca.begin(e);
		posLog ~= LogRecord(ca.position!order, e);
		ca.end(e);
	}

	posLog.should.be == [
		LogRecord(0, 10),
		LogRecord(10, 21),
		LogRecord(31, 12),
		LogRecord(43, 13),
		LogRecord(56, 24),
		LogRecord(80, 15),
		LogRecord(95, 16),
		LogRecord(111, 17),
	];

	// after traversing and before commit
	// fixedPosition equals to calcPosition result
	// and is the position of the next element after
	// the last one
	ca.csr.fixedPosition.should.be == 128;
	ca.csr.calcPosition!order.should.be == 128;
	ca.position!order.should.be == 128;

	// we call it if we want to scroll further
	// so we need to store the current position
	ca.commit!order;

	posLog.should.be == [
		LogRecord(0, 10),
		LogRecord(10, 21),
		LogRecord(31, 12),
		LogRecord(43, 13),
		LogRecord(56, 24),
		LogRecord(80, 15),
		LogRecord(95, 16),
		LogRecord(111, 17),
	];

	// after commit fixedPosition is reset
	// and the current position returned by calcPosition
	// equals to the position of the last element
	// (not the next element after the last one)
	ca.csr.fixedPosition.should.be == 0;
	ca.csr.calcPosition!order.should.be == 111;
	ca.position!order.should.be == 111;
}

version(unittest)
@Name("testBackward")
unittest
{
	import auxil.cursor : Cursor;

	const order = Cursor.Order.backward;
	LogRecord[] posLog;
	auto seq = sequence.dup.retro;
	CursorAccumulator ca;

	ca.start(sum(seq));
	foreach(e; seq)
	{
		ca.begin(e);
		posLog ~= LogRecord(ca.position!order, e);
		ca.end(e);
	}

	posLog.should.be == [
		LogRecord(111, 17), 
		LogRecord( 95, 16), 
		LogRecord( 80, 15), 
		LogRecord( 56, 24), 
		LogRecord( 43, 13), 
		LogRecord( 31, 12), 
		LogRecord( 10, 21), 
		LogRecord(  0, 10)
	];

	ca.csr.fixedPosition.should.be == 128;
	ca.csr.calcPosition!order.should.be == -10;
	ca.position!order.should.be == -10;

	// we call it if we want to scroll further
	// so we need to store the current position
	ca.commit!order;

	posLog.should.be == [
		LogRecord(111, 17), 
		LogRecord( 95, 16), 
		LogRecord( 80, 15), 
		LogRecord( 56, 24), 
		LogRecord( 43, 13), 
		LogRecord( 31, 12), 
		LogRecord( 10, 21), 
		LogRecord(  0, 10)
	];

	// after commit fixedPosition is reset
	// and the current position returned by calcPosition
	// equals to the position of the last element
	// (not the next element after the last one)
	ca.csr.fixedPosition.should.be == 0;
	ca.csr.calcPosition!order.should.be == -10;
	ca.position!order.should.be == -10;
}

version(unittest)
@Name("testTraversingForward")
unittest
{
	import auxil.cursor : Cursor;

	const order = Cursor.Order.forward;
	LogRecord[] posLog;
	auto seq = sequence.dup;
	CursorAccumulator ca;

	// start traversing
	ca.start;

	// step #1 - scroll 3 first elements
	{
		posLog = null;
		foreach(e; seq[0..3])
		{
			ca.begin(e);
			posLog ~= LogRecord(ca.position!order, e);
			ca.end(e);
		}

		// checks
		posLog.should.be == [
			LogRecord(0, 10),
			LogRecord(10, 21),
			LogRecord(31, 12),
		];

		ca.position!order.should.be == 43;
		ca.csr.last_value.should.be == 12;
	}

	// step #2 - scroll for the next 3 elements
	{
		posLog = null;
		foreach(e; seq[3..6])
		{
			ca.begin(e);
			posLog ~= LogRecord(ca.position!order, e);
			ca.end(e);
		}

		// checks
		posLog.should.be == [
			LogRecord(43, 13),
			LogRecord(56, 24),
			LogRecord(80, 15),
		];

		ca.position!order.should.be == 95;
		ca.csr.last_value.should.be == 15;
	}

	// step #3 - scroll for the last two elements
	{
		posLog = null;
		foreach(e; seq[6..$])
		{
			ca.begin(e);
			posLog ~= LogRecord(ca.position!order, e);
			ca.end(e);
		}

		// check
		posLog.should.be == [
			LogRecord(95, 16),
			LogRecord(111, 17),
		];

		ca.position!order.should.be == 128;
		ca.csr.last_value.should.be == 17;
	}

	// step #4 - scroll for the first two elements
	{
		ca.start;
		posLog = null;
		foreach(e; seq[0..2])
		{
			ca.begin(e);
			posLog ~= LogRecord(ca.position!order, e);
			ca.end(e);
		}

		// check
		posLog.should.be == [
			LogRecord(0, 10),
			LogRecord(10, 21),
		];

		ca.position!order.should.be == 31;
		ca.csr.last_value.should.be == 21;
	}
}

version(unittest)
@Name("testScrollingForward")
unittest
{
	import auxil.cursor : Cursor;

	const order = Cursor.Order.forward;
	LogRecord[] posLog;
	auto seq = sequence.dup;
	CursorAccumulator ca;

	// start scrolling
	ca.start;

	// step 1
	{
		foreach(e; seq[0..$/2])
		{
			ca.begin(e);
			posLog ~= LogRecord(ca.position!order, e);
			ca.end(e);
		}

		ca.position!order.should.be == 56;
		ca.csr.last_value.should.be == 13;

		// commiting is the difference between scrolling and traversing
		ca.commit!order;

		posLog.should.be == [
			LogRecord(0, 10),
			LogRecord(10, 21),
			LogRecord(31, 12),
			LogRecord(43, 13),
		];

		ca.position!order.should.be == 43;
		ca.csr.last_value.should.be == 13;
		ca.csr.current_value.should.be == 13;
	}

	// step 2
	{
		posLog = null;

		foreach(e; seq[$/2-1..$]) // <= important that we start from the last element ($/2-1 not just $/2)
		{
			ca.begin(e);
			posLog ~= LogRecord(ca.position!order, e);
			ca.end(e);
		}
		ca.position!order.should.be == 128;
		ca.csr.last_value.should.be == 17;
		ca.csr.current_value.should.be == 17;

		ca.commit!order;

		posLog.should.be == [
			LogRecord(43, 13),
			LogRecord(56, 24),
			LogRecord(80, 15),
			LogRecord(95, 16),
			LogRecord(111, 17),
		];

		ca.position!order.should.be == 111;
		ca.csr.last_value.should.be == 17;
		ca.csr.current_value.should.be == 17;
	}
}
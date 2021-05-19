module auxil.cursor;

import std.math : isNaN;

struct Cursor
{
	alias Type = int;
	/// defines direction of traversing
	enum Order : bool { backward, forward, }

	// sum of all previous elements
	// it can have only fixed set of values so it is called `fixed`
	Type fixedPosition;
	// the value we should iterate over given sequence and
	// can be any value
	private Type _destination;
	// the start position
	Type init_value;
	Type last_value;
	Type current_value;

	this(Type v) @safe @nogc
	{
		reset(v);
	}

	void reset(Type v = 0) @safe @nogc
	{
		fixedPosition = 0;
		_destination  = 0;
		init_value    = v;
		last_value    = 0;
		current_value = 0;
	}

	void scroll(Type value) @safe @nogc
	{
		assert(value >= 0);
		_destination = fixedPosition + value;
	}

	auto phase() @safe @nogc const
	{
		return _destination - fixedPosition;
	}

	// used if the sequence has ended before
	// the destination was achieved
	// because the current position is 
	// the position of the next elements, i.e.
	// non-existing element because the sequence
	// has ended
	//
	// probably it is a hack
	auto fixUp(Order order)() @safe @nogc
	{
		static assert(order == Order.forward, "the method is intended for forward mode only");
		fixedPosition -= last_value;
	}

	private bool _complete;
	bool complete() @safe @nogc { return _complete; }

	void begin(Type v) @safe @nogc
	{
		current_value = v;
	}

	void next(Type v) @safe @nogc
	{
		if (fixedPosition + v > _destination)
		{
			_complete = true;
		}
		else
		{
			last_value = v;
			fixedPosition += last_value;
		}
	}

	void toString(Writer)(ref Writer w) @safe
	{
		import std.algorithm : copy;
		import std.conv : text;
		typeof(this).stringof.copy(w);
		w.put('(');
		static foreach(i; 0..this.tupleof.length)
		{{
			enum name = __traits(identifier, this.tupleof[i]);
			text(name, " : ", this.tupleof[i], ", ").copy(w);
		}}
		w.put(')');
	}

	package auto calcPosition(Order order)() @safe @nogc
	{
		static if (order == Cursor.Order.forward)
			return init_value + fixedPosition;
		else
			return init_value - fixedPosition - current_value;
	}
}

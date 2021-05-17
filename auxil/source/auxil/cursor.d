module auxil.cursor;

import std.math : isNaN;

struct Cursor
{
	// sum of all previous elements
	// it can have only fixed set of values so it is called `fixed`
	float fixedPosition = 0;
	// the value we should iterate over given sequence and
	// can be any value
	private float _destination;
	// the start position
	float init_value = 0;
	// current position relative to init_value
	float loc = 0;

	this(float v) { loc = 0; init_value = v; }

	void reset(float v = init_value.init) @safe @nogc
	{
		fixedPosition = 0;
		_destination  = _destination.init;
		init_value    = v;
		loc           = 0;
	}

	void scroll(float value) @safe @nogc
	{
		_destination = value;
	}

	auto phase() @safe @nogc const
	{
		if (_destination.isNaN)
			return 0;

		return _destination - fixedPosition;
	}

	private bool _complete;
	bool complete() @safe @nogc { return _complete; }
	void next(float v) @safe @nogc
	{
		if (fixedPosition + v > _destination)
		{
			_complete = true;
		}
		else
		{
			fixedPosition += v;
			loc += v;
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

	package auto calcPosition(bool forward)(float e) @safe @nogc
	{
		static if (forward)
			return init_value + loc;
		else
			return init_value - loc - e;
	}
}

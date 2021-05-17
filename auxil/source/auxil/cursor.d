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
	float last_value;

	this(float v) @safe @nogc
	{
		reset(v);
	}

	void reset(float v = 0) @safe @nogc
	{
		fixedPosition = 0;
		_destination  = _destination.init;
		init_value    = v;
		last_value    = 0;
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

	auto fixUp() @safe @nogc
	{
		fixedPosition -= last_value;
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

	package auto calcPosition(bool forward)(float e) @safe @nogc
	{
		static if (forward)
			return init_value + fixedPosition;
		else
			return init_value - fixedPosition - e;
	}
}

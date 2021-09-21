module auxil.location;

import auxil.model : Orientation; // FIXME avoid import from this module
import auxil.treepath;

alias SizeType = int;

enum Order { Sinking, Bubbling, }

struct Axis
{
	SizeType position, destination, change, size;
}

@safe
struct Location
{
@nogc:
	enum State { seeking, first, rest, finishing, }
	State _state;
	TreePath current_path, path;
	Axis x, y;

	@property
	{
		State state() @safe @nogc nothrow { return _state; }
	}

	package void resetState() @safe @nogc nothrow
	{
		_state = (path.value.length) ? State.seeking : State.rest;
		y.change = 0;
		x.change = 0;
	}

	/// returns true if the processing should be interrupted
	package bool checkState() @safe @nogc
	{
		final switch(_state)
		{
			case State.seeking:
				if (current_path.value == path.value)
					_state = State.first;
			break;
			case State.first:
				_state = State.rest;
			break;
			case State.rest:
				// do nothing
			break;
			case State.finishing:
			{
				return true;
			}
		}
		return false;
	}

	void indent()
	{
		current_path.put(0);
	}

	void unindent()
	{
		current_path.popBack;
	}

	auto startValue(Order order)(size_t len)
	{
		import std.algorithm : among;

		size_t start_value;
		static if (order == Order.Bubbling)
		{
			start_value = len;
			start_value--;
		}
		if (_state.among(State.seeking, State.first))
		{
			auto idx = current_path.value.length;
			if (idx && path.value.length >= idx)
			{
				start_value = path.value[idx-1];
				// position should change only if we've got the initial path
				// and don't get the end
				if (_state == State.seeking) y.change = 0;
			}
		}
		return start_value;
	}

	void setPath(int v)
	{
		current_path.back = v;
	}

	bool stateFirstOrRest() @safe @nogc pure nothrow
	{
		import std.algorithm : among;
		return !!_state.among(State.first, State.rest);
	}
}
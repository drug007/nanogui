module auxil.location;

import auxil.treepath;

alias SizeType = int;

enum Order { Sinking, Bubbling, }

@safe
struct Location
{
@nogc:
	enum State { seeking, first, rest, finishing, }
	enum Orientation { Horizontal, Vertical, }
	private State _state;
	Orientation orientation = Orientation.Vertical;
	TreePath tree_path, path;
	SizeType destination;
	SizeType[2] _position;
	private SizeType _deferred_change;

	@property position() { return _position[orientation]; }
	@property position(SizeType v) { _position[orientation] = v; }

	@property State state() @safe @nogc nothrow { return _state; }

	package void resetState() @safe @nogc nothrow
	{
		_state = (path.value.length) ? State.seeking : State.rest;
		_deferred_change = 0;
	}

	/// returns true if the processing should be interrupted
	package bool checkState() @safe @nogc
	{
		final switch(_state)
		{
			case State.seeking:
				if (tree_path.value == path.value)
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

	auto movePositionIfSinking(Order order)(SizeType header_size)
	{
		static if (order == Order.Sinking)
		{
			position = position + _deferred_change;
			_deferred_change = header_size;
		}
	}

	auto checkPositionIfSinking(Order order)()
	{
		static if (order == Order.Sinking)
		{
			if (position+_deferred_change > destination)
			{
				path = tree_path;
				_state = State.finishing;
			}
		}
	}

	auto movePositionIfBubbling(Order order)(SizeType header_size)
	{
		static if (order == Order.Bubbling)
		{
			position = position + _deferred_change;
			_deferred_change = -header_size;
		}
	}

	auto checkPositionIfBubbling(Order order)()
	{
		static if (order == Order.Bubbling)
		{
			if (position <= destination)
			{
				_state = State.finishing;
				path = tree_path;
			}
		}
	}

	void intend()
	{
		tree_path.put(0);
	}

	void unintend()
	{
		tree_path.popBack;
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
			auto idx = tree_path.value.length;
			if (idx && path.value.length >= idx)
			{
				start_value = path.value[idx-1];
				// position should change only if we've got the initial path
				// and don't get the end
				if (_state == State.seeking) _deferred_change = 0;
			}
		}
		return start_value;
	}

	void setPath(int v)
	{
		tree_path.back = v;
	}

	bool stateFirstOrRest()
	{
		import std.algorithm : among;
		return !!_state.among(State.first, State.rest);
	}
}
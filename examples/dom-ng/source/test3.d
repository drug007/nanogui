module test3;

import std.algorithm : map;
import std.stdio;
import core.thread.fiber;
import std.container.rbtree;

struct Item
{
	uint id;
	string description;
}

struct ItemPtr
{
	uint id;
	Item* payload;

	this(uint i)
	{
		id = i;
		payload = null;
	}

	this(ref Item i)
	{
		id = i.id;
		payload = &i;
	}

	this(uint i, Item* p)
	{
		id = i;
		payload = p;
	}
}

struct ItemIndex
{
	alias Impl = RedBlackTree!(ItemPtr, "a.id < b.id");
	Impl _impl;
	alias _impl this;

	auto keys()
	{
		import std.array : array;
		return _impl[].map!"a.id".array;
	}

	struct Range
	{
		import std.array : back, empty, front, popBack, popFront;

		alias Type = ItemPtr;
		alias Keys = typeof(ItemIndex.init.keys());
		private ItemIndex* _idx;
		private Keys _keys;

		this(ref ItemIndex si)
		{
			_idx = &si;
			_keys = si.keys;
		}

		this(ItemIndex* i, Keys k)
		{
			_idx = i;
			_keys = k;
		}

		@disable this();

		bool empty()
		{
			return _keys.empty;
		}

		Type front()
		{
			auto e = ItemPtr(_keys.front);
			return _idx.equalRange(e).front;
		}

		void popFront()
		{
			_keys.popFront;
		}

		Type back()
		{
			auto e = ItemPtr(_keys.front);
			return _idx.equalRange(e).front;
		}

		void popBack()
		{
			_keys.popBack;
		}

		typeof(this) save()
		{
			auto instance = this;
			instance._keys = _keys.dup;
			return instance;
		}

		Type opIndex(size_t idx)
		{
			auto e = ItemPtr(_keys.front);
			return _idx.equalRange(e).front;
		}

		size_t length()
		{
			return _keys.length;
		}
	}

	auto opIndex(uint i)
	{
		return _impl.equalRange(ItemPtr(i, null)).front;
	}

	auto opSlice()
	{
		return Range(this);
	}
}

void testItemIndex()
{
	Item[] data = [
		Item(100, "item100"),
		Item(200, "item200"),
		Item(50, "item50"),
	];

	auto index = ItemIndex();
	index._impl = new ItemIndex.Impl(data.map!((ref a)=>ItemPtr(a.id, &a)));

	writeln(index[].map!"*a.payload");
	writeln;

	auto idx = index[];

	scope Fiber composed = new Fiber(()
	{
		while(!idx.empty)
		{
			writeln(*idx.front.payload);
			idx.popFront;
			Fiber.yield();
		}
	});

	composed.call();
	composed.call();
	composed.call();
	composed.call();

	// since each fiber has run to completion, each should have state TERM
	assert( composed.state == Fiber.State.TERM );
}
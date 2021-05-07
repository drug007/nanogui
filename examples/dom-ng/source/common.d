module common;

import core.thread.fiber;

auto makeRange(V, D)(ref V visitor, D dg)
{
	return Range!V(visitor, dg);
}

struct Range(P)
{
	import core.lifetime : emplace;

	private P* _parent;
	
	void[__traits(classInstanceSize, Fiber)] _buffer;
	private this(D)(ref P parent, D dg)
	{
		_parent = &parent;
		auto fiber = emplace!Fiber(_buffer, dg);
		assert(fiber.state == Fiber.State.HOLD);
	}

	bool empty()
	{
		auto fiber = (() @trusted => cast(Fiber)(_buffer.ptr))();
		return fiber.state == Fiber.State.TERM;
	}

	void popFront()
	{
		assert(!empty);
		auto fiber = (() @trusted => cast(Fiber)(_buffer.ptr))();
		fiber.call;
	}

	ref front() return { return *_parent; }
}

module common;

import core.thread.fiber;

auto makeRange(V, D)(ref V visitor, D dg)
{
	auto r = Range!V(visitor, dg);
	assert(!r.empty);
	r.popFront; // we need to enter the tree
	return r;
}

struct Range(P)
{
	import core.lifetime : emplace;
	import core.stdc.stdlib : free, malloc;

	private P* _parent;

	Fiber _fiber;
	private this(D)(ref P parent, D dg)
	{
		_parent = &parent;
		enum FiberSize = __traits(classInstanceSize, Fiber);
		auto buffer = malloc(FiberSize);
		import std.exception : enforce;
		enforce(buffer);
		_fiber = emplace!Fiber(buffer[0..FiberSize], dg);
		assert(_fiber.state == Fiber.State.HOLD);
	}

	~this()
	{
		destroy(_fiber);
		free(cast(void*)_fiber);
	}

	debug invariant
	{
		assert(_fiber.state != Fiber.State.EXEC);
	}

	bool empty()
	{
		return _fiber.state == Fiber.State.TERM;
	}

	void popFront()
	{
		assert(!empty);
		_fiber.call;
	}

	ref front() return { return *_parent; }
}

module auxil.model.two_faced_range;

import auxil.model : Order;

version(unittest) import unit_threaded : Name;

package struct TwoFacedRange(Order order)
{
	int s, l;

	@disable this();

	this(size_t s, size_t l)
	{
		this.s = cast(int) s;
		this.l = cast(int) l;
	}

	bool empty() const
	{
		return (-1 >= s) || (s >= l);
	}

	int front() const
	{
		assert(!empty);
		return s;
	}

	void popFront()
	{
		assert(!empty);
		static if (order == Order.Sinking)  s++; else
		static if (order == Order.Bubbling) s--; else
		static assert(0);
	}
}

version(unittest) @Name("two_faced_range")
unittest
{
	import unit_threaded;

	int[] empty;

	{
		auto rf = TwoFacedRange!(Order.Sinking)(1, 2);
		rf.should.be == [1];
		// lower boundary is always inclusive
		auto rb = TwoFacedRange!(Order.Bubbling)(1, 2);
		rb.should.be == [1, 0];
	}
	{
		auto rf = TwoFacedRange!(Order.Sinking)(2, 4);
		rf.should.be == [2, 3];
		// lower boundary is always inclusive
		auto rb = TwoFacedRange!(Order.Bubbling)(2, 4);
		rb.should.be == [2, 1, 0];
	}
	{
		auto rf = TwoFacedRange!(Order.Sinking)(0, 4);
		rf.should.be == [0, 1, 2, 3];
		auto rb = TwoFacedRange!(Order.Bubbling)(0, 4);
		rb.should.be == [0];
	}
	{
		auto rf = TwoFacedRange!(Order.Sinking)(4, 4);
		rf.should.be == empty;
		auto rb = TwoFacedRange!(Order.Bubbling)(4, 4);
		rb.should.be == empty;
	}
	{
		auto rf = TwoFacedRange!(Order.Sinking)(0, 0);
		rf.should.be == empty;
		auto rb = TwoFacedRange!(Order.Bubbling)(0, 0);
		rb.should.be == empty;
	}
}

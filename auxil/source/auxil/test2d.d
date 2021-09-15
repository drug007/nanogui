module auxil.test2d;

version(unittest) import unit_threaded : Name, should, be;

import auxil.model;
import auxil.default_visitor : TreePathVisitorImpl, MeasuringVisitor;
import auxil.location : SizeType, Axis;

struct Pos
{
	Axis x, y;

	this(ref Axis x, ref Axis y)
	{
		this.x = x;
		this.y = y;
	}

	this(SizeType x, SizeType y, SizeType w, SizeType h)
	{
		this.x.position = x;
		this.y.position = y;
		this.x.size = w;
		this.y.size = h;
	}

	auto opEquals(ref const(Pos) other) const
	{
		if (x.position != other.x.position)
			return false;
		if (x.size != other.x.size)
			return false;
		if (y.position != other.y.position)
			return false;
		if (y.size != other.y.size)
			return false;
		return true;
	}

	void toString(W)(ref W w) const
	{
		import std.algorithm : copy;
		import std.conv : text;

		text("Pos(", 
			x.position, ", ",
			y.position, ", ",
			x.size, ", ",
			y.size, 
		")"
		).copy(w);
	}
}

@safe private
struct Visitor2D
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem.vector : Vector;

	alias TreePathVisitor = TreePathVisitorImpl!(typeof(this));
	TreePathVisitor default_visitor;
	alias default_visitor this;

	Vector!(Pos, Mallocator) position;

	this(SizeType[2] size) @nogc
	{
		default_visitor = TreePathVisitor(size);
	}

	void enterTree(Order order, Data, Model)(ref const(Data) data, ref Model model) {}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (Model.Collapsable || order == Order.Sinking)
		{
			() @trusted {
				position ~= Pos(loc.x, loc.y);
			} ();
		}
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void beforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void afterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
}

/// test for 2D positioning using text mode only (no coordinates)
version(unittest) @Name("text2D")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	Test[2] data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model[0].collapsed = false;
	model[1].collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}

	model.size.should.be == 90;
	model.header_size.should.be == 10;
	model.length.should.be == 2;
	model[0].size.should.be == 40;
	model[1].size.should.be == 40;

	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		visitor.position[].should.be == [
			Pos( 0, 0, 300, 10), 
				Pos(10, 10, 290, 10), 
					Pos(20, 20, 280, 10), 
					Pos(20, 30, 280, 10), 
					Pos(20, 40, 280, 10),
				Pos(10, 50, 290, 10), 
					Pos(20, 60, 280, 10), 
					Pos(20, 70, 280, 10), 
					Pos(20, 80, 280, 10),
		];
	}();

	model[0].orientation = Orientation.Horizontal;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);

		model.size.should.be == 60;

		with(model[0])
		{
			size.should.be == 290;
			header_size.should.be == 10;
			f.size.should.be == 96;
			i.size.should.be == 97;
			s.size.should.be == 97;
		}
		with(model[1])
		{
			size.should.be == 40;
			header_size.should.be == 10;
			f.size.should.be == 10;
			i.size.should.be == 10;
			s.size.should.be == 10;
		}
	}
	visitor.position.clear;
	visitor.loc.y.position = 0;
	model.visitForward(data, visitor);

	() @trusted
	{
		visitor.position[].should.be == [
			Pos( 0, 0, 300, 10), 
				Pos(10, 10, 290, 10), 
					Pos(10, 10, 96, 10), Pos(10+96, 10, 97, 10), Pos(10+96+97, 10, 290-96-97, 10),
				Pos(10, 20, 290, 10), 
					Pos(20, 30, 280, 10), 
					Pos(20, 40, 280, 10), 
					Pos(20, 50, 280, 10),
		];
	}();
}

version(unittest) @Name("staticAttribute")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	static struct Wrapper
	{
		@("Orientation.Horizontal")
		Test t1;
		Test t2;
	}

	Wrapper data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model.t1.collapsed = false;
	model.t2.collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}
	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		visitor.position[].should.be == [
			Pos( 0, 0, 300, 10), 
				Pos(10, 10, 290, 10), 
					Pos(10, 10, 96, 10), Pos(10+96, 10, 97, 10), Pos(10+96+97, 10, 290-96-97, 10),
				Pos(10, 20, 290, 10), 
					Pos(20, 30, 280, 10), 
					Pos(20, 40, 280, 10), 
					Pos(20, 50, 280, 10),
		];
	}();
}

version(unittest) @Name("twoHorizontalAggregate")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	struct Test1
	{
		double d;
		short sh;
		Test t;
	}

	static struct Wrapper
	{
		@("Orientation.Horizontal")
		Test1 t1;
		@("Orientation.Horizontal")
		Test1 t2;
	}

	Wrapper data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model.t1.collapsed = false;
	model.t2.collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}
	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		visitor.position[].should.be == [
			Pos(0, 0, 300, 590), 
				Pos(10, 10, 290, 10), 
					Pos(10, 10, 96, 10), Pos(106, 10, 97, 10), Pos(203, 10, 97, 10), 
				Pos(10, 20, 290, 10), 
					Pos(10, 20, 96, 10), Pos(106, 20, 97, 10), Pos(203, 20, 97, 10)
		];
	}();
}

version(unittest) @Name("MixedLayoutN0")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	static struct Test1
	{
		double d;
		@("Orientation.Vertical")
		Test t;
		short sh;
	}

	static struct Test2
	{
		double d = 9.98;
		@("Orientation.Horizontal")
		Test1 t1;
		string str = "cool";
	}

	Test2 data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model.t1.collapsed = false;
	model.t1.t.collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}
	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		visitor.position[].should.be == [
			Pos(0, 0, 300, 10),     /* Test2 (Header) */
				Pos(10, 10, 290, 10),  /* Test2.d */
				Pos(10, 20, 290, 10),  /* Test2.t1 (Header) */
					// Test1.d           Test1.t (Header)                      Test1.sh
					Pos(10, 20, 96, 10), Pos(106, 20, 96, 10), 
					                        Pos(116, 30, 86, 10), /* Test.f */
					                        Pos(116, 40, 86, 10), /* Test.i */
					                        Pos(116, 50, 86, 10), /* Test.s */
					                                                           Pos(203, 20, 97, 10), 
				Pos(10, 60, 290, 10),  /* Test2.str */
		];
	}();
}
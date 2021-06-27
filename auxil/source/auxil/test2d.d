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

	Vector!(char, Mallocator) output;
	private Vector!(char, Mallocator) _indentation;

	Vector!(Pos, Mallocator) position;
	SizeType size;


	Axis x, old_x;

	this(SizeType size) @nogc
	{
		this.size = size;
	}

	auto processItem(T...)(T msg)
	{
		() @trusted {
			output ~= _indentation[];
			import nogc.conv : text;
			output ~= text(msg)[];
		} ();
	}

	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		x.position = 0;
		final switch (this.orientation)
		{
			case Orientation.Vertical:
				x.size = size;
			break;
			case Orientation.Horizontal:
				x.size = model.size;
			break;
		}
		default_visitor.enterTree!(order, Data)(data, model);
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (Model.Collapsable)
		{
			import auxil.traits : hasRenderHeader;

			old_x = x;

			() @trusted {
				position ~= Pos(x, loc.y);
			} ();

			final switch (model.orientation)
			{
				case Orientation.Vertical:
					processItem("Caption: ", Data.stringof);
					() @trusted {
						output ~= "\n";
						_indentation ~= "\t";
						x.position = x.position + model.header_size;
						x.size = x.size - model.header_size;
					} ();
				break;
				case Orientation.Horizontal:
				break;
			}
			orientation = model.orientation;
		}
		else static if (order == Order.Sinking)
			processLeaf!(order, Data, Model)(data, model);
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (Model.Collapsable)
		{
			final switch (model.orientation)
			{
				case Orientation.Vertical:
					if (_indentation.length)
						_indentation.popBack;
					x.position = x.position - model.header_size;
					x.size = x.size + model.header_size;
				break;
				case Orientation.Horizontal:
					() @trusted {
						output ~= "\n";
					} ();
					x.position = old_x.position;
					x.size = old_x.size;
				break;
			}
		}
		else static if (order == Order.Bubbling)
			processLeaf!(order, Data, Model)(data, model);
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		final switch (orientation)
		{
			case Orientation.Vertical:
			break;
			case Orientation.Horizontal:
				x.size = model.size;
			break;
		}
		() @trusted {
			position ~= Pos(x, loc.y);
		} ();
		processItem(data);
		final switch (this.orientation)
		{
			case Orientation.Vertical:
				() @trusted {
					output ~= "\n";
				} ();
			break;
			case Orientation.Horizontal:
				x.position = x.position + model.size;
			break;
		}
	}

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

	auto visitor = Visitor2D(300);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model[0].collapsed = false;
	model[1].collapsed = false;
	{
		auto mv = MeasuringVisitor([300, 9]);
		model.visitForward(data, mv);
	}
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

		visitor.output[].should.be == 
"Caption: Test[2]
	Caption: Test
		7.700000
		8
		some text
	Caption: Test
		7.700000
		8
		some text
";
	}();

	model[0].orientation = Orientation.Horizontal;
	{
		auto mv = MeasuringVisitor([300, 9]);
		model.visitForward(data, mv);

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
	visitor.output.clear;
	visitor.position.clear;
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

		visitor.output[].should.be == 
"Caption: Test[2]
	7.700000	8	some text
	Caption: Test
		7.700000
		8
		some text
";
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

	auto visitor = Visitor2D(300);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model.t1.collapsed = false;
	model.t2.collapsed = false;
	{
		auto mv = MeasuringVisitor([300, 9]);
		model.visitForward(data, mv);
	}
	// // visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		visitor.position[].should.be == [
			Pos( 0, 10, 300, 10), 
				Pos(10, 20, 290, 10), 
					Pos(10, 20, 96, 10), Pos(10+96, 20, 97, 10), Pos(10+96+97, 20, 290-96-97, 10),
				Pos(10, 30, 290, 10), 
					Pos(20, 40, 280, 10), 
					Pos(20, 50, 280, 10), 
					Pos(20, 60, 280, 10),
		];

		visitor.output[].should.be == 
"Caption: Wrapper
	7.700000	8	some text
	Caption: Test
		7.700000
		8
		some text
";
	}();
}
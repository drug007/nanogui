module auxil.test2d;

version(unittest) import unit_threaded : Name, should, be;

import auxil.model;
import auxil.default_visitor : TreePathVisitor, MeasuringVisitor;
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
}

@safe private
struct Visitor2D
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem.vector : Vector;

	Vector!(char, Mallocator) output;
	private Vector!(char, Mallocator) _indentation;
	TreePathVisitor default_visitor;
	alias default_visitor this;

	Vector!(Pos, Mallocator) position;
	SizeType size;


	Axis xaxis, old_xaxis, yaxis;

	void setAxis(SizeType x, SizeType y, SizeType w, SizeType h)
	{
		xaxis.position = x;
		yaxis.position = y;
		xaxis.size = w;
		yaxis.size = h;
	}

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
		loc.y.position = 0;

		final switch (this.orientation)
		{
			case Orientation.Vertical:
				setAxis(0, 0, size, model.header_size);
			break;
			case Orientation.Horizontal:
				setAxis(0, 0, model.size, size);
			break;
		}

	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		import auxil.traits : hasRenderHeader;

		old_xaxis = xaxis;

		final switch (model.orientation)
		{
			case Orientation.Vertical:
				yaxis.position = yaxis.position + model.header_size;
			break;
			case Orientation.Horizontal:
				yaxis.position = yaxis.position + model.header_size;
			break;
		}

		() @trusted {
			position ~= Pos(xaxis, yaxis);
		} ();

		final switch (model.orientation)
		{
			case Orientation.Vertical:
				processItem("Caption: ", Data.stringof);
				() @trusted {
					output ~= "\n";
					_indentation ~= "\t";
					xaxis.position = xaxis.position + model.header_size;
					xaxis.size = xaxis.size - model.header_size;
				} ();
			break;
			case Orientation.Horizontal:
			break;
		}
		orientation = model.orientation;
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		final switch (model.orientation)
		{
			case Orientation.Vertical:
				if (_indentation.length)
					_indentation.popBack;
				xaxis.position = xaxis.position - model.header_size;
				xaxis.size = xaxis.size + model.header_size;
			break;
			case Orientation.Horizontal:
				() @trusted {
					output ~= "\n";
				} ();
				xaxis.position = old_xaxis.position;
				xaxis.size = old_xaxis.size;
			break;
		}
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		final switch (orientation)
		{
			case Orientation.Vertical:
				yaxis.position = yaxis.position + model.size;
			break;
			case Orientation.Horizontal:
				xaxis.size = model.size;
			break;
		}
		() @trusted {
			position ~= Pos(xaxis, yaxis);
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
				xaxis.position = xaxis.position + model.size;
			break;
		}
	}
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
			Pos( 0, 10, 300, 10), 
				Pos(10, 20, 290, 10), 
					Pos(20, 30, 280, 10), 
					Pos(20, 40, 280, 10), 
					Pos(20, 50, 280, 10),
				Pos(10, 60, 290, 10), 
					Pos(20, 70, 280, 10), 
					Pos(20, 80, 280, 10), 
					Pos(20, 90, 280, 10),
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
			Pos( 0, 10, 300, 10), 
				Pos(10, 20, 290, 10), 
					Pos(10, 20, 96, 10), Pos(10+96, 20, 97, 10), Pos(10+96+97, 20, 290-96-97, 10),
				Pos(10, 30, 290, 10), 
					Pos(20, 40, 280, 10), 
					Pos(20, 50, 280, 10), 
					Pos(20, 60, 280, 10),
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
	visitor.loc.y.destination = visitor.loc.y.destination.max;
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
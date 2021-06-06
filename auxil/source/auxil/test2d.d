module auxil.test2d;

version(unittest) import unit_threaded : Name, should, be;

import auxil.model;
import auxil.default_visitor : TreePathVisitor, MeasuringVisitor;
import auxil.location : SizeType, Axis;

struct Pos
{
	@safe:
	Axis[2] axis;

	this(SizeType x, SizeType y, SizeType w, SizeType h)
	{
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
	}

	@property SizeType x() const { return axis[0].value; }
	@property SizeType w() const { return axis[0].size; }
	@property SizeType y() const { return axis[1].value; }
	@property SizeType h() const { return axis[1].size; }

	@property x(SizeType v) { axis[0].value = v; }
	@property w(SizeType v) { axis[0].size = v; }
	@property y(SizeType v) { axis[1].value = v; }
	@property h(SizeType v) { axis[1].size = v; }
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
	Pos pos, old_pos;
	SizeType size;

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
		loc.position = 0;

		final switch (this.orientation)
		{
			case Orientation.Vertical:
				pos = Pos(0, 0, size, model.header_size);
			break;
			case Orientation.Horizontal:
				pos = Pos(0, 0, model.size, size);
			break;
		}

	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		import auxil.traits : hasRenderHeader;

		old_pos = pos;

		final switch (model.orientation)
		{
			case Orientation.Vertical:
				pos.y = pos.y + model.header_size;
			break;
			case Orientation.Horizontal:
				pos.y = pos.y + model.header_size;
			break;
		}

		() @trusted {
			position ~= pos;
		} ();

		final switch (model.orientation)
		{
			case Orientation.Vertical:
				processItem("Caption: ", Data.stringof);
				() @trusted {
					output ~= "\n";
					_indentation ~= "\t";
					pos.x = pos.x + model.header_size;
					pos.w = pos.w - model.header_size;
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
				pos.x = pos.x - model.header_size;
				pos.w = pos.w + model.header_size;
			break;
			case Orientation.Horizontal:
				() @trusted {
					output ~= "\n";
				} ();
				pos.x = old_pos.x;
				pos.w = old_pos.w;
			break;
		}
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		final switch (orientation)
		{
			case Orientation.Vertical:
				pos.y = pos.y + model.size;
			break;
			case Orientation.Horizontal:
				pos.w = model.size;
			break;
		}
		() @trusted {
			position ~= pos;
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
				pos.x = pos.x + model.size;
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
	visitor.loc.destination = visitor.loc.destination.max;
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
	visitor.loc.destination = visitor.loc.destination.max;
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
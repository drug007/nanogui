module auxil.test2d;

version(unittest) import unit_threaded : Name, should, be;

import auxil.model;
import auxil.default_visitor : TreePathVisitor, MeasuringVisitor;
import auxil.location : SizeType;

struct Pos
{
	SizeType x, y, w, h;
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
	Orientation  orientation;

	Vector!(Pos, Mallocator) position;
	Pos pos, old_pos;

	this(float size) @nogc
	{
		default_visitor = TreePathVisitor();
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
		pos = Pos(0, 0, 300, 20);
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		import auxil.traits : hasRenderHeader;

		old_pos = pos;

		final switch (model.orientation)
		{
			case Orientation.Vertical:
				pos.y += model.header_size;
			break;
			case Orientation.Horizontal:
				pos.y += model.header_size;
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
					pos.x += 2*model.header_size;
					pos.w -= 2*model.header_size;
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
				pos.x -= 2*model.header_size;
				pos.w += 2*model.header_size;
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
				pos.y += model.size;
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
				pos.x += model.size;
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

	auto visitor = Visitor2D();
	auto model = makeModel(data);
	model.collapsed = false;
	model[0].collapsed = false;
	model[1].collapsed = false;
	{
		auto mv = MeasuringVisitor(9);
		model.visitForward(data, mv);
	}
	visitor.loc.destination = visitor.loc.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		visitor.position[].should.be == [
			Pos( 0, 10, 300, 20), 
				Pos(20, 20, 280, 20), 
					Pos(40, 30, 260, 20), 
					Pos(40, 40, 260, 20), 
					Pos(40, 50, 260, 20),
				Pos(20, 60, 280, 20), 
					Pos(40, 70, 260, 20), 
					Pos(40, 80, 260, 20), 
					Pos(40, 90, 260, 20),
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
	model[0].size = 280;
	{
		auto mv = MeasuringVisitor(9);
		model.visitForward(data, mv);

		with(model[0])
		{
			size.should.be == 280;
			header_size.should.be == 10;
			f.size.should.be == 93;
			i.size.should.be == 93;
			s.size.should.be == 94;
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
			Pos( 0, 10, 300, 20), 
				Pos(20, 20, 280, 20), 
					Pos(20, 20, 93, 20), Pos(20+1*93, 20, 93, 20), Pos(20+2*93, 20, 280-2*93, 20),
				Pos(20, 30, 280, 20), 
					Pos(40, 40, 260, 20), 
					Pos(40, 50, 260, 20), 
					Pos(40, 60, 260, 20),
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

module auxil.test2d;

version(unittest) import unit_threaded : Name;

import auxil.common : Order, SizeType;
import auxil.model;
import auxil.default_visitor;

struct TreePosition
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem : Vector;

	Vector!(int, Mallocator) path;
	SizeType x, y;

	@disable this();

	this(P)(P p, SizeType x, SizeType y)
		if (!is(P == void[]))
	{
		path = p;
		this.x = x;
		this.y = y;
	}

	/// Handy ctor for case this([], size)
	this(S)(void[] p, SizeType w, SizeType h)
	{
		this.x = x;
		this.y = y;
	}

	import std.range : isOutputRange;
	import std.format : FormatSpec;

	void toString(Writer) (ref Writer w, scope const ref FormatSpec!char fmt) const
		if (isOutputRange!(Writer, char))
	{
		import std.algorithm : copy;
		import std.conv : text;

		copy(typeof(this).stringof, w);
		w.put('(');
		copy(text(path[], ", ", x, ", ", y), w);
		w.put(')');
	}
}

struct RelativeMeasurer
{
	TreePathVisitor default_visitor;
	alias default_visitor this;

	TreePosition[] output;

	void indent()
	{
		if (orientation == orientation.Vertical)
			posX = posX + 15;
	}

	void unindent()
	{
		if (orientation == orientation.Vertical)
			posX = posX - 15;
	}

	void enterTree(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output = null;
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (order == Order.Sinking)
			output ~= TreePosition(tree_path.value, posX, posY);
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (order == Order.Bubbling)
			output ~= TreePosition(tree_path.value, posX, posY);
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output ~= TreePosition(tree_path.value, posX, posY);
	}
}

version(unittest) @Name("horizontal.TrivialAggregate")
@safe
unittest
{
	import unit_threaded : should, be;

	import auxil.common : Orientation;

	static struct TrivialStruct
	{
		int i = -1;
		float f = 10e6;
	}

	auto data = [TrivialStruct(), TrivialStruct(), TrivialStruct()];
	auto model = makeModel(data);

	model.collapsed = false;

	model.orientation.should.be == Orientation.Vertical;

	model[0].orientation = Orientation.Vertical;
	model[0].collapsed = false;

	model[1].orientation = Orientation.Horizontal;
	model[1].collapsed = false;

	model[2].orientation = Orientation.Vertical;
	model[2].collapsed = false;

	// measure size
	{
		auto mv = MeasuringVisitor(32, 9);
		model.traversalForward(data, mv);
	}

	model[0].header_size.should.be == 10;
	model[0].i.size.should.be == 10;
	model[0].f.size.should.be == 10;
	model[0].size.should.be == 30;

	model[1].header_size.should.be == 33;
	model[1].i.size.should.be == 33;
	model[1].f.size.should.be == 33;
	model[1].size.should.be == 99;

	model[2].header_size.should.be == 10;
	model[2].i.size.should.be == 10;
	model[2].f.size.should.be == 10;
	model[2].size.should.be == 30;

	model.header_size.should.be == 10;
	model.size.should.be == 80;

	() @trusted {
		auto rm = RelativeMeasurer();
		rm.clear;
		rm.posX = 0;
		rm.posY = 0;
		rm.destX = 1000;
		rm.destY = 1000;
		model.traversalForward(data, rm);

		int i;
		rm.output[i].path[].length.should.be == 0;
		rm.output[i].x.should.be == 0;
		rm.output[i].y.should.be == 0;
		i++;

		rm.output[i].path[].should.be == [0];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 10;
		i++;

		rm.output[i].path[].should.be == [0, 0];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 20;
		i++;

		rm.output[i].path[].should.be == [0, 1];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 30;
		i++;

		rm.output[i].path[].should.be == [1];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 40;
		i++;

		rm.output[i].path[].should.be == [1, 0];
		rm.output[i].x.should.be == 48;
		rm.output[i].y.should.be == 40;
		i++;

		rm.output[i].path[].should.be == [1, 1];
		rm.output[i].x.should.be == 81;
		rm.output[i].y.should.be == 40;
		i++;

		rm.output[i].path[].should.be == [2];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 50;
		i++;

		rm.output[i].path[].should.be == [2, 0];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 60;
		i++;

		rm.output[i].path[].should.be == [2, 1];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 70;
		i++;
	} ();
}

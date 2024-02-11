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

version(unittest) @Name("horizontal")
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

	auto data = TrivialStruct();
	auto model = makeModel(data);
	import std;
	writeln(model);
	model.collapsed = false;

	model.orientation.should.be == Orientation.Vertical;

	model.orientation = Orientation.Horizontal;
	model.collapsed = false;


	// measure size
	{
		auto mv = MeasuringVisitor(32, 9);
		model.traversalForward(data, mv);
	}

	model.headerSizeY.should.be == 33;
	model.i.size.should.be == 33;
	model.f.size.should.be == 33;
	model.size.should.be == 99;

	import std;
	writeln(model);
	auto visitor = RelativeMeasurer();
	visitor.posX = 0;
	visitor.posY = 0;
	model.traversalForward(data, visitor);
	import std;
	writeln(model);

	() @trusted
	{
		visitor.output[].each!writeln;
	} ();

	version(none) () @trusted
	{
		import core.stdc.stdio : printf;
		visitor.output[$-1] = 0;
		printf("---\n%s\n---\nlength: %ld\n",
			visitor.output[].ptr, visitor.output.length);
	} ();
}

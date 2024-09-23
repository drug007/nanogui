module auxil.test2d;

version(unittest) import unit_threaded : Name;

import auxil.common : Order, SizeType;
import auxil.model;
import auxil.default_visitor;

struct TreePosition
{
@safe:
@nogc:
	import std.experimental.allocator.mallocator : Mallocator;
	import automem : Vector;

	Vector!(int, Mallocator) path;
	SizeType x, y, w, h;

	this(SizeType x, SizeType y, SizeType w, SizeType h, int[] path) 
	{
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
		this.path = path;
	}

	@disable this();

	this(P)(P p, SizeType x, SizeType y, SizeType w, SizeType h)
		if (!is(P == void[]))
	{
		path = p;
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
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
	@safe:
	DefaultVisitor default_visitor;
	alias default_visitor this;

	TreePosition[] output;

	this(SizeType w, SizeType h)
	{
		default_visitor = DefaultVisitor(w, h);
	}

	void indent()
	{
		if (orientation == orientation.Vertical)
			default_visitor.indent(15);
	}

	void unindent()
	{
		if (orientation == orientation.Vertical)
			default_visitor.indent(-15);
	}

	void enterTree(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output = null;
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model) @trusted
	{
		static if (order == Order.Sinking)
			output ~= TreePosition(tree_path.value[], posX, posY, sizeX, sizeY);
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model) @trusted
	{
		static if (order == Order.Bubbling)
			output ~= TreePosition(tree_path.value[], posX, posY, sizeX, sizeY);
	}
}

void printLogToSvg(Log)(string filename, double scale, ref Log log) @trusted
{
	import printed.canvas : SVGDocument;
	import printed.canvas;

	import auxil.common : Orientation;

	auto svg = new SVGDocument (420, 297);
	const k = scale;
	with (svg)
	{
		lineWidth(k);
		foreach(e; log)
		{
			const x = k*e.x;
			const y = k*e.y;
			const w = k*e.w;
			const h = k*e.h;

			strokeStyle = brush("#00ff00");
			fillStyle = brush("#eee");
			fillRect(x*k, y*k, w*k, h*k);
			beginPath(x*k, y*k);
			lineTo((x+w)*k, y*k);
			lineTo((x+w)*k, (y+h)*k);
			lineTo(x*k, (y+h)*k);
			lineTo(x*k, y*k);
			closePath;
			fillAndStroke;
		}
	}

	static import std.file;
	std.file.write(filename ~ ".svg", svg.bytes);
}

version(unittest) @Name("vertical.TrivialAggregate")
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

	model[1].orientation = Orientation.Vertical;
	model[1].collapsed = false;

	model[2].orientation = Orientation.Vertical;
	model[2].collapsed = false;

	const spacing = 1;
	const width = 99;
	const height = 9;
	const sizeY = height + spacing;
	// measure size
	{
		auto mv = MeasuringVisitor(width, height);
		model.traversalForward(data, mv);
	}

	model[0].header_size.should.be == 10;
	model[0].i.size.should.be == 10;
	model[0].f.size.should.be == 10;
	model[0].size.should.be == 30;

	model[1].header_size.should.be == 10;
	model[1].i.size.should.be == 10;
	model[1].f.size.should.be == 10;
	model[1].size.should.be == 30;

	model[2].header_size.should.be == 10;
	model[2].i.size.should.be == 10;
	model[2].f.size.should.be == 10;
	model[2].size.should.be == 30;

	model.header_size.should.be == 10;
	model.size.should.be == 100;

	() @trusted {
		auto rm = RelativeMeasurer(width, height);
		rm.clear;
		rm.posX = 0;
		rm.posY = 0;
		rm.destX = 1000;
		rm.destY = 1000;
		model.traversalForward(data, rm);

		printLogToSvg("vertical.TrivialAggregate", 1.0, rm.output);

		int i;
		rm.output[i].path[].length.should.be == 0;
		rm.output[i].x.should.be == 0;
		rm.output[i].y.should.be == 0;
		rm.output[i].w.should.be == width;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [0];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 10;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [0, 0];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 20;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [0, 1];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 30;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [1];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 40;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [1, 0];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 50;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [1, 1];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 60;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [2];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 70;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [2, 0];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 80;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [2, 1];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 90;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;
	} ();
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

	auto data = TrivialStruct(1, 1);
	auto model = makeModel(data);

	model.collapsed = false;

	model.orientation = Orientation.Horizontal;

	const width = 100;
	const height = 9;
	const spacing = 1;
	const sizeX = width + spacing;

	// measure size
	{
		auto mv = MeasuringVisitor(width, height);
		model.traversalForward(data, mv);
	}

	model.header_size.should.be == sizeX;
	model.i.size.should.be == sizeX;
	model.f.size.should.be == sizeX;
	model.size.should.be == 3*sizeX;

	model.header_size.should.be == 101;
	model.size.should.be == 303;

	() @trusted {
		auto rm = RelativeMeasurer(width, height);
		rm.clear;
		rm.posX = 0;
		rm.posY = 0;
		rm.destX = 1000;
		rm.destY = 1000;
		enum spacing = 1;
		model.traversalForward(data, rm);

		printLogToSvg("horizontal.TrivialAggregate", 1, rm.output);

		int i;
		rm.output[i].path[].length.should.be == 0;
		rm.output[i].x.should.be == 0;
		rm.output[i].y.should.be == 0;
		rm.output[i].w.should.be == sizeX;
		rm.output[i].h.should.be == height;
		i++;

		rm.output[i].path[].should.be == [0];
		rm.output[i].x.should.be == sizeX;
		rm.output[i].y.should.be == 0;
		rm.output[i].w.should.be == sizeX;
		rm.output[i].h.should.be == height;
		i++;

		rm.output[i].path[].should.be == [1];
		rm.output[i].x.should.be == 2*sizeX;
		rm.output[i].y.should.be == 0;
		rm.output[i].w.should.be == sizeX;
		rm.output[i].h.should.be == height;

		rm.output.length.should.be == 3;
	} ();
}

version(unittest) @Name("horizontal.ArrayOfTrivialAggregates.1")
@safe
unittest
{
	import std.range : zip;

	import unit_threaded : should, be;

	import auxil.common : Orientation;

	static struct TrivialStruct
	{
		int i = -1;
		float f = 10e6;
	}

	auto data = [TrivialStruct(1, 1)];
	auto model = makeModel(data);

	model.collapsed = false;
	model.orientation = Orientation.Horizontal;

	model[0].collapsed = false;
	model[0].orientation = Orientation.Horizontal;

	const width = 100;
	const height = 9;
	const spacing = 1;
	const sizeX = width + spacing;

	// measure size
	{
		auto mv = MeasuringVisitor(width, height);
		model.traversalForward(data, mv);
	}

	model.header_size.should.be == sizeX;
	model.header_size.should.be == 101;
	model.size.should.be == 404;

	model[0].header_size.should.be == sizeX;
	model[0].i.size.should.be == sizeX;
	model[0].f.size.should.be == sizeX;
	model[0].size.should.be == 3*sizeX;

	{
		auto rm = RelativeMeasurer(width, height);
		rm.clear;
		rm.posX = 0;
		rm.posY = 0;
		rm.destX = 1000;
		rm.destY = 1000;
		model.traversalForward(data, rm);

		printLogToSvg("horizontal.ArrayOfTrivialAggregates.1", 1, rm.output);

		auto expectedData = [
			TreePosition(0*sizeX, 0, sizeX, height, []),
			TreePosition(1*sizeX, 0, sizeX, height, [0]),
			TreePosition(2*sizeX, 0, sizeX, height, [0, 0]),
			TreePosition(3*sizeX, 0, sizeX, height, [0, 1]),
		];

		rm.output.length.should.be == expectedData.length;

		foreach(ref given, expected; zip(rm.output, expectedData))
			given.should.be == expected;

	}
}

version(unittest) @Name("mixed.Aggregate")
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

	auto data = [TrivialStruct(1, 1), TrivialStruct(2, 2), TrivialStruct(3, 3)];
	auto model = makeModel(data);

	model.collapsed = false;

	model.orientation.should.be == Orientation.Vertical;

	model[0].orientation = Orientation.Vertical;
	model[0].collapsed = false;

	model[1].orientation = Orientation.Horizontal;
	model[1].collapsed = false;

	model[2].orientation = Orientation.Vertical;
	model[2].collapsed = false;

	const width = 100;
	const height = 9;
	const spacing = 1;
	const sizeX = width + spacing;
	const sizeY = height + spacing;

	// measure size
	{
		auto mv = MeasuringVisitor(width, height);
		model.traversalForward(data, mv);
	}

	model[0].header_size.should.be == sizeY;
	model[0].i.size.should.be == sizeY;
	model[0].f.size.should.be == sizeY;
	model[0].size.should.be == 3*sizeY;

	model[1].header_size.should.be == sizeX;
	model[1].i.size.should.be == sizeX;
	model[1].f.size.should.be == sizeX;
	model[1].size.should.be == 3*sizeX;

	model[2].header_size.should.be == sizeY;
	model[2].i.size.should.be == sizeY;
	model[2].f.size.should.be == sizeY;
	model[2].size.should.be == 3*sizeY;

	model.header_size.should.be == 10;
	model.size.should.be == 80;

	() @trusted {
		auto rm = RelativeMeasurer(width, height);
		rm.clear;
		rm.posX = 0;
		rm.posY = 0;
		rm.destX = 1000;
		rm.destY = 1000;
		model.traversalForward(data, rm);

		printLogToSvg("mixed.Aggregate", 1, rm.output);

		int i;
		rm.output[i].path[].length.should.be == 0;
		rm.output[i].x.should.be == 0;
		rm.output[i].y.should.be == 0;
		rm.output[i].w.should.be == width;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [0];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 10;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [0, 0];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 20;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [0, 1];
		rm.output[i].x.should.be == 30;
		rm.output[i].y.should.be == 30;
		rm.output[i].w.should.be == width - rm.output[i].x;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [1];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 40;
		rm.output[i].w.should.be == sizeX;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [1, 0];
		rm.output[i].x.should.be == 15;
		rm.output[i].y.should.be == 40;
		rm.output[i].w.should.be == sizeX;
		rm.output[i].h.should.be == sizeY;
		i++;

		rm.output[i].path[].should.be == [1, 1];
		rm.output[i].x.should.be == 15 + sizeX; // размер первого элемента плюс размер второго
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

module tests.test;

import dyaml;

import lixua.model2;

struct Pos
{
	double x, y;
}

struct Color
{
	ubyte r, g, b, a;
}

struct Circle
{
	Pos position;
	double radius;
	Color colour;
}

struct Square
{
	Pos lefttop, rightbottom;
	Color colour;
}

struct Shape
{
	Circle origin;
	Square destination;
}

string desc = "
shape:
    order: Reverse
    origin:
        position:
        radius:
        colour:
            order: Forward
    destination:
        lefttop:
        rightbottom:
        colour:
";

auto getOrder(const(Node) node, Order default_) @safe
{
	try
	{
		import std.conv : to;
		return node["order"].as!string.to!Order;
	}
	catch(YAMLException e)
	{
		return default_;
	}
}

struct Visitor
{
	import std.algorithm : joiner;
	import std.range : repeat;
	import std.stdio : File;
	import std.traits : isInstanceOf;

	size_t nesting_level;
	File output;
	Order currentOrder;
	Node root, currentRoot;

	@disable
	this();

	this(string filename)
	{
		output = File(filename, "a");
		root = Loader.fromString(desc).load();
		currentRoot = root;
	}

	auto visit(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
		if (isInstanceOf!(AggregateModel, Model))
	{
		static if (order == Order.Runtime)
		{
			currentRoot = currentRoot[model.Name];
			currentOrder = currentRoot.getOrder(currentOrder);
		}
		else
			currentOrder = order;

		output.writeln("	".repeat(nesting_level).joiner, Data.stringof, " ", model.Name, " ", order == Order.Runtime ? "Runtime: " : "", currentOrder);

		import lixua.traits2 : AggregateMembers;
		final switch(order)
		{
			case Order.Runtime:
			{
				if (currentOrder == Order.Forward || currentOrder == Order.Runtime)
					goto case Order.Forward;
				else if (currentOrder == Order.Reverse)
					goto case Order.Reverse;
				else
					assert(0);
			}
			case Order.Forward:
			{
				static foreach(member; AggregateMembers!Data)
				{{
					auto oldCurrentRoot = currentRoot;
					auto oldCurrentOrder = currentOrder;
					nesting_level++;
					scope(exit)
					{
						currentOrder = oldCurrentOrder;
						currentRoot = oldCurrentRoot;
						nesting_level--;
					}
					mixin("model."~member).visit!order(mixin("data."~member), this);
				}}
				return true;
			}
			case Order.Reverse:
			{
				import std.meta : Reverse;
				static foreach(member; Reverse!(AggregateMembers!Data))
				{{
					auto oldCurrentRoot = currentRoot;
					auto oldCurrentOrder = currentOrder;
					nesting_level++;
					scope(exit)
					{
						currentOrder = oldCurrentOrder;
						currentRoot = oldCurrentRoot;
						nesting_level--;
					}
					mixin("model."~member).visit!order(mixin("data."~member), this);
				}}
				return true;
			}
		}
	}

	auto visit(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
		if (isInstanceOf!(ScalarModel, Model))
	{
		output.writeln("	".repeat(nesting_level).joiner, Data.stringof, " ", model.Name, " ", data);

		return true;
	}
}

void main()
{
	auto c = Circle();
	auto s = Square();
	auto shape = Shape(c, s);
	auto shapeModel = Model!shape(shape);

	import std.stdio : writeln;
	writeln("size of data: ", shape.sizeof);
	writeln("size of model: ", shapeModel.sizeof);

	static immutable logName = "log.log";
	{
		import std.stdio : File;
		File(logName, "w");
	}
	{
		auto visitor = Visitor(logName);
		shapeModel.visit!(Order.Forward)(shape, visitor);
	}
	{
		auto visitor = Visitor("log.log");
		shapeModel.visit!(Order.Reverse)(shape, visitor);
	}
	{
		auto visitor = Visitor("log.log");
		shapeModel.visit!(Order.Runtime)(shape, visitor);
	}

	import std.algorithm : splitter;
	import std.file : readText;
	import std.path : buildPath;

	const f = readText(logName);
	const etalon = readText(buildPath("testdata", "etalon.log"));

	import std.algorithm : equal;
	import std.string : lineSplitter;
	assert(f.lineSplitter.equal(etalon.lineSplitter));
}
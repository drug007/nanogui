module tests.test;

import dyaml;

import lixua.model2;

struct PodStructure
{
	byte _byte;
	short _short;
	int _int;
	long _long;
	ubyte _ubyte;
	ushort _ushort;
	uint _uint;
	ulong _ulong;
}

struct Foo
{
	int i = -100;
	float f = 3;
	double d = 16;
	private string str;
	Bar b;
}

struct Bar
{
	int i;
	float f;
	PodStructure ps;
}

string desc = "
foo:
    order: reverse
    ps:
        bar:
            order: runtime
";

struct Visitor
{
	import std.algorithm : joiner;
	import std.range : repeat;
	import std.stdio : File;
	import std.traits : isInstanceOf;

	size_t nesting_level;
	File output;
	Order currentOrder;

	@disable
	this();

	this(string filename)
	{
		output = File(filename, "a");
	}

	auto visit(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
		if (isInstanceOf!(AggregateModel, Model))
	{
		currentOrder = order;
		output.writeln("	".repeat(nesting_level).joiner, Data.stringof, " ", model.Name, " ", currentOrder);

		import lixua.traits2 : AggregateMembers;
		static if (order == Order.Forward)
		{
			static foreach(member; AggregateMembers!Data)
			{{
				nesting_level++;
				scope(exit) nesting_level--;
				mixin("model."~member).visit!order(mixin("data."~member), this);
			}}
		}
		else static if (order == Order.Reverse)
		{
			import std.meta : Reverse;
			static foreach(member; Reverse!(AggregateMembers!Data))
			{{
				nesting_level++;
				scope(exit) nesting_level--;
				mixin("model."~member).visit!order(mixin("data."~member), this);
			}}
		}
		else
			static assert(0, "Unsupported");

		return true;
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
	auto bar = Bar(-1, -2, PodStructure(
		byte.min, 
		short.min, 
		int.min, 
		long.min, 
		ubyte.max, 
		ushort.max,
		uint.max,
		ulong.max,
	));
	auto foo = Foo(99, -3, 11, "str", bar);
	auto fooModel = Model!foo(foo);

	import std.stdio : writeln;
	writeln("size of data: ", foo.sizeof);
	writeln("size of model: ", fooModel.sizeof);

	static immutable logName = "log.log";
	{
		import std.stdio : File;
		File(logName, "w");
	}
	{
		auto visitor = Visitor(logName);
		fooModel.visit!(Order.Forward)(foo, visitor);
	}
	{
		auto visitor = Visitor("log.log");
		fooModel.visit!(Order.Reverse)(foo, visitor);
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
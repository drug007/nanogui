module tests.test;

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
	PodStructure ps;
}

struct Visitor
{
	import std.algorithm : joiner;
	import std.range : repeat;
	import std.stdio : File;
	import std.traits : isInstanceOf;

	size_t nesting_level;
	File output;

	@disable
	this();

	this(string filename)
	{
		output = File(filename, "w");
	}

	auto visit(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
		if (isInstanceOf!(AggregateModel, Model))
	{
		output.writeln("	".repeat(nesting_level).joiner, Data.stringof, " ", model.Name);

		import lixua.traits2 : AggregateMembers;
		static foreach(member; AggregateMembers!Data)
		{{
			nesting_level++;
			scope(exit) nesting_level--;
			mixin("model."~member).visit!order(mixin("data."~member), this);
		}}

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
	auto foo = Foo(99, -3, 11, "str", PodStructure(
		byte.min, 
		short.min, 
		int.min, 
		long.min, 
		ubyte.max, 
		ushort.max,
		uint.max,
		ulong.max,
	));
	auto fooModel = Model!foo(foo);

	import std.stdio : writeln;
	writeln("size of data: ", foo.sizeof);
	writeln("size of model: ", fooModel.sizeof);

	{
		auto visitor = Visitor("log.log");
		fooModel.visit!(Order.Forward)(foo, visitor);
	}

	import std.algorithm : splitter;
	import std.file : readText;
	import std.path : buildPath;

	const f = readText("log.log");
	const etalon = readText(buildPath("testdata", "etalon.log"));

	import std.algorithm : equal;
	import std.string : lineSplitter;
	assert(f.lineSplitter.equal(etalon.lineSplitter));
}
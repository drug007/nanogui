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
		import std.stdio;
		import std.algorithm : joiner;
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
		import std.algorithm : joiner;
		import std.stdio;
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

	import std.file : readText;
	import std.algorithm : splitter;
	auto f = readText("log.log");

	const etalon = 
"Foo foo
	int i 99
	float f -3
	double d 11
	PodStructure ps
		byte _byte -128
		short _short -32768
		int _int -2147483648
		long _long -9223372036854775808
		ubyte _ubyte 255
		ushort _ushort 65535
		uint _uint 4294967295
		ulong _ulong 18446744073709551615
";
	import std.algorithm : equal;
	import std.string : lineSplitter;
	assert(f.lineSplitter.equal(etalon.lineSplitter));
}
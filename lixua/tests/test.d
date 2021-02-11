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

	auto visit(Order order, string name, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		return visit!(name, Data)(data, model);
	}

	auto visit(string name, Data, Model)(auto ref const(Data) data, ref Model model)
		if (isInstanceOf!(AggregateModel, Model))
	{
		import std.stdio;
		import std.algorithm : joiner;
		output.writeln("	".repeat(nesting_level).joiner, name);

		import lixua.traits2 : AggregateMembers;
		static foreach(member; AggregateMembers!Data)
		{{
			nesting_level++;
			scope(exit) nesting_level--;
			mixin("model."~member).visit!member(mixin("data."~member), this);
		}}

		return true;
	}

	auto visit(string name, Data, Model)(auto ref const(Data) data, ref Model model)
		if (isInstanceOf!(ScalarModel, Model))
	{
		import std.algorithm : joiner;
		import std.stdio;
		output.writeln("	".repeat(nesting_level).joiner, Data.stringof, " ", name, " ", data);

		return true;
	}
}

void main()
{

	auto foo = Foo(99, -3, 11);
	auto fooModel = makeModel(foo);
	import std.stdio;
	writeln(foo);
	writeln(fooModel);
	foo.i.writeln;
	writeln(1);
	// fooModel.i.writeln;

	writeln("===");
	writeln("size of data: ", foo.sizeof);
	writeln("size of model: ", fooModel.sizeof);

	{
		auto visitor = Visitor("log.log");
		fooModel.visit!(Order.Forward, "foo")(foo, visitor);
	}

	import std.file : readText;
	import std.algorithm : splitter;
	auto f = readText("log.log");

	const etalon = 
"foo
	int i 99
	float f -3
	double d 11
";
	import std.algorithm : equal;
	import std.string : lineSplitter;
	assert(f.lineSplitter.equal(etalon.lineSplitter));
}
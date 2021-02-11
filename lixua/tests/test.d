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
	import std.traits : isInstanceOf;

	auto visit(Order order, Data, Model)(auto ref Data data, ref Model model)
	{
		return visit!Data(data, model);
	}

	auto visit(Data, Model)(auto ref Data data, ref Model model)
		if (isInstanceOf!(AggregateModel, Model))
	{
		import lixua.traits2 : AggregateMembers;
		static foreach(member; AggregateMembers!Data)
		{
			mixin("model."~member).visit(mixin("data."~member), this);
		}

		return true;
	}

	auto visit(Data, Model)(auto ref Data data, ref Model model)
		if (isInstanceOf!(ScalarModel, Model))
	{
		import std.stdio;
		writeln(Data.stringof);
		writeln(data);
		writeln;

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

	Visitor visitor;
	fooModel.visit!(Order.Forward)(foo, visitor);
}
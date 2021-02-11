module tests.test;

void main()
{
	import lixua.model;

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

	auto foo = Foo(99, -3, 11);
	auto fooModel = makeModel(foo);
	import std;
	writeln(foo);
	writeln(fooModel);
	foo.i.writeln;
	writeln(1);
	// fooModel.i.writeln;
}
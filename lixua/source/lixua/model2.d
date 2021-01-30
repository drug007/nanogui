module lixua.model2;

unittest
{
	struct Foo
	{
		int i = -100;
		float f = 3;
		double d = 16;
		private string str;
	}

	auto foo = Foo(99, -3, 11);
	import lixua.model : makeModel;
	auto fooModel = makeModel(foo);
	import std;
	writeln(foo);
	writeln(fooModel);
	foo.i.writeln;
	fooModel.i.writeln;

	// проверка 
}
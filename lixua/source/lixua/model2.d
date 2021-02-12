module lixua.model2;

import std.format : format;

import lixua.traits2 : UnqualTypeOf;

private enum dataHasAggregateModel(T) = 
	(is(T == struct) || is(T == union) || is(T == class));
private enum dataHasScalarModel(T) = (
	is(T == float)  ||
	is(T == double) ||
	is(T == byte)   ||
	is(T == ubyte)  ||
	is(T == short)  ||
	is(T == ushort) ||
	is(T == int)    ||
	is(T == uint)   ||
	is(T == long)   ||
	is(T == ulong)
);

enum Order { Forward, Reverse, Runtime, }

template Model(alias A)
{
	static if (dataHasAggregateModel!(UnqualTypeOf!A))
		alias Model = AggregateModel!A;
	else static if (dataHasScalarModel!(UnqualTypeOf!A))
		alias Model = ScalarModel!A;
	else
		static assert(0, A.stringof ~ " has type `" ~ UnqualTypeOf!A.stringof ~ "` and has no appropriate model");
}

template AggregateModel(alias A)
	if (dataHasAggregateModel!(UnqualTypeOf!A))
{
	struct AggregateModel
	{
		alias Data = UnqualTypeOf!A;
		static immutable string Name = A.stringof;

		import lixua.traits2 : AggregateMembers;
		static foreach(member; AggregateMembers!Data)
			mixin("Model!(Data.%1$s) %1$s;".format(member));

		this()(auto ref const(Data) data)
		{
		}

		bool visit(Order order, Visitor)(ref const(Data) data, ref Visitor visitor)
		{
			return visitor.visit!order(data, this);
		}
	}
}

struct ScalarModel(alias A)
	if (dataHasScalarModel!(UnqualTypeOf!A))
{
	alias Data = UnqualTypeOf!A;
	static immutable string Name = A.stringof;

	this()(auto ref const(Data) data)
	{
	}

	bool visit(Order order, Visitor)(ref const(Data) data, ref Visitor visitor)
	{
		return visitor.visit!order(data, this);
	}
}

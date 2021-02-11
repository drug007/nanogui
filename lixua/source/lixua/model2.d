module lixua.model2;

import lixua.traits : UnqualTypeOf = TypeOf;

private enum dataHasAggregateModel(T) = 
	(is(T == struct) || is(T == union) || is(T == class));
private enum dataHasScalarModel(T) = (
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
	else
		alias Model = ScalarModel!A;
}

template AggregateModel(alias A)
	if (dataHasAggregateModel!(UnqualTypeOf!A))
{
	struct AggregateModel
	{
		alias Data = UnqualTypeOf!A;

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

	this()(auto ref const(Data) data)
	{
	}

	bool visit(Visitor)(ref const(Data) data, ref Visitor visitor)
	{
		return visitor.visit(data, this);
	}
}

auto makeModel(T)(auto ref const(T) data)
{
	return Model!T(data);
}

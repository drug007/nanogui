module auxil.treepath;

struct TreePath
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem.vector : Vector;

@safe:

	Vector!(int, Mallocator) value;

	@disable this(this);

	this(ref return scope TreePath rhs) nothrow @trusted
	{
		value = rhs.value[];
	}

	this(ref return scope const(TreePath) rhs) nothrow @trusted const
	{
		value = rhs.value[];
	}

	this(ref return scope inout(TreePath) rhs) nothrow @trusted inout
	{
		// // value = typeof(this)(rhs.value[]);
		// size_t l = rhs.value.length();
		// (cast(const)value).length = l;
		auto dummy = Vector!(int, Mallocator)(cast(int[])rhs.value[]);
		value = cast(inout) dummy;
	}

	ref int back() return @nogc
	{
		assert(value.length);
		return value[$-1];
	}

	void popBack() @nogc
	{
		value.popBack;
	}

	void clear() @nogc
	{
		value.clear;
	}

	auto put(int i) @nogc @trusted
	{
		value.put(i);
	}

	import std.range : isOutputRange;
	import std.format : FormatSpec;

	void toString(Writer) (ref Writer w, scope const ref FormatSpec!char fmt) const  @trusted
		if (isOutputRange!(Writer, char))
	{
		import std;
		import std.conv : text;

		w.put('[');
		if (value.length)
		{
			foreach(e; value[0..$-1])
				copy(text(e, "."), w);
			copy(text(value[$-1]), w);
		}
		w.put(']');
	}
}
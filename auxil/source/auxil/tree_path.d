module auxil.tree_path;

struct TreePath
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem.vector : Vector;

@safe:

	Vector!(int, Mallocator)  value;

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

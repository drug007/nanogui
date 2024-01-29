module auxil.fixedappender;

struct FixedAppender(size_t Size)
{
	void put(char c) pure
	{
		import std.exception : enforce;

		enforce(size < Size);
		buffer[size++] = c;
	}

	void put(scope const(char)[] s) pure
	{
		import std.exception : enforce;

		enforce(size + s.length <= Size);
		foreach(c; s)
			buffer[size++] = c;
	}

	@property size_t length() const @safe nothrow @nogc pure
	{
		return size;
	}

	string opSlice() return scope pure nothrow @property
	{
		import std.exception : assumeUnique;
		assert(size <= Size);
		return buffer[0..size].assumeUnique;
	}

	void clear() @safe nothrow @nogc pure
	{
		size = 0;
	}

private:
	char[Size] buffer;
	size_t size;
}

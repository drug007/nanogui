module lixua.traits2;

private template isSymbol(A...)
{
	static if (A.length == 1)
		enum isSymbol = .isSymbol!A;
	else
		enum isSymbol = false;
}
private template isSymbol(alias A)
{
	static if (__traits(compiles, { enum id = __traits(identifier, A); }))
		enum isSymbol = __traits(identifier, A) != "A";
	else
		enum isSymbol = false;
}

template AggregateMembers(alias A)
{
	import std.meta : ApplyLeft, Filter, AliasSeq;
	import std.traits : isType, Unqual;

	alias Type = UnqualTypeOf!A;

	Type symbol;

	alias AllMembers = AliasSeq!(__traits(allMembers, Type));
	alias isProper = ApplyLeft!(isNotIgnored, symbol);
	alias AggregateMembers = Filter!(isProper, AllMembers);
}

package template isNotIgnored(alias value, string member)
{
	import std.algorithm : among;
	import std.meta : AliasSeq, Filter;
	import std.traits : isSomeFunction, isType, Unqual;

	alias T = UnqualTypeOf!value;

	static if (member.among("__ctor", "__dtor", "this", "~this"))
		enum isNotIgnored = false;
	else static if (isSymbol!(__traits(getMember, T, member)))
	{
		// check if the symbol has `ignored` attribute assigned
		static if (Filter!(isIgnored, AliasSeq!(__traits(getAttributes, __traits(getMember, T, member)))).length)
			enum isNotIgnored = false;
		else
			enum isNotIgnored = isMemberProper!(value, member);
	}
	else
		enum isNotIgnored = isMemberProper!(value, member);
}

package template isMemberProper(alias value, string member)
{
	import std.algorithm : among;
	import std.traits : isSomeFunction, isType, Unqual;

	alias T = UnqualTypeOf!value;

	static if (isItSequence!value)
		enum isMemberProper = false;
	else static if (hasProtection!(value, member) && !isPublic!(value, member))
		enum isMemberProper = false;
	else static if (__traits(compiles, { auto v = mixin("T." ~ member); })) // static members
		enum isMemberProper = false;
	else static if (isItSequence!(__traits(getMember, value, member)))
		enum isMemberProper = false;
	else static if (isMemberStatic!(T, member))
		enum isMemberProper = false;
	else static if (isReadableAndWritable!(value, member) && !isSomeFunction!(__traits(getMember, T, member)))
		enum isMemberProper = !member.among("__ctor", "__dtor");
	else static if (isReadable!(value, member))
		enum isMemberProper = isProperty!(value, member); // a readable property is getter
	else
		enum isMemberProper = false;
}

private enum isIgnored(alias tested) = __traits(isSame, ignored, tested);
private template isItSequence(T...)
{
	static if (T.length < 2)
		enum isItSequence = false;
	else
		enum isItSequence = true;
}

private template hasProtection(alias aggregate, string member)
{
	enum hasProtection = __traits(compiles, { enum pl = __traits(getProtection, __traits(getMember, typeof(aggregate), member)); });
}

private enum isReadable(alias aggregate, string member) = __traits(compiles, { auto _val = __traits(getMember, aggregate, member); });
private enum isMemberStatic(T, string member) = __traits(compiles, { auto a = mixin("T." ~ member); });
// check if the member is readable/writeble?
private enum isReadableAndWritable(alias aggregate, string member) = __traits(compiles, __traits(getMember, aggregate, member) = __traits(getMember, aggregate, member));
private enum isPublic(alias aggregate, string member) = !__traits(getProtection, __traits(getMember, aggregate, member)).privateOrPackage;

private bool privateOrPackage()(string protection)
{
	return protection == "private" || protection == "package";
}

template UnqualTypeOf(alias A)
{
	import std.traits : isType, Unqual;

	static if (isType!A)
	{
		alias UnqualTypeOf = Unqual!A;
	}
	else
	{
		alias UnqualTypeOf = Unqual!(typeof(A));
	}
}

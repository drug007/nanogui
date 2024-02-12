module auxil.traits;

version(unittest) import unit_threaded : Name;

import std.traits : isTypeTuple;

template isNullable(T)
{
	import std.traits : isInstanceOf;
	import std.typecons : Nullable;

	enum isNullable = is(T == struct) && isInstanceOf!(Nullable, T);
}

template isTimemarked(T)
{
	version (HAVE_TIMEMARKED)
	{
		import std.traits : isInstanceOf;
		import rdp.timemarked : Timemarked;

		enum isTimemarked = is(T == struct) && isInstanceOf!(Timemarked, T);
	}
	else
		enum isTimemarked = false;
}

template hasRenderHeader(alias A)
{
	import auxil.fixedappender : FixedAppender;

	FixedAppender!32 app;

	static if (is(typeof(A.renderHeader(app))))
		enum hasRenderHeader = true;
	else
		enum hasRenderHeader = false;
}

private bool privateOrPackage()(string protection)
{
	return protection == "private" || protection == "package";
}

template TypeOf(alias A)
{
	import std.traits : isType, Unqual;

	static if (isType!A)
	{
		alias TypeOf = Unqual!A;
	}
	else
	{
		alias TypeOf = Unqual!(typeof(A));
	}
}

// check if the member is readable/writeble?
private enum isReadableAndWritable(alias aggregate, string member) = __traits(compiles, __traits(getMember, aggregate, member) = __traits(getMember, aggregate, member));
private enum isPublic(alias aggregate, string member) = !__traits(getProtection, __traits(getMember, aggregate, member)).privateOrPackage;

// check if the member is property with const qualifier
private template isConstProperty(alias aggregate, string member)
{
	import std.traits : isSomeFunction, hasFunctionAttributes;

	static if(isSomeFunction!(__traits(getMember, typeof(aggregate), member)))
		enum isConstProperty = hasFunctionAttributes!(__traits(getMember, aggregate, member), "const", "@property");
	else
		enum isConstProperty = false;
}

// check if the member is property
private template isProperty(alias aggregate, string member)
{
	import std.traits : isSomeFunction, functionAttributes, FunctionAttribute;

	static if(isSomeFunction!(__traits(getMember, typeof(aggregate), member)))
		enum isProperty = !!(functionAttributes!(__traits(getMember, typeof(aggregate), member)) & FunctionAttribute.property);
	else
		enum isProperty = false;
}

// check if the member is readable
private enum isReadable(alias aggregate, string member) = __traits(compiles, { auto _val = __traits(getMember, aggregate, member); });
private enum isMemberStatic(T, string member) = __traits(compiles, { auto a = mixin("T." ~ member); });

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

version(unittest) @Name("aggregates")
@safe
unittest
{
	import unit_threaded : should, be;

	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	static struct StructWithStruct
	{
		double d = 8.8;
		long l = 999;
		Test t;
	}

	static class TestClass
	{

	}

	static struct StructWithPointerAndClass
	{
		double* d;
		TestClass tc;
	}

	static struct StructWithNestedClass
	{
		TestClass tc;
	}

	assert( isProcessible!float);
	assert( isProcessible!(float*));
	assert( isProcessible!Test );
	assert( isProcessible!StructWithStruct);
	assert(!isProcessible!TestClass);
	assert(!isProcessible!StructWithPointerAndClass);
	assert(!isProcessible!StructWithNestedClass);
}

template isProcessible(alias A)
{
	import std.traits, std.range;

	static if (isType!A)
		alias T = Unqual!A;
	else
		alias T = Unqual!(typeof(A));

	static if (is(T == struct) || is(T == union))
	{
		static foreach(member; DrawableMembers!T)
		{
			static if (is(Unqual!(typeof(mixin("T." ~ member))) == T))
			{
				// If the member is a property and returns type T then
				// we skip this property to prevent endless recursion
			}
			else static if (!is(typeof(isProcessible) == bool) &&
				!isProcessible!(mixin("T." ~ member)))
			{
				enum isProcessible = false;
			}
		}

		static if (!is(typeof(isProcessible) == bool))
			enum isProcessible = true;
	}
	else static if (
	       isStaticArray!T
	    || isRandomAccessRange!T
	    || isAssociativeArray!T
	    || isSomeString!T
	    || isFloatingPoint!T
	    || isIntegral!T
	    || isSomeChar!T
	    || isPointer!T
	    || is(T == bool))
	{
		enum isProcessible = true;
	}
	else
		enum isProcessible = false;
}

private enum isIgnored(alias tested) = __traits(isSame, ignored, tested);

// This trait defines what members should be drawn -
// public members that are either readable and writable or getter properties
package template isMemberDrawable(alias value, string member)
{
	import std.algorithm : among;
	import std.traits : isSomeFunction, isType, Unqual;

	static if (isType!value)
		alias T = Unqual!value;
	else
		alias T = Unqual!(typeof(value));

	static if (isItSequence!value)
		enum isMemberDrawable = false;
	else static if (hasProtection!(value, member) && !isPublic!(value, member))
		enum isMemberDrawable = false;
	else static if (__traits(compiles, { auto v = mixin("T." ~ member); })) // static members
		enum isMemberDrawable = false;
	else static if (isItSequence!(__traits(getMember, value, member)))
		enum isMemberDrawable = false;
	else static if (isMemberStatic!(T, member))
		enum isMemberDrawable = false;
	else static if (isReadableAndWritable!(value, member) && !isSomeFunction!(__traits(getMember, T, member)))
		enum isMemberDrawable = !member.among("__ctor", "__dtor");
	else static if (isReadable!(value, member))
		enum isMemberDrawable = isProperty!(value, member); // a readable property is getter
	else
		enum isMemberDrawable = false;
}

template isMemberDrawableAndNotIgnored(alias value, string member)
{
	import std.algorithm : among;
	import std.meta : AliasSeq, Filter;
	import std.traits : isSomeFunction, isType, Unqual;

	static if (isType!value)
		alias T = Unqual!value;
	else
		alias T = Unqual!(typeof(value));

	static if (member.among("__ctor", "__dtor", "this", "~this"))
		enum isMemberDrawableAndNotIgnored = false;
	else static if (isSymbol!(__traits(getMember, T, member)))
	{
		// check if the symbol has `ignored` attribute assigned
		static if (Filter!(isIgnored, AliasSeq!(__traits(getAttributes, __traits(getMember, T, member)))).length)
			enum isMemberDrawableAndNotIgnored = false;
		else
			enum isMemberDrawableAndNotIgnored = isMemberDrawable!(value, member);
	}
	else
		enum isMemberDrawableAndNotIgnored = isMemberDrawable!(value, member);
}

/// returns alias sequence, members of which are members of value
/// that should be drawn
package template DrawableMembers(alias A)
{
	import std.meta : ApplyLeft, Filter, AliasSeq, EraseAll;
	import std.traits : isType, Unqual, isInstanceOf;

	import taggedalgebraic : TaggedAlgebraic;

	static if (isType!A)
	{
		alias Type = Unqual!A;
	}
	else
	{
		alias Type = Unqual!(typeof(A));
	}

	Type symbol;

	alias RawAllMembers = AliasSeq!(__traits(allMembers, Type));
	// Because TaggedAlgebraic has deprecated members to avoid compiler
	// warnings we filter deprecated members out
	static if (isInstanceOf!(TaggedAlgebraic, Type))
	{
		import std.algorithm : among;

		alias AllMembers = AliasSeq!();
		static foreach (m; RawAllMembers)
			static if (!m.among("typeID", "Union", "Type"))
				AllMembers = AliasSeq!(AllMembers, m);
	}
	else
		alias AllMembers = RawAllMembers;
	alias isProper = ApplyLeft!(isMemberDrawableAndNotIgnored, symbol);
	alias DrawableMembers = Filter!(isProper, AllMembers);
}

/*
Rendering proxy
*/
struct renderedAs(T){}
struct renderedAsPointee(string N)
{
	enum string name = N;
}
struct renderedAsMember(string N)
{
	enum string name = N;
}
struct ignored{}
private enum bool isRenderedAs(A) = is(A : renderedAs!T, T);
private enum bool isRenderedAs(alias a) = false;
package alias getRenderedAs(T : renderedAs!Proxy, Proxy) = Proxy;
package template getRenderedAs(alias value)
{
	private alias _list = ProxyList!value;
	static assert(_list.length == 1, `Only single rendering proxy is allowed`);
	alias getRenderedAs = _list[0];
}

private import std.traits : isInstanceOf;
private import std.meta : staticMap, Filter;

private alias ProxyList(alias value) = staticMap!(getRenderedAs, Filter!(isRenderedAs, __traits(getAttributes, value)));
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

package template hasRenderedAs(alias A)
{
	import std.traits : isBuiltinType, isType;
	static if (isSymbol!A)
	{
		private enum listLength = ProxyList!A.length;
		static assert(listLength <= 1, `Only single rendering proxy is allowed`);
		enum hasRenderedAs = listLength == 1;
	}
	else
		enum hasRenderedAs = false;
}

private template isRenderedAsMember(alias A) if (isSymbol!A)
{
	enum bool isRenderedAsMember = isInstanceOf!(renderedAsMember, TypeOf!A);
}

private template isRenderedAsMember(alias A) if (!isSymbol!A)
{
	enum bool isRenderedAsMember = false;
}

package template hasRenderedAsMember(T) if (!isSymbol!T)
{
	enum hasRenderedAsMember = false;
}

package template hasRenderedAsMember(T) if (isSymbol!T)
{
	import std.meta : Filter;

	alias attr = Filter!(isRenderedAsMember, __traits(getAttributes, T));
	static if (attr.length == 1)
		enum hasRenderedAsMember = true;
	else static if (attr.length == 0)
		enum hasRenderedAsMember = false;
	else
		static assert(0, "Only single renderedAsMember attribute is allowd");
}

package template getRenderedAsMember(T)
{
	alias Attributes = Filter!(isRenderedAsMember, __traits(getAttributes, T));
	enum string getRenderedAsMember = Attributes[0].name;
}

alias getRenderedAsMemberString(alias A) = getGivenAttributeAsString!(A, "renderedAsMember");
alias getRenderedAsPointeeString(alias A) = getGivenAttributeAsString!(A, "renderedAsPointee");

version(unittest) @Name("getRenderedAsMemberString")
unittest
{
	import std.meta : AliasSeq;

	static struct S0
	{
		int i;
		float f;
	}

	S0 s1;
	@("renderedAsMember.i")
	S0 s2;

	static assert ([getRenderedAsMemberString!S0] == []);
	static assert ([getRenderedAsMemberString!s1] == []);
	static assert ([getRenderedAsMemberString!s2] == ["i"]);

	static struct S2
	{
		S0 s;
	}

	static struct S3
	{
		@("renderedAsMember.s.f")
		S0 s;
	}

	static assert ([getRenderedAsMemberString!S2] == []);
	static assert ([getRenderedAsMemberString!(S3.s)] == ["s.f"]);
}

package template getGivenAttributeAsString(alias A, string GivenAttribute)
{
	import std.meta : staticMap, Filter, AliasSeq;

	enum isString(alias A) = is(TypeOf!A == string);
	enum L = GivenAttribute.length;
	enum isGivenAttribute(string s) = s.length > L && s[0..L] == GivenAttribute;
	enum dropPrefix(string s) = s[L+1..$];
	alias T = TypeOf!A;

	template impl(alias N)
	{
		alias AllString = Filter!(isString, __traits(getAttributes, N));
		alias AllAttrib = Filter!(isGivenAttribute, AllString);
		alias Attr = staticMap!(dropPrefix, AllAttrib);
		static assert(Attr.length < 2, "Only single " ~ GivenAttribute ~ " attribute is allowed");

		static if (Attr.length == 1)
			alias impl = Attr;
		else
			alias impl = AliasSeq!();
	}

	static if (isSymbol!A)
		alias getGivenAttributeAsString = impl!A;
	else static if (isSymbol!T)
		alias getGivenAttributeAsString = impl!T;
	else
		alias getGivenAttributeAsString = AliasSeq!();
}

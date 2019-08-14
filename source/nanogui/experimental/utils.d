module nanogui.experimental.utils;

import nanogui.common : NanoContext;

void drawItem(ref NanoContext ctx, float height, const(char)[] str)
{
	import nanogui.common : textAlign, text;
	ctx.textAlign(ctx.algn);
	ctx.text(ctx.position.x, ctx.position.y, str);
	ctx.position.y += cast(int) height;
}

struct DataItem(T)
{
	import std.traits : isAggregateType, isPointer, isArray, isSomeString, isAssociativeArray;
	import gfm.math : vec2i;
	import nanogui.common : Vector2i;

	enum textBufferSize = 1024;

	T content;
	private vec2i _size;

	this(string c, vec2i s)
	{
		content = c;
		_size = s;
	}

	auto draw(Context)(ref Context ctx, const(char)[] header, float height)
		if (!isAggregateType!T && 
			!isPointer!T &&
			(!isArray!T || isSomeString!T) &&
			!isAssociativeArray!T)
	{
		// import core.stdc.stdio : snprintf;
		import std.format : sformat;
		import std.traits : isIntegral, isFloatingPoint, isBoolean;

		char[textBufferSize] buffer;
		size_t l;
		if (header.length)
			l = sformat(buffer, "%s: ", header).length;

		// format specifier depends on type
		static if (is(T == enum))
		{
			const s = content.enumToString;
			l += sformat(buffer[l..$], min(buffer.length-l, s.length), "%s", s).length;
		}
		else static if (isIntegral!T)
			l += sformat(buffer[l..$], "%d", content).length;
		else static if (isFloatingPoint!T)
			l += sformat(buffer[l..$], "%f", content).length;
		else static if (isBoolean!T)
			l += sformat(buffer[l..$], content ? "true\0" : "false\0").length;
		else static if (isSomeString!T)
			l += sformat(buffer[l..$], "%s", content).length;
		else
			static assert(0, T.stringof);

		ctx.drawItem(height, buffer[0..l]);
	}

	// auto draw(Context)(Context ctx, const(char)[] header)
	// 	if (isAggregateType!T)// && !isInstanceOf!(TaggedAlgebraic, T) && !isNullable!T)
	// {
	// 	// static if (DrawnAsAvailable)
	// 	// {
	// 	// 	nk_layout_row_dynamic(ctx, itemHeight, 1);
	// 	// 	static if (Cached)
	// 	// 		state_drawn_as.draw(ctx, header, cached);
	// 	// 	else
	// 	// 		state_drawn_as.draw(ctx, "", t.drawnAs);
	// 	// }
	// 	// else
	// 	static if (DrawableMembers!t.length == 1)
	// 	{
	// 		static foreach(member; DrawableMembers!t)
	// 			mixin("state_" ~ member ~ ".draw(ctx, \"" ~ member ~"\", t." ~ member ~ ");");
	// 	}
	// 	else
	// 	{
	// 		import core.stdc.stdio : sprintf;
			
	// 		char[textBufferSize] buffer;
	// 		snprintf(buffer.ptr, buffer.length, "%s", header.ptr);

	// 		if (nk_tree_state_push(ctx, NK_TREE_NODE, buffer.ptr, &collapsed))
	// 		{
	// 			scope(exit)
	// 				nk_tree_pop(ctx);
				
	// 			static foreach(member; DrawableMembers!t) 
	// 			{
	// 				mixin("height += state_" ~ member ~ ".draw(ctx, \"" ~ member ~"\", t." ~ member ~ ");");
	// 			}
	// 		}
	// 	}
	// }

	auto visible() const nothrow @safe pure @nogc { return true; }
	auto performLayout(NVG)(NVG ctx) { };

	auto size() const nothrow @safe pure @nogc { return _size; }
	auto size(vec2i v) nothrow @safe pure @nogc { _size = v; }
}

mixin template DependencyProperty(T, alias string name)
{
	import std.string : capitalize;

	protected
	{
		mixin("T m" ~ name.capitalize ~ ";");
	}
	public 
	{
		import std.format : format;
		mixin (format(q{
			final T %1$s() const { return m%2$s; }
			final void %1$s(T value)
			{ 
				if (value == m%2$s) return;
				m%2$s = value;
				invalidate();
			}
		}, name, name.capitalize));
	}
}

// helpers

private string enumToString(E)(E e) @nogc @safe nothrow
	if (is(E == enum))
{
	import std.traits : Unqual;

	// using `if` instead of `final switch` is simple
	// workaround of duplicated enum members
	static foreach(v; __traits(allMembers, E))
		mixin("if (e == E." ~ v ~ ") return `" ~ v ~ "`;");
	return "Unrepresentable by " ~ Unqual!E.stringof ~ " value";
}

import std.traits : isTypeTuple;

private template isNullable(T)
{
	import std.traits : hasMember;

	static if (
		hasMember!(T, "isNull") &&
		is(typeof(__traits(getMember, T, "isNull")) == bool) &&
		(
			(hasMember!(T, "get") && !is(typeof(__traits(getMember, T, "get")) == void)) ||
			(hasMember!(T, "value") && !is(typeof(__traits(getMember, T, "value")) == void))
		) &&
		hasMember!(T, "nullify") &&
		is(typeof(__traits(getMember, T, "nullify")) == void)
	)
	{
		enum isNullable = true;
	}
	else
	{
		enum isNullable = false;
	}
}

private bool privateOrPackage()(string protection)
{
	return protection == "private" || protection == "package";
}

// check if the member is readable/writeble?
private enum isReadableAndWritable(alias aggregate, string member) = __traits(compiles, __traits(getMember, aggregate, member) = __traits(getMember, aggregate, member));
private enum isPublic(alias aggregate, string member) = !__traits(getProtection, __traits(getMember, aggregate, member)).privateOrPackage;

// check if the member is property with const qualifier
private template isConstProperty(alias aggregate, string member)
{
	import std.traits : isSomeFunction, hasFunctionAttributes;

	static if(isSomeFunction!(__traits(getMember, aggregate, member)))
		enum isConstProperty = hasFunctionAttributes!(__traits(getMember, aggregate, member), "const", "@property");
	else
		enum isConstProperty = false;
}

// check if the member is readable
private enum isReadable(alias aggregate, string member) = __traits(compiles, { auto _val = __traits(getMember, aggregate, member); });

private template isItSequence(T...)
{
	static if (T.length < 2)
		enum isItSequence = false;
	else
		enum isItSequence = true;
}

private template hasProtection(alias aggregate, string member)
{
	enum hasProtection = __traits(compiles, { enum pl = __traits(getProtection, __traits(getMember, aggregate, member)); });
}

// This trait defines what members should be drawn -
// public members that are either readable and writable or getter properties
private template Drawable(alias value, string member)
{
	import std.algorithm : among;
	import std.traits : isTypeTuple, isSomeFunction;

	static if (isItSequence!value)
		enum Drawable = false;
	else
	static if (hasProtection!(value, member) && !isPublic!(value, member))
			enum Drawable = false;
	else
	static if (isItSequence!(__traits(getMember, value, member)))
		enum Drawable = false;
	else
	static if(member.among("__ctor", "__dtor"))
		enum Drawable = false;
	else
	static if (isReadableAndWritable!(value, member) && !isSomeFunction!(__traits(getMember, value, member)))
		enum Drawable = true;
	else
	static if (isReadable!(value, member))
		enum Drawable = isConstProperty!(value, member); // a readable property is getter
	else
		enum Drawable = false;
}

/// returns alias sequence, members of which are members of value
/// that should be drawn
private template DrawableMembers(alias A)
{
	import std.meta : ApplyLeft, Filter, AliasSeq;
	import std.traits : isType, Unqual;

	static if (isType!A)
	{
		alias Type = Unqual!A;
	}
	else
	{
		alias Type = Unqual!(typeof(A));
	}

	Type symbol;

	alias AllMembers = AliasSeq!(__traits(allMembers, Type));
	alias isProper = ApplyLeft!(Drawable, symbol);
	alias DrawableMembers = Filter!(isProper, AllMembers);

}
module nanogui.experimental.utils;

import nanogui.common : NanoContext;
import nanogui.common : Vector2f, Vector2i;

public import auxil.sizeindex;
public import auxil.model;
public import auxil.traits;

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

void indent(ref NanoContext ctx)
{
	ctx.position.x += 20;
	ctx.size.x -= 20;
}

void unindent(ref NanoContext ctx)
{
	ctx.position.x -= 20;
	ctx.size.x += 20;
}

bool isPointInRect(Vector2f topleft, Vector2f size, Vector2f point)
{
	return point.x >= topleft.x && point.x < topleft.x+size.x &&
		point.y >= topleft.y && point.y < topleft.y+size.y;
}

bool isPointInRect(Vector2i topleft, Vector2i size, Vector2i point)
{
	return point.x >= topleft.x && point.x < topleft.x+size.x &&
		point.y >= topleft.y && point.y < topleft.y+size.y;
}

auto drawItem(T)(ref NanoContext ctx, T item)
{
	import std.traits : isSomeString;

	static if (isSomeString!T)
		return drawString(ctx, item);
	else
		return drawPodType(ctx, item);
}

private auto drawString(Char)(ref NanoContext ctx, const(Char)[] str)
{
	import nanogui.common : textAlign, text, roundedRect, fill, beginPath, linearGradient, fillPaint, fillColor;

	// it is possible if the item is placed out of visible area
	if (ctx.size[ctx.orientation] <= 0)
		return false;

	bool inside;
	if (isPointInRect(ctx.position, ctx.size, ctx.mouse))
	{
		const gradTop = ctx.theme.mButtonGradientTopFocused;
		const gradBot = ctx.theme.mButtonGradientBotFocused;

		ctx.beginPath;
		ctx.roundedRect(
			ctx.position.x, ctx.position.y,
			ctx.size.x, ctx.size.y,
			ctx.theme.mButtonCornerRadius - 1
		);

		const bg = ctx.linearGradient(
			ctx.position.x, ctx.position.y, 
			ctx.position.x, ctx.position.y + ctx.size.y,
			gradTop, gradBot
		);

		ctx.fillPaint(bg);
		ctx.fill;
		ctx.fillColor(ctx.theme.mTextColor);
		inside = true;
	}
	ctx.textAlign(ctx.algn);
	ctx.text(ctx.position.x, ctx.position.y, str);
	if (ctx.orientation == ctx.orientation.Vertical)
		ctx.position.y += ctx.size.y;
	else
		ctx.position.x += ctx.size.x;

	return inside;
}

private auto drawPodType(T)(ref NanoContext ctx, T item)
{
	import std.format : sformat;
	import std.traits : isIntegral, isFloatingPoint, isBoolean, isSomeString,
		isPointer, isSomeChar;

	enum textBufferSize = 512;
	char[textBufferSize] buffer;
	size_t l;

	// format specifier depends on type
	static if (is(T == enum))
	{
		const s = item.enumToString;
		l += sformat(buffer[l..$], "%s", s).length;
	}
	else static if (isIntegral!T)
		l += sformat(buffer[l..$], "%d", item).length;
	else static if (isFloatingPoint!T)
		l += sformat(buffer[l..$], "%f", item).length;
	else static if (isBoolean!T)
		l += sformat(buffer[l..$], item ? "true" : "false").length;
	else static if (isSomeString!T || isPointer!T)
		l += sformat(buffer[l..$], "%s", item).length;
	else static if (isSomeChar!T)
		l += sformat(buffer[l..$], "%s", item).length;
	else
		static assert(0, T.stringof);

	buffer[l < $ ? l : $-1] = '\0';

	return ctx.drawString(buffer[0..l]);
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

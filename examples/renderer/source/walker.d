module walker;

import common;

struct WidgetRange
{
	float x, delta, xend;

	invariant
	{
		import std.math, std.conv;

		assert(x >= 0, x.text);
		assert(xend.isNaN || xend >= 0);
		assert(!x.isNaN);
		assert(!delta.isNaN);
	}

	bool empty() const
	{
		return x >= xend;
	}

	auto front()
	{
		import std.typecons : tuple;
		return tuple(x, delta);
	}

	void popFront()
	{
		import std.math : isNaN;
		x += xend.isNaN ? 0 : delta;
	}
}

struct Walker
{
	WorkArea area;
	auto direction = Direction.row;
	auto alignment = Alignment.stretch;
	auto justification = Justification.around;

	WidgetRange[] xWidgetRange, yWidgetRange;

	auto wrapping = false;
	int nestingLevel;

	// for debug output in console
	string indentPrefix;
	// for debug rendering
	RenderState[] renderlog;

	import std.stdio;
	import traverse;

	auto render(Data, Dom)(Data data, Dom dom)
	{
		assert(dom);
		import std.math : isNaN;

		// defaulting
		if (area.margin.isNaN)
			area.margin = 0;
		if (area.padding.isNaN)
			area.padding = 0;

		traverseImpl!(leaf, nodeEnter, nodeLeave)(this, data, dom);
	}

	static auto leaf(Data, Dom)(ref typeof(this) ctx, Data data, Dom dom)
	{
		with(ctx)
		{
			writeln(indentPrefix, data);
			writeln(indentPrefix, ctx.area.w, "x", ctx.area.h);
			writeln(indentPrefix, dom.attributes.direction);
			if (!dom.attributes.direction.isNull)
				direction = dom.attributes.direction.get;
			if (!dom.attributes.margin.isNull)
				area.margin = dom.attributes.margin.get;
			if (!dom.attributes.padding.isNull)
				area.padding = dom.attributes.padding.get;

			renderlog ~= RenderState(dom.name, area, direction, 1, nestingLevel);
			auto a = area;
			a.x += area.margin;
			a.y += area.margin;
			a.w -= area.margin*2;
			a.h -= area.margin*2;
			renderlog ~= RenderState(dom.name, a, direction, 2, nestingLevel);
			a.x += area.padding;
			a.y += area.padding;
			a.w -= area.padding*2;
			a.h -= area.padding*2;
			renderlog ~= RenderState(dom.name, a, direction, 3, nestingLevel);
		}
	}

	static auto nodeEnter(Data, Dom)(ref typeof(this) ctx, Data data, Dom dom)
	{
		with(ctx)
		{
			writeln(indentPrefix, data);
			// writeln(indentPrefix, ctx.area.x, ", ", ctx.area.y, " ", ctx.area.w, "x", ctx.area.h);
			writeln(indentPrefix, ctx.area.margin);

			if (!dom.attributes.direction.isNull)
				direction = dom.attributes.direction.get;
			if (!dom.attributes.margin.isNull)
				area.margin = dom.attributes.margin.get;
			if (!dom.attributes.padding.isNull)
				area.padding = dom.attributes.padding.get;

			renderlog ~= RenderState(dom.name, area, direction, 1, nestingLevel);
			auto a = area;
			a.x += area.margin;
			a.y += area.margin;
			a.w -= area.margin*2;
			a.h -= area.margin*2;
			renderlog ~= RenderState(dom.name, a, direction, 2, nestingLevel);
			a.x += area.padding;
			a.y += area.padding;
			a.w -= area.padding*2;
			a.h -= area.padding*2;
			renderlog ~= RenderState(dom.name, a, direction, 3, nestingLevel);

			import std.math : isNaN;
			assert(!area.margin.isNaN);
			final switch (direction)
			{
				case Direction.row:
					xWidgetRange ~= WidgetRange(area.x + area.margin + area.padding, (area.w - 2*(area.margin + area.padding))/dom.child.length, area.x+area.w - 2*(area.margin + area.padding));
					yWidgetRange ~= WidgetRange(area.y + area.margin + area.padding, area.h - 2*(area.margin + area.padding), float.nan);
					break;
				case Direction.rowReverse:
					assert(0, "not implemented");
					// break;
				case Direction.column:
					xWidgetRange ~= WidgetRange(area.x + area.margin + area.padding, area.w - 2*(area.margin + area.padding), float.nan);
					yWidgetRange ~= WidgetRange(area.y + area.margin + area.padding, (area.h - 2*(area.margin + area.padding))/dom.child.length, area.y+area.h - 2*(area.margin + area.padding));
					break;
				case Direction.columnReverse:
					assert(0, "not implemented");
					// break;
			}

			indentPrefix ~= "\t";
		}
	}

	static auto nodeLeave(Data, Dom)(ref typeof(this) ctx, Data data, Dom dom)
	{
		ctx.indentPrefix = ctx.indentPrefix[0..$-1];
		ctx.xWidgetRange  = ctx.xWidgetRange [0..$-1];
		ctx.yWidgetRange  = ctx.yWidgetRange [0..$-1];
	}
}

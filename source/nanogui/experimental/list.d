///
module nanogui.experimental.list;

import std.algorithm : min, max;
import nanogui.widget;
import nanogui.common : MouseButton, Vector2f, Vector2i, NanoContext;
import nanogui.experimental.utils : DataItem;

private class IListImplementor
{
	import nanogui.layout : BoxLayout;

	abstract void     size(Vector2i v);
	abstract void     position(Vector2i v);
	abstract void     layout(BoxLayout l);
	abstract Vector2i preferredSize(NanoContext ctx) const;
	abstract void     performLayout(NanoContext ctx);
	abstract void     currentItemIndicesToHeight(ref float start, ref float finish);
	abstract void     draw(NanoContext ctx);
}

private class ListImplementor(T) : IListImplementor
{
	import std.range : isRandomAccessRange;
	import nanogui.layout : BoxLayout;

	private
	{
		DataItem!T[] _data;
		BoxLayout    _layout;
		Vector2i     _size;
		Vector2i     _pos;
		List         _parent;

		static int _last_id;
		int        _id;

		size_t _scroll_position;
		size_t _start_item;
		size_t _finish_item;
		size_t _shift;
	}

	@disable this();

	this(R)(List p, R data) if (isRandomAccessRange!R)
	{
		import std.exception : enforce;

		enforce(p);

		_id = ++_id;
		_parent = p;

		import std.array : array;
		_data = data.array;
		_scroll_position = _scroll_position.max-1;
	}

	override void size(Vector2i v)
	{
		_size = v;
	}

	override void position(Vector2i v)
	{
		_pos = v;
	}

	override void layout(BoxLayout l)
	{
		_layout = l;
	}

	/// Draw the widget (and all child widgets)
	override void draw(NanoContext ctx)
	{
		int fontSize = _parent.theme.mButtonFontSize;
		ctx.fontSize(fontSize);
		ctx.fontFace("sans-bold");

		ctx.save;

		int size_y = (_parent.fixedSize.y) ? _parent.fixedSize.y : _parent.size.y;
		assert(_size.y >= _parent.size.y);
		const scroll_position = cast(size_t) (_parent.mScroll * (_size.y - _parent.size.y));
		if (_scroll_position != scroll_position)
		{
			_shift = heightToItemIndex(_data, scroll_position, size_y, _layout.spacing, _start_item, _finish_item, _shift);
			_scroll_position = scroll_position;
		}

		ctx.theme = _parent.theme;
		ctx.current_size = _parent.size.x;
		ctx.position.x = _pos.x;
		ctx.position.y = cast(int) _shift + _pos.y;

		ctx.mouse -= _parent.absolutePosition;
		scope(exit) ctx.mouse += _parent.absolutePosition;

		import std.algorithm : min;
		foreach(child; _data[_start_item..min(_finish_item, $)])
		{
			ctx.save;
			scope(exit) ctx.restore;

			import std.conv : text;
			child.draw(ctx, text(child.size.y), child.size.y);
			ctx.position.y += cast(int) _layout.spacing;
		}
		ctx.restore;
	}

	/// Convert given range of items indices to to corresponding List height range
	private auto itemIndexToHeight(size_t start_index, size_t last_index, ref float start, ref float finish)
	{
		import nanogui.layout : BoxLayout;
		double curr = 0;
		double spacing = _layout.spacing;
		size_t idx;
		assert(start_index < last_index);
		start = 0;
		finish = 0;

		foreach(ref const e; _data)
		{
			if (idx >= start_index)
			{
				start = curr;
				idx++;
				curr += e.size.y + spacing;
				break;
			}
			idx++;
			curr += e.size.y + spacing;
		}

		if (start_index >= _data.length)
		{
			finish = start;
			return;
		}

		const low_boundary = ++idx;
		foreach(ref const e; _data[low_boundary..$])
		{
			if (idx >= last_index)
			{
				finish = curr;
				break;
			}
			idx++;
			curr += e.size.y + spacing;
		}

		if (last_index >= _data.length)
			finish = curr + spacing;
	}

	override void currentItemIndicesToHeight(ref float start, ref float finish)
	{
		return itemIndexToHeight(_start_item, _finish_item, start, finish);
	}

	/// Compute the preferred size of the widget
	override Vector2i preferredSize(NanoContext ctx) const
	{
		static Vector2i[int] size_inited;

		if (_id !in size_inited)
			size_inited[_id] = Vector2i();
		else if (size_inited[_id] != Vector2i())
			return size_inited[_id];

		import nanogui.layout : BoxLayout, Orientation, axisIndex, nextAxisIndex;

		Vector2i size;
		int yOffset = 0;

		uint visible_widget_count;
		int axis1 = _layout.orientation.axisIndex;
		int axis2 = _layout.orientation.nextAxisIndex;
		foreach(ref dataitem; _data)
		{
			if (!dataitem.visible) 
				continue;
			visible_widget_count++;
			// accumulate the primary axis size
			size[axis1] += dataitem.size[axis1];
			// the secondary axis size is equal to the max size of dataitems
			size[axis2] = max(size[axis2], dataitem.size[axis2]);
		}
		if (visible_widget_count > 1)
			size[axis1] += (visible_widget_count - 1) * _layout.spacing;
		size_inited[_id] = size;
		return size + Vector2i(0, yOffset);
	}

	/// Invoke the associated layout generator to properly place child widgets, if any
	override void performLayout(NanoContext ctx)
	{
		_scroll_position++; // little hack to force updating item indices
		foreach(ref dataitem; _data)
		{
			if (!dataitem.visible)
				continue;

			dataitem.performLayout(ctx);
		}
	}

	/// Handle a mouse button event (default implementation: propagate to children)
	bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
	{
		// foreach_reverse(ch; mChildren)
		// {
		// 	Widget child = ch;
		// 	if (child.visible && child.contains(p - mPos) &&
		// 		child.mouseButtonEvent(p - mPos, button, down, modifiers))
		// 		return true;
		// }
		// if (button == MouseButton.Left && down && !mFocused)
		// 	requestFocus();
		return false;
	}
}

class List : Widget
{
	import std.range : isRandomAccessRange, ElementType;
public:

	this(R)(Widget parent, R range) if (isRandomAccessRange!R)
	{
		super(parent);
		mChildPreferredHeight = 0;
		mScroll = 0.0f;
		mUpdateLayout = false;

		alias T = ElementType!R;
		DataItem!T[] data;
		data.reserve(range.length);
		foreach(e; range)
		{
			import std.random : uniform;
			data ~= DataItem!T(e, Vector2i(80, 30 + uniform(0, 30)));
		}

		list_implementor = new ListImplementor!string(this, data);
		list_implementor.size = Vector2i(width, height);

		import nanogui.layout : BoxLayout, Orientation;
		auto layout = new BoxLayout(Orientation.Vertical);
		layout.margin = 40;
		layout.setSpacing = 20;
		list_implementor.layout = layout;
	}

	/// Return the current scroll amount as a value between 0 and 1. 0 means scrolled to the top and 1 to the bottom.
	float scroll() const { return mScroll; }
	/// Set the scroll amount to a value between 0 and 1. 0 means scrolled to the top and 1 to the bottom.
	void setScroll(float scroll) { mScroll = scroll; }

	override void performLayout(NanoContext ctx)
	{
		super.performLayout(ctx);

		if (list_implementor is null)
			return;

		const list_implementor_preferred_size = list_implementor.preferredSize(ctx);
		mSize.y = parent.size.y - 2*parent.layout.margin;
		if (mSize.y < 0)
			mSize.y = 0;

		mChildPreferredHeight = list_implementor.preferredSize(ctx).y;

		if (mChildPreferredHeight > mSize.y)
		{
			auto y = cast(int) (-mScroll*(mChildPreferredHeight - mSize.y));
			list_implementor.position = Vector2i(0, y);
			list_implementor.size = Vector2i(mSize.x-12, mChildPreferredHeight);
		}
		else 
		{
			list_implementor.position = Vector2i(0, 0);
			list_implementor.size = mSize;
			mScroll = 0;
		}
		list_implementor.performLayout(ctx);
	}

	override Vector2i preferredSize(NanoContext ctx) const
	{
		// always return 0 because the size is defined by the parent container
		return Vector2i(0, 0);
	}
	
	override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
	{
		if (list_implementor !is null && mChildPreferredHeight > mSize.y)
		{
			float scrollh = height * min(1.0f, height / cast(float)mChildPreferredHeight);

			mScroll = max(cast(float) 0.0f, min(cast(float) 1.0f,
						mScroll + rel.y / cast(float)(mSize.y - 8 - scrollh)));
			mUpdateLayout = true;
			return true;
		}
		else
		{
			return super.mouseDragEvent(p, rel, button, modifiers);
		}
	}

	override bool scrollEvent(Vector2i p, Vector2f rel)
	{
		if (list_implementor !is null && mChildPreferredHeight > mSize.y)
		{
			const scrollAmount = rel.y * 10;
			mScroll = max(0.0f, min(1.0f, mScroll - scrollAmount/cast(typeof(mScroll))mChildPreferredHeight));
			mUpdateLayout = true;
			return true;
		}
		else
		{
			return super.scrollEvent(p, rel);
		}
	}

	/// Handle a mouse button event (default implementation: propagate to children)
	override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
	{
		const r = super.mouseButtonEvent(p, button, down, modifiers);
		if (p.x < mPos.x + mSize.x - 12)
			return r;

		if (!down)
			return false;

		const l = mScroll * height;
		if (list_implementor !is null && mChildPreferredHeight > mSize.y)
		{
			float s, f;
			list_implementor.currentItemIndicesToHeight(s, f);
			const scrollAmount = l > p.y ? (f - s) : -(f - s);

			mScroll = max(0.0f, min(1.0f, mScroll - scrollAmount/2/cast(float)mChildPreferredHeight));
			mUpdateLayout = true;
			return true;
		}
		return false;
	}

	override void draw(NanoContext ctx)
	{
		if (list_implementor is null)
			return;
		auto y = cast(int) (-mScroll*(mChildPreferredHeight - mSize.y));
		list_implementor.position = Vector2i(0, y);
		mChildPreferredHeight = list_implementor.preferredSize(ctx).y;
		float scrollh = max(16, height *
			min(1.0f, height / cast(float) mChildPreferredHeight));

		if (mUpdateLayout)
		{
			list_implementor.performLayout(ctx);
			mUpdateLayout = false;
		}

		ctx.save;
		ctx.translate(mPos.x, mPos.y);
		ctx.intersectScissor(0, 0, mSize.x, mSize.y);
		list_implementor.draw(ctx);
		ctx.restore;

		if (mChildPreferredHeight <= mSize.y)
			return;

		NVGPaint paint = ctx.boxGradient(
			mPos.x + mSize.x - 12 + 1, mPos.y + 4 + 1, 8,
			mSize.y - 8, 3, 4, Color(0, 0, 0, 32), Color(0, 0, 0, 92));
		ctx.beginPath;
		ctx.roundedRect(mPos.x + mSize.x - 12, mPos.y + 4, 8,
					mSize.y - 8, 3);
		ctx.fillPaint(paint);
		ctx.fill;

		paint = ctx.boxGradient(
			mPos.x + mSize.x - 12 - 1,
			mPos.y + 4 + (mSize.y - 8 - scrollh) * mScroll - 1, 8, scrollh,
			3, 4, Color(220, 220, 220, 100), Color(128, 128, 128, 100));

		ctx.beginPath;
		ctx.roundedRect(
			mPos.x + mSize.x - 12 + 1,
			mPos.y + 4 + 1 + (mSize.y - 8 - scrollh) * mScroll, 8 - 2,
			scrollh - 2, 2);
		ctx.fillPaint(paint);
		ctx.fill;
	}
	// override void save(Serializer &s) const;
	// override bool load(Serializer &s);
protected:
	int mChildPreferredHeight;
	float mScroll;
	bool mUpdateLayout;
	IListImplementor list_implementor;
}

/// Convert given range of List height to corresponding items indices
private auto heightToItemIndex(R)(R data, double start, double delta, double spacing, ref size_t start_index, ref size_t last_index, double e0)
{
	const N = data.length;
	size_t idx = start_index;
	assert(delta >= 0);

	if (e0 > start)
	{
		assert(0 <= idx && idx < N);
		for(; idx > 0; idx--)
		{
			if (e0 - data[idx-1].size.y - spacing <= start &&
				e0 > start)
			{
				start_index = idx-1;
				e0 -= data[idx-1].size.y + spacing;
				break;
			}
			else
			{
				e0 -= data[idx-1].size.y + spacing;
			}
		}
	}
	else
	{
		idx = start_index;
		for(; idx < N; idx++)
		{
			if (e0 <= start && e0 + data[idx].size.y + spacing > start)
			{
				start_index = idx;
				break;
			}
			else
			{
				e0 += data[idx].size.y + spacing;
			}
		}
		assert(0 <= idx);
		assert(idx <= N);
		assert(
			(e0 <= start && idx == data.length) ||
			(e0 <= start && (e0 + data[idx].size.y + spacing) > start) || 
			(idx == N /*&& e0 == E*/)
		);
	}

	if (idx == N)
	{
		// assert(e0 == E);
		start_index = N - 1;
		last_index = N;
		return cast(size_t) e0; // start (and finish too) is beyond the last index
	}

	auto e1 = e0;
	last_index = 0;

	for(; idx < N; idx++)
	{
		if (e1 > start + delta)
		{
			last_index = idx + 1;
			break;
		}
		else
			e1 += data[idx].size.y + spacing;
	}

	if (idx == data.length)
		last_index = idx; // start is before and finish is beyond the last index

	return cast(size_t) e0;
}
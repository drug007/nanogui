///
module nanogui.experimental.list;

/*
	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/

import std.algorithm : min, max;
import std.range : isRandomAccessRange, ElementType;
import nanogui.widget;
import nanogui.common : MouseButton, Vector2f, Vector2i, NanoContext;
import nanogui.experimental.utils : Model, isProcessible;

/**
 * Tree view widget.
 */
class List(D) : Widget
	if (isProcessible!D)
{
public:

	alias Data = D;

	enum modelHasCollapsed = is(typeof(Model!Data.collapsed) == bool);

	/**
	 * Adds a TreeView to the specified `parent`.
	 *
	 * Params:
	 *     parent = The Widget to add this TreeView to.
	 *     data   = The content of the widget.
	 */
	this(Widget parent, Data data)
	{
		super(parent);
		_data = data;
		_model = makeModel(_data);
		mScroll = 0.0f;
		this.data = data;
	}

	// the getter for the data is private because
	// the widget does not own the data and
	// the widget can not be considered as
	// a data source
	private @property ref auto data() const
	{
		return _data;
	}

	@property
	auto data(Data data)
	{
		_data = data;
		_model.update(data);
		_model.sizeYM = 0;
		_model_changed = true;
		calculateScrollableState;
		rm.posY = 0;
		traversal(_model, _data, rm, 1);
	}

	/// Callback that called on mouse clicking
	void delegate(MouseButton, ref const(TreePath)) onMousePressed;

	void applyByTreePath(T)(ref const(TreePath) tree_path, void delegate(ref const(T) value) dg)
	{
		import nanogui.experimental.utils : applyByTreePath;
		applyByTreePath(_data, _model, tree_path.value[], dg);
	}

	/// Return the current scroll amount as a value between 0 and 1. 0 means scrolled to the top and 1 to the bottom.
	float scroll() const { return mScroll; }
	/// Set the scroll amount to a value between 0 and 1. 0 means scrolled to the top and 1 to the bottom.
	void setScroll(float scroll) { mScroll = scroll; }

	override void performLayout(NanoContext ctx)
	{
		super.performLayout(ctx);

		mSize.y = parent.size.y - 2*parent.layout.margin;
		import nanogui.window : Window;
		if (auto window = cast(const Window)(parent) && window.title.length)
			mSize.y -= parent.theme.mWindowHeaderHeight;
		if (mSize.y < 0)
			mSize.y = 0;

		calculateScrollableState();
	}

	private void calculateScrollableState()
	{
		if (_model_changed)
		{
			const scroll_position = mScroll * (_model.size - size.y);
			import nanogui.experimental.utils : MeasuringVisitor;
			auto mv = MeasuringVisitor(0, fontSize);
			_model.traversalForward(_data, mv);
			mScroll = scroll_position / (_model.size - size.y);
			_model_changed = false;
		}

		if (_model.size <= mSize.y)
			mScroll = 0;
	}

	private bool isMouseInside(Vector2i p)
	{
		import nanogui.experimental.utils : isPointInRect;
		const rect_size = Vector2i(mSize.x, mSize.y);
		return isPointInRect(mPos, rect_size, p);
	}

	override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
	{
		if (!isMouseInside(p))
			return false;

		if (_pushed_scroll_btn)
		{
			// scroll button height
			float scrollh = height * min(1.0f, height / _model.size);

			mScroll = max(0.0f, min(1.0f, mScroll + rel.y / (mSize.y - 8.0f - scrollh)));
			return true;
		}

		return super.mouseDragEvent(p, rel, button, modifiers);
	}

	override bool scrollEvent(Vector2i p, Vector2f rel)
	{
		if (_model.size > mSize.y)
		{
			mScroll = max(0.0f, min(1.0f, mScroll - 10*rel.y/_model.size));
			return true;
		}

		return super.scrollEvent(p, rel);
	}

	static if (modelHasCollapsed)
	{
		import std.typecons : Nullable;

		Nullable!bool collapsed(int[] path)
		{
			import nanogui.experimental.utils : getPropertyByTreePath;

			return getPropertyByTreePath!("collapsed", bool)(_data, _model, path);
		}

		bool collapsed()
		{
			import std.exception : enforce;
			import nanogui.experimental.utils : getPropertyByTreePath;

			auto v = getPropertyByTreePath!("collapsed", bool)(_data, _model, (int[]).init);
			enforce(!v.isNull);
			return v.get;
		}

		void collapsed(bool value)
		{
			collapsed(null, value);
		}

		void collapsed(int[] path, bool value)
		{
			import nanogui.experimental.utils : setPropertyByTreePath;

			setPropertyByTreePath!"collapsed"(_data, _model, path, value);
			_model_changed = true;
			calculateScrollableState;
			screen.needToPerfomLayout = true;
		}
	}

	override bool mouseEnterEvent(Vector2i p, bool enter)
	{
		if (!enter)
			_pushed_scroll_btn = false;
		return super.mouseEnterEvent(p, enter);
	}

	/**
	 * The mouse button callback will return `true` when all three conditions are met:
	 *
	 * 1. This TreeView is "enabled" (see `nanogui.Widget.mEnabled`).
	 * 2. `p` is inside this TreeView.
	 * 3. `button` is `MouseButton.Left`.
	 *
	 * Since a mouse button event is issued for both when the mouse is pressed, as well
	 * as released, this function sets `nanogui.TreeView.mPushed` to `true` when
	 * parameter `down == true`.  When the second event (`down == false`) is fired,
	 * `nanogui.TreeView.mChecked` is inverted and `nanogui.TreeView.mCallback`
	 * is called.
	 *
	 * That is, the callback provided is only called when the mouse button is released,
	 * **and** the click location remains within the TreeView boundaries.  If the user
	 * clicks on the TreeView and releases away from the bounds of the TreeView,
	 * `nanogui.TreeView.mPushed` is simply set back to `false`.
	 */
	override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
	{
		if (!mEnabled)
			return false;

		if (!isMouseInside(p))
			return false;

		static if (modelHasCollapsed)
		{
			import nanogui.experimental.utils : isPointInRect;
			const scroll_bar_available = _model.size > mSize.y;
			// get the area over the header of the widget
			auto header_area = Vector2i(mSize.x, cast(int)_model.header_size);
			if (scroll_bar_available)
				header_area.x -= ScrollBarWidth;
			const over_header_area = isPointInRect(mPos, header_area, p);

			bool over_scroll_area;
			Vector2i scroll_area_pos;
			if (scroll_bar_available) // there is a scroll bar
			{
				scroll_area_pos = mPos + Vector2i(header_area.x, 0);
				auto scroll_area_size = Vector2i(ScrollBarWidth, mSize.y);
				over_scroll_area = isPointInRect(scroll_area_pos, scroll_area_size, p);
			}
			// if the event happens over neither the header nor scroll bar
			// nor any item - ignore it
			if (!over_header_area && !over_scroll_area && !tree_path.value.length)
				return false;

			if (button == MouseButton.Left)
			{
				if (down)
				{
					if (over_scroll_area)
					{
						const scroll = scrollBtnSize;
						import nanogui.experimental.utils : isPointInRect;
						const rtopleft = scroll_area_pos + Vector2f(0, scroll.y);
						const rsize = Vector2f(ScrollBarWidth, scroll.h);
						if (isPointInRect(rtopleft, rsize, Vector2f(p)))
							_pushed_scroll_btn = true;
					}
					else
						mPushed = true;
				}
				else
				{
					if (mPushed)
					{
						if (!over_scroll_area)
						{
							const value = collapsed(tree_path.value[]);
							if (!value.isNull)
								collapsed(tree_path.value[], !value.get);
						}
						mPushed = false;
					}
					_pushed_scroll_btn = false;
				}
				if (button == MouseButton.Left && down && !mFocused)
					requestFocus();
				version(none) return true;          // <--- replaced by this
			}                                       //                    |
			                                        //                    |
			if (onMousePressed && down)             //                    |
				onMousePressed(button, tree_path);  //                    |
			                                        //                    |
			return button == MouseButton.Left;      //  <------------------
		}
		else
			return true;
	}

	/// The preferred size of this TreeView.
	override Vector2i preferredSize(NanoContext ctx) const
	{
		// always return 0 because the size is defined by the parent container
		return Vector2i(0, 0);
	}

	/// Draws this TreeView.
	override void draw(ref NanoContext ctx)
	{
		ctx.save;

		ctx.fontSize(theme.mButtonFontSize);
		ctx.fontFace("sans-bold");

		const scroll_position = cast(size_t) (mScroll * (_model.size - size.y));

		if (_scroll_position != scroll_position)
		{
			_scroll_position = scroll_position;
			// Make a traversal to determine the position of the first visible item (rm.posY)
			// The coordinate of visible area (destination in this case) minus the position of
			// the first visible item is  the size of invisible part of the first visible item
			// if the item is partially visible
			traversal(_model, _data, rm, _scroll_position);
		}

		ctx.theme = theme;
		// Задаем размер по Х. Пыо У размер рассчитывается на основе размеров
		// элементов виджета
		auto sizeX = size.x;
		if (_model.size > mSize.y)
			sizeX -= ScrollBarWidth;

		ctx.mouse -= mPos;
		scope(exit) ctx.mouse += mPos;
		ctx.translate(mPos.x, mPos.y);
		ctx.intersectScissor(0, 0, sizeX, mSize.y);

		import nanogui.experimental.details.list_visitors : RenderingVisitor;
		import nanogui.layout : Orientation;

		// the size of invisible part of the first item
		// always 0 or below
		const auto invisiblePartSize = rm.posY - rm.destY;
		assert(invisiblePartSize <= 0);

		auto renderer = RenderingVisitor(ctx, Orientation.Vertical, rm.path, rm.posY, invisiblePartSize, sizeX);
		traversal(_model, _data, renderer, _scroll_position + size.y);
		tree_path = renderer.selectedItem;

		ctx.restore;

		if (_model.size > mSize.y)
			drawScrollBar(ctx);
	}

	private ScrollButtonSize scrollBtnSize()
	{
		const float scrollh = max(16, height * min(1.0f, height / _model.size));
		return ScrollButtonSize((mSize.y - 8 - scrollh) * mScroll, scrollh);
	}

	private void drawScrollBar(ref NanoContext ctx)
	{
		const scroll = scrollBtnSize;

		// scroll bar
		NVGPaint paint = ctx.boxGradient(
			mPos.x + mSize.x - ScrollBarWidth + 1, mPos.y + 4 + 1, 8,
			mSize.y - 8, 3, 4, Color(0, 0, 0, 32), Color(0, 0, 0, 192));
		ctx.beginPath;
		ctx.roundedRect(mPos.x + mSize.x - ScrollBarWidth, mPos.y + 4, 8,
					mSize.y - 8, 3);
		ctx.fillPaint(paint);
		ctx.fill;

		// scroll button
		paint = ctx.boxGradient(
			mPos.x + mSize.x - ScrollBarWidth - 1,
			mPos.y + 4 + scroll.y - 1, 8, scroll.h,
			3, 4, Color(220, 220, 220, 200), Color(128, 128, 128, 200));

		ctx.beginPath;
		ctx.roundedRect(
			mPos.x + mSize.x - ScrollBarWidth + 1,
			mPos.y + 4 + 1 + scroll.y, 8 - 2,
			scroll.h - 2, 2);
		ctx.fillPaint(paint);
		ctx.fill;
	}

// // Saves this TreeView to the specified Serializer.
//override void save(Serializer &s) const;

// // Loads the state of the specified Serializer to this TreeView.
//override bool load(Serializer &s);

protected:

	static struct ScrollButtonSize
	{
		float y; // y position of the scroll button
		float h; // height of the scroll button
	}

	import nanogui.experimental.utils : makeModel, traversal, traversalForward, TreePath;
	import nanogui.experimental.details.list_visitors : RelativeMeasurer;

	enum ScrollBarWidth = 8;
	Data _data;
	typeof(makeModel(_data)) _model;
	RelativeMeasurer rm;

	// sequence of indices to get access to current element of current treeview
	TreePath tree_path;

	double mScroll;
	bool mPushed;

	// y coordinate of first item
	size_t _scroll_position;
	size_t _start_item;
	size_t _finish_item;
	// y coordinate of the widget in space of first item
	size_t _shift;
	// if model size should be recalculated
	bool _model_changed;
	// if mouse left button has been pressed and not released over scroll button
	bool _pushed_scroll_btn;
}

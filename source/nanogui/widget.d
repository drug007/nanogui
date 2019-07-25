/*
	nanogui.widget -- Base class of all widgets

	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch> and
	ported to D by Alexandr Druzhinin <drug2004@bk.ru>
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/
///
module nanogui.widget;

import std.container.array;

import nanogui.theme;
import nanogui.layout;
import nanogui.common : Cursor, Vector2i, Vector2f, MouseButton, KeyAction;
import nanogui.screen : Screen;
public import nanogui.common;

/**
 * Base class of all widgets.
 *
 * Widget is the base class of all widgets in nanogui. It can
 * also be used as an panel to arrange an arbitrary number of child
 * widgets using a layout generator (see `nanogui.layout.Layout`).
 */
class Widget
{
public:
	/// Construct a new widget with the given parent widget
	this(Widget parent)
	{
		mVisible = true;
		mEnabled = true;
		mTooltip = ""; 
		mFontSize = -1;
		mIconExtraScale = 1.0f; 
		mCursor = Cursor.Arrow;
		if (parent)
			parent.addChild(this);
	}

	/// Return the parent widget
	final Widget parent() { return mParent; }
	/// Return the parent widget
	auto parent() const { return mParent; }
	/// Set the parent widget
	final void parent(Widget parent) { mParent = parent; }

	/// Return the used `nanogui.layout.Layout` generator
	final Layout layout() { return mLayout; }
	/// Return the used `nanogui.layout.Layout` generator
	auto layout() const { return mLayout; }
	/// Set the used `nanogui.layout.Layout` generator
	final void layout(Layout layout) { mLayout = layout; }

	/// Return the `nanogui.theme.Theme` used to draw this widget
	final const(Theme) theme() const { return mTheme; }
	/// Set the `nanogui.theme.Theme` used to draw this widget
	void theme(Theme theme)
	{
		if (mTheme is theme)
			return;
		mTheme = theme;
		foreach(child; mChildren)
			child.theme = theme;
	}

	/// Return the position relative to the parent widget
	final Vector2i position() const { return mPos; }
	/// Set the position relative to the parent widget
	final void position(Vector2i pos) { mPos = pos; }

	/// Return the absolute position on screen
	final Vector2i absolutePosition() const
	{
		return mParent ?
			(parent.absolutePosition + mPos) : mPos;
	}

	/// Return the size of the widget
	final Vector2i size() const { return mSize; }
	/// set the size of the widget
	final void size(Vector2i size) { mSize = size; }

	/// Return the width of the widget
	final int width() const { return mSize.x; }
	/// Set the width of the widget
	final void width(int width) { mSize.x = width; }

	/// Return the height of the widget
	final int height() const { return mSize.y; }
	/// Set the height of the widget
	final void height(int height) { mSize.y = height; }

	/**
	 * Set the fixed size of this widget
	 *
	 * If nonzero, components of the fixed size attribute override any values
	 * computed by a layout generator associated with this widget. Note that
	 * just setting the fixed size alone is not enough to actually change its
	 * size; this is done with a call to `nanogui.widget.Widget.size` or a call to `nanogui.widget.Widget.performLayout`
	 * in the parent widget.
	 */
	final void fixedSize(Vector2i fixedSize) { mFixedSize = fixedSize; }

	/// Return the fixed size
	final Vector2i fixedSize() const { return mFixedSize; }

	/// Return the fixed width (see `fixedSize`)
	final int fixedWidth() const { return mFixedSize.x; }
	/// Return the fixed height (see `fixedSize`)
	final int fixedHeight() const { return mFixedSize.y; }
	/// Set the fixed width (see `fixedSize`)
	final void fixedWidth(int width) { mFixedSize.x = width; }
	/// Set the fixed height (see `fixedSize`)
	final void fixedHeight(int height) { mFixedSize.y = height; }

	/// Return whether or not the widget is currently visible (assuming all parents are visible)
	final bool visible() const { return mVisible; }
	/// Set whether or not the widget is currently visible (assuming all parents are visible)
	final void visible(bool visible) { mVisible = visible; }

	/// Check if this widget is currently visible, taking parent widgets into account
	final bool visibleRecursive() const {
		import std.typecons : Rebindable;
		bool visible = true;
		Rebindable!(const Widget) widget = this;
		while (widget) {
			visible &= widget.visible;
			widget = widget.parent;
		}
		return visible;
	}

	/// Return the number of child widgets
	final int childCount() const
	{
		import std.conv : castFrom;
		return castFrom!size_t.to!int(mChildren.length);
	}

	/// Return the list of child widgets of the current widget
	auto children() { return mChildren; }
	/// ditto
	auto children() const { return mChildren; }

	/**
	* Add a child widget to the current widget at
	* the specified index.
	*
	* This function almost never needs to be called by hand,
	* since the constructor of `Widget` automatically
	* adds the current widget to its parent
	*/
	void addChild(int index, Widget widget)
	{
		assert(index <= childCount);
		mChildren.insertBefore(mChildren[index..$], widget);
		widget.parent = this;
		widget.theme = mTheme;
	}

	/// Convenience function which appends a widget at the end
	void addChild(Widget widget)
	{
		addChild(childCount(), widget);
	}

	/// Remove a child widget by index
	void removeChild(int index)
	{
		import std.range : takeOne;
		mChildren.linearRemove(mChildren[index..$].takeOne);
	}

	/// Remove a child widget by value
	void removeChild(Widget widget)
	{
		import std.algorithm : find;
		import std.range : takeOne;
		mChildren.linearRemove(mChildren[].find(widget).takeOne);
	}

	/// Retrieves the child at the specific position
	auto childAt(int index) const { return mChildren[index]; }

	/// Retrieves the child at the specific position
	auto childAt(int index) { return mChildren[index]; }

	/// Returns the index of a specific child or -1 if not found
	int childIndex(Widget widget) const
	{
		import std.algorithm : countUntil;
		return cast(int) countUntil!(a=>a is widget)(mChildren[]);
	}

	/// Variadic shorthand notation to construct and add a child widget
	auto add(W, Args...)(Args args)
	{
		return new WidgetClass(this, args);
	}

	/// Walk up the hierarchy and return the parent window
	final Window window()
	{
		Widget widget = this;
		while (true) {
			if (!widget)
				throw new Exception(
					"Widget:internal error (could not find parent window)");
			Window window = cast(Window)(widget);
			if (window)
				return window;
			widget = widget.parent;
		}
	}

	/// Walk up the hierarchy and return the parent screen
	final Screen screen()
	{
		auto widget = this;
		while (true) {
			if (!widget)
				throw new Exception(
					"Widget:internal error (could not find parent screen)");
			auto screen = cast(Screen) widget;
			if (screen)
				return screen;
			widget = widget.parent;
		}
	}

	protected void invalidate()
	{
		screen.needToDraw = true;
	}

	/// Associate this widget with an ID value (optional)
	void setId(string id) { mId = id; }
	/// Return the ID value associated with this widget, if any
	auto id() const { return mId; }

	/// Return whether or not this widget is currently enabled
	final bool enabled() const { return mEnabled; }
	/// Set whether or not this widget is currently enabled
	final void enabled(bool enabled) { mEnabled = enabled; }

	/// Return whether or not this widget is currently focused
	bool focused() const { return mFocused; }
	/// Set whether or not this widget is currently focused
	void focused(bool focused) { mFocused = focused; }
	/// Request the focus to be moved to this widget
	void requestFocus()
	{
		import nanogui.screen : Screen;
		Widget widget = this;
		while (widget.parent())
			widget = widget.parent();
		(cast(Screen) widget).updateFocus(this);
	}

	string tooltip() const { return mTooltip; }
	void tooltip(string tooltip) { mTooltip = tooltip; }

	/// Return current font size. If not set the default of the current theme will be returned
	final int fontSize() const
	{
		return (mFontSize < 0 && mTheme) ? mTheme.mStandardFontSize : mFontSize;
	}
	/// Set the font size of this widget
	final void fontSize(int fontSize) { mFontSize = fontSize; }
	/// Return whether the font size is explicitly specified for this widget
	final bool hasFontSize() const { return mFontSize > 0; }

	/**
	* The amount of extra scaling applied to *icon* fonts.
	* See `nanogui.Widget.mIconExtraScale`.
	*/
	float iconExtraScale() const { return mIconExtraScale; }

	/**
	* Sets the amount of extra scaling applied to *icon* fonts.
	* See `nanogui.Widget.mIconExtraScale`.
	*/
	void iconExtraScale(float scale) { mIconExtraScale = scale; }

	/// Return a pointer to the cursor of the widget
	Cursor cursor() const { return mCursor; }
	/// Set the cursor of the widget
	void cursor(Cursor value) { mCursor = value; }

	/// Check if the widget contains a certain position
	final bool contains(Vector2i p) const {
		import std.algorithm : all;
		// the widget contains a position if it more than
		// the widget position and less than widget position
		// + widget size
		auto d = (p-mPos);
		return d[].all!"a>=0" && (d-mSize)[].all!"a<=0";
	}

	/// Determine the widget located at the given position value (recursive)
	Widget findWidget(Vector2i p)
	{
		foreach_reverse(child; mChildren)
		{
			if (child.visible() && child.contains(p - mPos))
				return child.findWidget(p - mPos);
		}
		return contains(p) ? this : null;
	}

	/// Handle a mouse button event (default implementation: propagate to children)
	bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
	{
		foreach_reverse(ch; mChildren)
		{
			Widget child = ch;
			if (child.visible && child.contains(p - mPos) &&
				child.mouseButtonEvent(p - mPos, button, down, modifiers))
				return true;
		}
		if (button == MouseButton.Left && down && !mFocused)
			requestFocus();
		return false;
	}

	/// Handle a mouse motion event (default implementation: propagate to children)
	bool mouseMotionEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
	{
		foreach_reverse(it; mChildren)
		{
			Widget child = it;
			if (!child.visible)
				continue;
			const contained = child.contains(p - mPos);
			const prevContained = child.contains(p - mPos - rel);
			if (contained != prevContained)
				child.mouseEnterEvent(p, contained);
			if ((contained || prevContained) &&
				child.mouseMotionEvent(p - mPos, rel, button, modifiers))
				return true;
		}
		return false;
	}

	/// Handle a mouse drag event (default implementation: do nothing)
	bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
	{
		return false;
	}

	/// Handle a mouse enter/leave event (default implementation: record this fact, but do nothing)
	bool mouseEnterEvent(Vector2i p, bool enter)
	{
		mMouseFocus = enter;
		return false;
	}

	/// Handle a mouse scroll event (default implementation: propagate to children)
	bool scrollEvent(Vector2i p, Vector2f rel)
	{
		foreach_reverse (child; mChildren)
		{
			if (!child.visible)
				continue;
			if (child.contains(p - mPos) && child.scrollEvent(p - mPos, rel))
				return true;
		}
		return false;
	}

	/// Handle a focus change event (default implementation: record the focus status, but do nothing)
	bool focusEvent(bool focused)
	{
		mFocused = focused;
		return false;
	}

	/// Handle a keyboard event (default implementation: do nothing)
	bool keyboardEvent(int key, int scancode, KeyAction action, int modifiers)
	{
		return false;
	}

	/// Handle text input (UTF-32 format) (default implementation: do nothing)
	bool keyboardCharacterEvent(dchar codepoint)
	{
		return false;
	}

	/// Compute the preferred size of the widget
	Vector2i preferredSize(NanoContext ctx) const
	{
		if (mLayout)
			return mLayout.preferredSize(ctx, this);
		else
			return mSize;
	}

	/// Compute the preferred size of the widget considering its child except
	/// skipped one (for example button panel of window)
	final Vector2i preferredSize(NanoContext ctx, const Widget skipped) const
	{
		if (mLayout)
			return mLayout.preferredSize(ctx, this, skipped);
		else
			return mSize;
	}

	/// Invoke the associated layout generator to properly place child widgets, if any
	void performLayout(NanoContext ctx)
	{
		if (mLayout) {
			mLayout.performLayout(ctx, this);
		} else {
			foreach(c; mChildren) {
				Vector2i pref = c.preferredSize(ctx), fix = c.fixedSize();
				c.size(Vector2i(
					fix[0] ? fix[0] : pref[0],
					fix[1] ? fix[1] : pref[1]
				));
				c.performLayout(ctx);
			}
		}
	}

	/// Draw the widget (and all child widgets)
	void draw(NanoContext ctx)
	{
		version(NANOGUI_SHOW_WIDGET_BOUNDS)
		{
			ctx.strokeWidth(1.0f);
			ctx.beginPath;
			ctx.rect(mPos.x + 1.0f, mPos.y + 0.0f, mSize.x - 1, mSize.y - 1);
			ctx.strokeColor(Color(255, 0, 0, 255));
			ctx.stroke;
		}

		if (mChildren.length == 0)
			return;

		ctx.save;
		ctx.translate(mPos.x, mPos.y);
		foreach(child; mChildren)
		{
			if (child.visible)
			{
				ctx.save;
				scope(exit) ctx.restore;
				ctx.intersectScissor(child.mPos.x, child.mPos.y, child.mSize.x, child.mSize.y);
				child.draw(ctx);
			}
		}
		ctx.restore;
	}

// // Save the state of the widget into the given \ref Serializer instance
//virtual void save(Serializer &s) const;

// // Restore the state of the widget from the given \ref Serializer instance
//virtual bool load(Serializer &s);

protected:
	/// Free all resources used by the widget and any children
	~this()
	{
//foreach(child; mChildren) {
//    if (child)
//        child.decRef();
//}
	}

	/**
	 * Convenience definition for subclasses to get the full icon scale for this
	 * class of Widget.  It simple returns the value
	 * `mTheme.mIconScale * this.mIconExtraScale`.
	 *
	 * See_also:
	 *     `Theme.mIconScale` and `Widget.mIconExtraScale`.  This tiered scaling
	 *     strategy may not be appropriate with fonts other than `entypo.ttf`.
	 */
	pragma(inline, true)
	float icon_scale() const { return mTheme.mIconScale * mIconExtraScale; }

	Widget mParent;
	Theme mTheme;
	Layout mLayout;
	string mId;
	Vector2i mPos, mSize, mFixedSize;
	Array!Widget mChildren;

	/**
	 * Whether or not this Widget is currently visible.  When a Widget is not
	 * currently visible, no time is wasted executing its drawing method.
	 */
	bool mVisible;

	/**
	 * Whether or not this Widget is currently enabled.  Various different kinds
	 * of derived types use this to determine whether or not user input will be
	 * accepted.  For example, when ``mEnabled == false``, the state of a
	 * CheckBox cannot be changed, or a TextBox will not allow new input.
	 */
	bool mEnabled;
	bool mFocused, mMouseFocus;
	string mTooltip;
	int mFontSize;

	/**
	 * The amount of extra icon scaling used in addition the the theme's
	 * default icon font scale.  Default value is ``1.0``, which implies
	 * that `icon_scale` simply returns the value of `nanogui.Theme.mIconScale`.
	 *
	 * Most widgets do not need extra scaling, but some (e.g., `CheckBox`, `TextBox`)
	 * need to adjust the Theme's default icon scaling
	 * `nanogui.Theme.mIconScale` to properly display icons within their
	 * bounds (upscale, or downscale).
	 *
	 * Summary:
	 *
	 *    When using `nvgFontSize` for icons in subclasses, make sure to call
	 *    the `icon_scale` function.  Expected usage when *drawing* icon fonts
	 *    is something like:
	 *
	 * ---
	 *
	 *       void draw(NanoContext ctx)
	 *       {
	 *           // fontSize depends on the kind of `Widget`.  Search for `FontSize`
	 *           // in the `Theme` class (e.g., standard vs button)
	 *           float ih = fontSize;
	 *           // assuming your Widget has a declared `mIcon`
	 *           if (isFontIcon(mIcon)) {
	 *               ih *= icon_scale();
	 *               ctx.fontFace("icons");
	 *               ctx.fontSize(ih);
	 *               /// remaining drawing code (see button.d for more)
	 *           }
	 *       }
	 * ---
	 */
	float mIconExtraScale;
	Cursor mCursor;
}

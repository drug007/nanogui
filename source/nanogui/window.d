///
module nanogui.window;

/*
	nanogui/window.d -- Top-level window widget

	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/

import nanogui.widget;
import nanogui.common : Vector2i, Vector2f, MouseButton;

/**
 * Top-level window widget.
 */
class Window : Widget
{
public:
	this(Widget parent, string title = "Untitled", bool resizable = false)
	{
		super(parent);
		mTitle = title;
		mButtonPanel = null;
		mModal = false;
		mDrag = false;
		mResizeDir = Vector2i();
		import std.algorithm : max;
		mMinSize = Vector2i(3*mTheme.mResizeAreaOffset, max(3*mTheme.mResizeAreaOffset, mTheme.mWindowHeaderHeight + mTheme.mResizeAreaOffset));
		mResizable = resizable;
	}

	/// Return the window title
	final string title() const { return mTitle; }
	/// Set the window title
	final void title(string title) { mTitle = title; }

	/// Is this a model dialog?
	final bool modal() const { return mModal; }
	/// Set whether or not this is a modal dialog
	final void modal(bool modal) { mModal = modal; }
     /// Is this a resizable window?
    bool resizable() const { return mResizable; }
    /// Set whether or not this window is resizable
    void resizable(bool value) { mResizable = value; }

	/// Return the panel used to house window buttons
	final Widget buttonPanel()
	{
		import nanogui.layout : BoxLayout, Orientation, Alignment;
		if (!mButtonPanel) {
			mButtonPanel = new Widget(this);
			mButtonPanel.layout(new BoxLayout(Orientation.Horizontal, Alignment.Middle, 0, 4));
		}
		return mButtonPanel;
	}

	/// Dispose the window
	final void dispose();

	/// Center the window in the current `Screen`
	final void center();

	/// Draw the window
	override void draw(NanoContext ctx)
	{
		assert (mTheme);
		int ds = mTheme.mWindowDropShadowSize, cr = mTheme.mWindowCornerRadius;
		int hh = mTheme.mWindowHeaderHeight;

		/* Draw window */
		ctx.save;
		ctx.beginPath;
		ctx.roundedRect(mPos.x, mPos.y, mSize.x, mSize.y, cr);

		ctx.fillColor(mMouseFocus ? mTheme.mWindowFillFocused
									  : mTheme.mWindowFillUnfocused);
		ctx.fill;


		/* Draw a drop shadow */
		NVGPaint shadowPaint = ctx.boxGradient(
			mPos.x, mPos.y, mSize.x, mSize.y, cr*2, ds*2,
			mTheme.mDropShadow, mTheme.mTransparent);

		ctx.save;
		ctx.resetScissor;
		ctx.beginPath;
		ctx.rect(mPos.x-ds,mPos.y-ds, mSize.x+2*ds, mSize.y+2*ds);
		ctx.roundedRect(mPos.x, mPos.y, mSize.x, mSize.y, cr);
		ctx.pathWinding(NVGSolidity.Hole);
		ctx.fillPaint(shadowPaint);
		ctx.fill;
		ctx.restore;

		if (mTitle.length)
		{
			/* Draw header */
			NVGPaint headerPaint = ctx.linearGradient(
				mPos.x, mPos.y, mPos.x,
				mPos.y + hh,
				mTheme.mWindowHeaderGradientTop,
				mTheme.mWindowHeaderGradientBot);

			ctx.beginPath;
			ctx.roundedRect(mPos.x, mPos.y, mSize.x, hh, cr);

			ctx.fillPaint(headerPaint);
			ctx.fill;

			ctx.beginPath;
			ctx.roundedRect(mPos.x, mPos.y, mSize.x, hh, cr);
			ctx.strokeColor(mTheme.mWindowHeaderSepTop);

			ctx.save;
			ctx.intersectScissor(mPos.x, mPos.y, mSize.x, 0.5f);
			ctx.stroke;
			ctx.restore;

			ctx.beginPath;
			ctx.moveTo(mPos.x + 0.5f, mPos.y + hh - 1.5f);
			ctx.lineTo(mPos.x + mSize.x - 0.5f, mPos.y + hh - 1.5);
			ctx.strokeColor(mTheme.mWindowHeaderSepBot);
			ctx.stroke;

			ctx.fontSize(18.0f);
			ctx.fontFace("sans-bold");
			auto algn = NVGTextAlign();
			algn.center = true;
			algn.middle = true;
			ctx.textAlign(algn);

			ctx.fontBlur(2);
			ctx.fillColor(mTheme.mDropShadow);
			ctx.text(mPos.x + mSize.x / 2,
					mPos.y + hh / 2, mTitle);

			ctx.fontBlur(0);
			ctx.fillColor(mFocused ? mTheme.mWindowTitleFocused
									   : mTheme.mWindowTitleUnfocused);
			ctx.text(mPos.x + mSize.x / 2, mPos.y + hh / 2 - 1,
					mTitle);
		}

		ctx.restore;
		Widget.draw(ctx);
	}
	/// Handle window drag events
	override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
	{
		import std.algorithm : min, max;
		import gfm.math : maxByElem;

		if (mDrag && (button & (1 << MouseButton.Left)) != 0) {
			mPos += rel;
			{
				// mPos = mPos.cwiseMax(Vector2i::Zero());
				mPos[0] = max(mPos[0], 0);
				mPos[1] = max(mPos[1], 0);
			}
			{
				// mPos = mPos.cwiseMin(parent()->size() - mSize);
				auto other = parent.size - mSize;
				mPos[0] = min(mPos[0], other[0]);
				mPos[1] = min(mPos[1], other[1]);
			}
			return true;
		}
		else if (mResizable && mResize && (button & (1 << MouseButton.Left)) != 0)
		{
			const lowerRightCorner = mPos + mSize;
			const upperLeftCorner = mPos;
			bool resized = false;


			if (mResizeDir.x == 1) {
				if ((rel.x > 0 && p.x >= lowerRightCorner.x) || (rel.x < 0)) {
					mSize.x += rel.x;
					resized = true;
				}
			} else if (mResizeDir.x == -1) {
				if ((rel.x < 0 && p.x <= upperLeftCorner.x) ||
						(rel.x > 0)) {
					mSize.x += -rel.x;
					mSize = mSize.maxByElem(mMinSize);
					mPos = lowerRightCorner - mSize;
					resized = true;
				}
			}

			if (mResizeDir.y == 1) {
				if ((rel.y > 0 && p.y >= lowerRightCorner.y) || (rel.y < 0)) {
					mSize.y += rel.y;
					resized = true;
				}
			}
			mSize = mSize.maxByElem(mMinSize);
			if (resized)
				screen.needToPerfomLayout = true;
			return true;
		}
		return false;
	}
	/// Handle a mouse motion event (default implementation: propagate to children)
	override bool mouseMotionEvent(const Vector2i p, const Vector2i rel, MouseButton button, int modifiers)
	{
		import nanogui.common : Cursor;

		if (Widget.mouseMotionEvent(p, rel, button, modifiers))
			return true;

		if (mResizable && mFixedSize.x == 0 && checkHorizontalResize(p) != 0)
		{
			mCursor = Cursor.HResize;
		}
		else if (mResizable && mFixedSize.y == 0 && checkVerticalResize(p) != 0)
		{
			mCursor = Cursor.VResize;
		}
		else
		{
			mCursor = Cursor.Arrow;
		}
		return false;
	}
	/// Handle mouse events recursively and bring the current window to the top
	override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
	{
		if (super.mouseButtonEvent(p, button, down, modifiers))
			return true;
		if (button == MouseButton.Left)
		{
			mDrag = down && (p.y - mPos.y) < mTheme.mWindowHeaderHeight;
			mResize = false;
			if (mResizable && !mDrag && down)
			{
				mResizeDir.x = (mFixedSize.x == 0) ? checkHorizontalResize(p) : 0;
				mResizeDir.y = (mFixedSize.y == 0) ? checkVerticalResize(p) : 0;
				mResize = mResizeDir.x != 0 || mResizeDir.y != 0;
			}
			return true;
		}
		return false;
	}
	/// Accept scroll events and propagate them to the widget under the mouse cursor
	override bool scrollEvent(Vector2i p, Vector2f rel)
	{
		Widget.scrollEvent(p, rel);
		return true;
	}

	/// Compute the preferred size of the widget
	override Vector2i preferredSize(NanoContext ctx) const
	{
		if (mResizable)
			return mSize;

		Vector2i result = Widget.preferredSize(ctx, mButtonPanel);

		ctx.fontSize(18.0f);
		ctx.fontFace("sans-bold");
		float[4] bounds;
		ctx.textBounds(0, 0, mTitle, bounds);

		if (result.x < bounds[2]-bounds[0] + 20)
			result.x = cast(int) (bounds[2]-bounds[0] + 20);
		if (result.y < bounds[3]-bounds[1])
			result.y = cast(int) (bounds[3]-bounds[1]);

		return result;
	}
	/// Invoke the associated layout generator to properly place child widgets, if any
	override void performLayout(NanoContext ctx)
	{
		if (!mButtonPanel) {
			Widget.performLayout(ctx);
		} else {
			mButtonPanel.visible(false);
			Widget.performLayout(ctx);
			foreach (w; mButtonPanel.children) {
				w.fixedSize(Vector2i(22, 22));
				w.fontSize(15);
			}
			mButtonPanel.visible(true);
			mButtonPanel.size(Vector2i(width(), 22));
			mButtonPanel.position(Vector2i(width() - (mButtonPanel.preferredSize(ctx).x + 5), 3));
			mButtonPanel.performLayout(ctx);
		}
	}
//override void save(Serializer &s) const;
//override bool load(Serializer &s);
public:
	/// Internal helper function to maintain nested window position values; overridden in \ref Popup
	void refreshRelativePlacement()
	{
		/* Overridden in \ref Popup */
	}
protected:
	int checkHorizontalResize(const Vector2i mousePos)
	{
		const offset = mTheme.mResizeAreaOffset;
		const lowerRightCorner = absolutePosition + size;
		const headerLowerLeftCornerY = absolutePosition.y + mTheme.mWindowHeaderHeight;

		if (mousePos.y > headerLowerLeftCornerY &&
			mousePos.x <= absolutePosition.x + offset &&
			mousePos.x >= absolutePosition.x)
		{
			return -1;
		}
		else if (mousePos.y > headerLowerLeftCornerY && 
			mousePos.x >= lowerRightCorner.x - offset &&
			mousePos.x <= lowerRightCorner.x)
		{
			return 1;
		}

		return 0;
	}
	int checkVerticalResize(const Vector2i mousePos)
	{
		const offset = mTheme.mResizeAreaOffset;
		const lowerRightCorner = absolutePosition + size;

		// Do not check for resize area on top of the window. It is to prevent conflict drag and resize event.
		if (mousePos.y >= lowerRightCorner.y - offset && mousePos.y <= lowerRightCorner.y)
		{
			return 1;
		}

		return 0;
	}

	string mTitle;
	Widget mButtonPanel;
	bool mModal;
	bool mDrag;
	bool mResize;
	Vector2i mResizeDir;
	Vector2i mMinSize;
	bool mResizable;
}
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
	this(Widget parent, string title = "Untitled")
	{
		super(parent);
		mTitle = title;
		mButtonPanel = null;
		mModal = false;
		mDrag = false;
	}

	/// Return the window title
	final string title() const { return mTitle; }
	/// Set the window title
	final void title(string title) { mTitle = title; }

	/// Is this a model dialog?
	final bool modal() const { return mModal; }
	/// Set whether or not this is a modal dialog
	final void modal(bool modal) { mModal = modal; }

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

	string mTitle;
	Widget mButtonPanel;
	bool mModal;
	bool mDrag;
}
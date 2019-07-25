///
module nanogui.label;

/*
	nanogui/label.h -- Text label with an arbitrary font, color, and size

	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/

import nanogui.widget;
import nanogui.common;
import nanogui.theme;

/**
 * Text label widget.
 *
 * The font and color can be customized. When `Widget.fixedWidth``
 * is used, the text is wrapped when it surpasses the specified width.
 */
class Label : Widget 
{
public:
	this(Widget parent, string caption, string font = "sans", int fontSize = -1)
	{
		super(parent);
		mCaption = caption;
		mFont = font;
		if (mTheme) {
			mFontSize = mTheme.mStandardFontSize;
			mColor = mTheme.mTextColor;
		}
		if (fontSize >= 0) mFontSize = fontSize;
	}

	import nanogui.experimental.utils : DependencyProperty;
	/// Getter and setter for the label's text caption
	mixin DependencyProperty!(string, "caption");
	/// Getter and setter for the currently active font
	/// (2 are available by default: 'sans' and 'sans-bold')
	mixin DependencyProperty!(string, "font");
	/// Getter and setter for the label color
	mixin DependencyProperty!(Color, "color");

	/// Set the `Theme` used to draw this widget
	override void theme(Theme theme)
	{
		Widget.theme(theme);
		if (mTheme) {
			mFontSize = mTheme.mStandardFontSize;
			mColor = mTheme.mTextColor;
		}
	}

	/// Compute the size needed to fully display the label
	override Vector2i preferredSize(NanoContext ctx) const
	{
		if (mCaption == "")
			return Vector2i();
		ctx.fontFace(mFont);
		ctx.fontSize(fontSize());
		
		float[4] bounds;
		if (mFixedSize.x > 0) {
			NVGTextAlign algn;
			algn.left = true;
			algn.top = true;
			ctx.textAlign(algn);
			ctx.textBoxBounds(mPos.x, mPos.y, mFixedSize.x, mCaption, bounds);
			return Vector2i(mFixedSize.x, cast(int) (bounds[3] - bounds[1]));
		} else {
			NVGTextAlign algn;
			algn.left = true;
			algn.middle = true;
			ctx.textAlign(algn);
			return Vector2i(
				cast(int) ctx.textBounds(0, 0, mCaption, bounds) + 2,
				fontSize()
			);
		}
	}

	/// Draw the label
	override void draw(NanoContext ctx)
	{
		Widget.draw(ctx);
		ctx.fontFace(mFont);
		ctx.fontSize(fontSize());
		ctx.fillColor(mColor);
		if (mFixedSize.x > 0)
		{
			NVGTextAlign algn;
			algn.left = true;
			algn.top = true;
			ctx.textAlign(algn);
			ctx.textBox(mPos.x, mPos.y, mFixedSize.x, mCaption);
		} else {
			NVGTextAlign algn;
			algn.left = true;
			algn.middle = true;
			ctx.textAlign(algn);
			ctx.text(mPos.x, mPos.y + mSize.y * 0.5f, mCaption);
		}
	}

	//override void save(Serializer &s) const;
	//override bool load(Serializer &s);
}

///
module nanogui.experimental.treeview;

/*
	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/

import nanogui.widget;
import nanogui.common : Vector2i, Vector2f, MouseButton;

/**
 * Tree view widget.
 *
 * Remarks:
 *     This class overrides `nanogui.Widget.mIconExtraScale` to be `1.2f`,
 *     which affects all subclasses of this Widget.  Subclasses must explicitly
 *     set a different value if needed (e.g., in their constructor).
 */
class TreeView(TreeModel) : Widget
{
public:
	/**
	 * Adds a TreeView to the specified `parent`.
	 *
	 * Params:
	 *     parent   = The Widget to add this TreeView to.
	 *     caption  = The caption text of the TreeView (default `"Untitled"`).
	 *     callback = If provided, the callback to execute when the TreeView is 
	 *     checked or unchecked.  Default parameter function does nothing.  See
	 *     `nanogui.TreeView.mPushed` for the difference between "pushed"
	 *     and "checked".
	 */
	this(Widget parent, const string caption, TreeModel model, void delegate(bool) callback)
	{
		super(parent);
		mCaption = caption;
		mPushed = false;
		mChecked = false;
		mCallback = callback;
		mIconExtraScale = 1.2f;// widget override

		this.model = model;
	}

	/// The caption of this TreeView.
	final string caption() const { return mCaption; }

	/// Sets the caption of this TreeView.
	final void caption(string caption) { mCaption = caption; }

	/// Whether or not this TreeView is currently checked.
	final bool checked() const { return mChecked; }

	/// Sets whether or not this TreeView is currently checked.
	final void checked(bool checked) { mChecked = checked; }

	/// Whether or not this TreeView is currently pushed.  See `nanogui.TreeView.mPushed`.
	final bool pushed() const { return mPushed; }

	/// Sets whether or not this TreeView is currently pushed.  See `nanogui.TreeView.mPushed`.
	final void pushed(bool pushed) { mPushed = pushed; }

	/// Returns the current callback of this TreeView.
	final void delegate(bool) callback() const { return mCallback; }

	/// Sets the callback to be executed when this TreeView is checked / unchecked.
	final void callback(void delegate(bool) callback) { mCallback = callback; }

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
		super.mouseButtonEvent(p, button, down, modifiers);
		if (!mEnabled)
			return false;

		import nanogui.experimental.utils : isPointInRect;
		const rect_size = Vector2i(mSize.x, mChecked ? cast(int) (fontSize() * 1.3f) : mSize.y);

		if (button == MouseButton.Left)
		{
			import std.stdio;
			writeln(tree_path);
			if (!isPointInRect(mPos, rect_size, p))
				return false;
			if (down)
			{
				mPushed = true;
			}
			else if (mPushed)
			{
				mChecked = !mChecked;
				if (mCallback)
					mCallback(mChecked);
				mPushed = false;
			}
			return true;
		}
		return false;
	}

	/// The preferred size of this TreeView.
	override Vector2i preferredSize(NanoContext ctx) const
	{
		if (mFixedSize != Vector2i())
			return mFixedSize;
		ctx.fontSize(fontSize());
		ctx.fontFace("sans");
		float[4] bounds;
		const extra = mChecked ? (fontSize() * 1.3f * 1/*model.length*/) : 0;
		return cast(Vector2i) Vector2f(
			(ctx.textBounds(0, 0, mCaption, bounds[]) +
				1.8f * fontSize()),
			fontSize() * 1.3f + extra);
	}

	/// Draws this TreeView.
	override void draw(ref NanoContext ctx)
	{
		// do not call super.draw() because we do custom drawing

		Vector2i titleSize = void;
		titleSize.x = mSize.x;
		titleSize.y = mChecked ? cast(int) (fontSize() * 1.3f) : mSize.y;

		ctx.save;
		scope(exit) ctx.restore;
		{
			// background for icon
			NVGPaint bg = ctx.boxGradient(mPos.x + 1.5f, mPos.y + 1.5f,
										titleSize.y - 2.0f, titleSize.y - 2.0f, 3, 3,
										mPushed ? Color(0, 0, 0, 100) : Color(0, 0, 0, 32),
										Color(0, 0, 0, 180));

			ctx.beginPath;
			ctx.roundedRect(mPos.x + 1.0f, mPos.y + 1.0f, titleSize.y - 2.0f,
						titleSize.y - 2.0f, 3);
			ctx.fillPaint(bg);
			ctx.fill;
		}

		ctx.position = mPos;
		ctx.theme = theme;
		ctx.current_size = 0; // prevents highlighting of icon
		const old = ctx.mouse;
		ctx.mouse -= window.absolutePosition;
		scope(exit) ctx.mouse = old;

		import nanogui.experimental.utils : drawItem, indent, unindent;
		{
			// icon
			ctx.fontSize(titleSize.y * icon_scale());
			ctx.fontFace("icons");
			ctx.fillColor(mEnabled ? mTheme.mIconColor
										: mTheme.mDisabledTextColor);
			// NVGTextAlign algn;
			// algn.center = true;
			// algn.middle = true;
			// ctx.textAlign(algn);

			import nanogui.entypo : Entypo;
			drawItem(ctx, titleSize.y, 
					[mChecked ? cast(dchar)Entypo.ICON_CHEVRON_DOWN :
								cast(dchar)Entypo.ICON_CHEVRON_RIGHT
					]);
			ctx.position -= Vector2i(0, titleSize.y);
		}

		ctx.current_size = size.x - titleSize.y;

		ctx.tree_view_nesting_level = 0;

		{
			// Caption
			ctx.position += Vector2i(cast(int)(1.6f * fontSize), 0);
			scope(exit) ctx.position -= Vector2i(cast(int)(1.6f * fontSize), 0);
			ctx.fontSize(fontSize);
			ctx.fontFace("sans");
			ctx.fillColor(mEnabled ? mTheme.mTextColor : mTheme.mDisabledTextColor);
			tree_path.length = 0;
			if (drawItem(ctx, titleSize.y, mCaption))
			{
				tree_path.length = 1;
				tree_path[ctx.tree_view_nesting_level] = 0;
			}
		}

		// content of tree view
		if (mChecked)
		{
			ctx.indent;
			ctx.tree_view_nesting_level++;
			scope(exit)
			{
				assert(ctx.tree_view_nesting_level > 0);
				ctx.tree_view_nesting_level--;
				ctx.unindent;
			}

			ctx.fontSize(fontSize);
			ctx.fontFace("sans");

			import std.algorithm : min;
			import std.range : isRandomAccessRange;
			static if (isRandomAccessRange!TreeModel)
			{
				foreach(i, item; model)
				{
					ctx.save;
					scope(exit) ctx.restore;

					if (drawItem(ctx, cast(int)(fontSize() * 1.3f), item))
					{
						if (tree_path.length < ctx.tree_view_nesting_level+1)
							tree_path.length = ctx.tree_view_nesting_level+1;
						tree_path[ctx.tree_view_nesting_level] = i;
					}
				}
			}
			else static if (is(TreeModel == struct))
			{
				ctx.save;
				scope(exit) ctx.restore;

				if (drawItem(ctx, cast(int)(fontSize() * 1.3f), model))
				{
					if (tree_path.length < ctx.tree_view_nesting_level+1)
						tree_path.length = ctx.tree_view_nesting_level+1;
					tree_path[ctx.tree_view_nesting_level] = 0;
				}
			}
			else
			{
			 	// static assert(0, "Unsupported type of TreeModel: " ~ TreeModel.stringof);
				drawItem(ctx, cast(int)(fontSize() * 1.3f), model);
			}
		}
	}

// // Saves this TreeView to the specified Serializer.
//override void save(Serializer &s) const;

// // Loads the state of the specified Serializer to this TreeView.
//override bool load(Serializer &s);

protected:
	/// The caption text of this TreeView.
	string mCaption;

	/**
	 * Internal tracking variable to distinguish between mouse click and release.
	 * `nanogui.TreeView.mCallback` is only called upon release.  See
	 * `nanogui.TreeView.mouseButtonEvent` for specific conditions.
	 */
	bool mPushed;

	/// Whether or not this TreeView is currently checked or unchecked.
	bool _mChecked;
	
	bool mChecked() const { return _mChecked; };
	auto mChecked(bool v)
	{
		if (_mChecked != v)
		{
			_mChecked = v;
			import std.stdio;
			writeln("mChecked changed: ", v);
			mSize += Vector2i(0, v ? 100 : -100);
			screen.needToPerfomLayout = true;
		}
	}

	TreeModel model;

	/// The function to execute when `nanogui.TreeView.mChecked` is changed.
	void delegate(bool) mCallback;

	// sequence of indices to get access to current element of current treeview
	size_t[] tree_path;
	// // number of current dimension (nesting level) of current tree path
	// size_t current_dimension;
}

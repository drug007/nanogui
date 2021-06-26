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
import nanogui.common : MouseButton, Vector2f, Vector2i;
import nanogui.experimental.utils : Model, TreePathVisitor;

/**
 * Tree view widget.
 */
class TreeView(Data) : Widget
{
public:

	enum modelHasCollapsed = is(typeof(Model!Data.collapsed) == bool);

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
	this(Widget parent, string caption, Data data, void delegate(bool) callback)
	{
		super(parent);
		mCaption = caption;
		static if (modelHasCollapsed)
		{
			mPushed = false;
			mChecked = false;
			mCallback = callback;
		}
		_data = data;
		_model = makeModel(_data);
		import nanogui.experimental.utils : MeasuringVisitor;
		auto v = MeasuringVisitor([size.x, fontSize]);
		_model.visitForward(_data, v);
	}

	/// The caption of this TreeView.
	final string caption() const { return mCaption; }

	/// Sets the caption of this TreeView.
	final void caption(string caption) { mCaption = caption; }

	static if (modelHasCollapsed)
	{
		/// Whether or not this TreeView is currently checked.
		final bool checked() const { return _model.collapsed; }

		/// Sets whether or not this TreeView is currently checked.
		final void checked(bool checked) { _model.collapsed = checked; }

		/// Whether or not this TreeView is currently pushed.  See `nanogui.TreeView.mPushed`.
		final bool pushed() const { return mPushed; }

		/// Sets whether or not this TreeView is currently pushed.  See `nanogui.TreeView.mPushed`.
		final void pushed(bool pushed) { mPushed = pushed; }

		/// Returns the current callback of this TreeView.
		final void delegate(bool) callback() const { return mCallback; }

		/// Sets the callback to be executed when this TreeView is checked / unchecked.
		final void callback(void delegate(bool) callback) { mCallback = callback; }
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

		static if (modelHasCollapsed)
		{
			import nanogui.experimental.utils : isPointInRect;
			const rect_size = Vector2i(mSize.x, !_model.collapsed ? cast(int) (fontSize() * 1.3f) : mSize.y);

			if (button == MouseButton.Left)
			{
				import nanogui.experimental.utils : setPropertyByTreePath, getPropertyByTreePath;
				if (!down && tree_path.value.length)
				{
					const value = getPropertyByTreePath!("collapsed", bool)(_data, _model, tree_path.value[]);
					if (!value.isNull)
					{
						setPropertyByTreePath!"collapsed"(_data, _model, tree_path.value[], !value.get);
						import nanogui.experimental.utils : MeasuringVisitor;
						auto mv = MeasuringVisitor([size.x, fontSize]);
						_model.visitForward(_data, mv);
						screen.needToPerfomLayout = true;
					}
				}
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
		}

		return super.mouseButtonEvent(p, button, down, modifiers);
	}

	/// The preferred size of this TreeView.
	override Vector2i preferredSize(NanoContext ctx) const
	{
		if (mFixedSize != Vector2i())
			return mFixedSize;
		ctx.fontSize(fontSize());
		ctx.fontFace("sans");
		float[4] bounds;

		return cast(Vector2i) Vector2f(
			(ctx.textBounds(0, 0, mCaption, bounds[]) +
				1.8f * fontSize()),
			_model.size);
	}

	/// Draws this TreeView.
	override void draw(ref NanoContext ctx)
	{
		import auxil.location : SizeType;
		// do not call super.draw() because we do custom drawing

		//ctx.fontSize(theme.mButtonFontSize);
		//ctx.fontFace("sans-bold");

		ctx.theme = theme;
		ctx.size = Vector2f(size.x, ctx.fontSize);
		ctx.position = mPos;

		//ctx.mouse -= mPos;
		//scope(exit) ctx.mouse += mPos;

		auto renderer = RenderingVisitor(ctx);
		renderer.loc.y.destination = cast(SizeType) (ctx.position.y + size.y);
		import nanogui.layout : Orientation;
		renderer.ctx.orientation = Orientation.Vertical;
		_model.visitForward(_data, renderer);
		tree_path = renderer.selected_item;
	}

// // Saves this TreeView to the specified Serializer.
//override void save(Serializer &s) const;

// // Loads the state of the specified Serializer to this TreeView.
//override bool load(Serializer &s);

protected:

	import nanogui.experimental.utils : makeModel, visit, visitForward, TreePath;

	/// The caption text of this TreeView.
	string mCaption;

	static if (modelHasCollapsed)
	{
		/**
		* Internal tracking variable to distinguish between mouse click and release.
		* `nanogui.TreeView.mCallback` is only called upon release.  See
		* `nanogui.TreeView.mouseButtonEvent` for specific conditions.
		*/
		bool mPushed;

		bool mChecked() const
		{
			static if (is(typeof(_model.collapsed) == bool))
				return !_model.collapsed;
			else
				return false;
		}

		auto mChecked(bool v)
		{
			static if (is(typeof(_model.collapsed) == bool))
				if (_model.collapsed == v)
				{
					_model.collapsed = !v;
					import nanogui.experimental.utils : MeasuringVisitor;
					auto mv = MeasuringVisitor([size.x, fontSize]);
					_model.visitForward(_data, mv);
					screen.needToPerfomLayout = true;
				}
		}

		/// The function to execute when `nanogui.TreeView.mChecked` is changed.
		void delegate(bool) mCallback;
	}

	Data _data;
	typeof(makeModel(_data)) _model;

	// sequence of indices to get access to current element of current treeview
	TreePath tree_path;
}

private struct RenderingVisitor
{
	import nanogui.experimental.utils : drawItem, indent, unindent, TreePath;
	import auxil.model;

	NanoContext ctx;
	TreePathVisitor default_visitor;
	alias default_visitor this;

	TreePath selected_item;
	float finish;

	bool complete()
	{
		return ctx.position.y > finish;
	}

	void beforeChildren()
	{
		ctx.indent;
	}

	void afterChildren()
	{
		ctx.unindent;
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		ctx.save;
		scope(exit) ctx.restore;

		{
			// background for icon
			NVGPaint bg = ctx.boxGradient(
				ctx.position.x + 1.5f, ctx.position.y + 1.5f,
				ctx.size[ctx.orientation] - 2.0f, ctx.size[ctx.orientation] - 2.0f, 3, 3,
				true/*pushed*/ ? Color(0, 0, 0, 100) : Color(0, 0, 0, 32),
				Color(0, 0, 0, 180)
			);

			ctx.beginPath;
			ctx.roundedRect(ctx.position.x + 1.0f, ctx.position.y + 1.0f,
				ctx.size[ctx.orientation] - 2.0f, ctx.size[ctx.orientation] - 2.0f, 3);
			ctx.fillPaint(bg);
			ctx.fill;
		}

		{
			// icon
			ctx.fontSize(ctx.size.y);
			ctx.fontFace("icons");
			ctx.fillColor(model.enabled ? ctx.theme.mIconColor
			                            : ctx.theme.mDisabledTextColor);
			NVGTextAlign algn;
			algn.center = true;
			algn.middle = true;
			ctx.textAlign(algn);

			import nanogui.entypo : Entypo;
			int axis2 = (cast(int)ctx.orientation+1)%2;
			const old = ctx.size[axis2];
			ctx.size[axis2] = ctx.size[ctx.orientation]; // icon has width equals to its height
			dchar symb = model.collapsed ? Entypo.ICON_CHEVRON_RIGHT :
			                               Entypo.ICON_CHEVRON_DOWN;
			if (drawItem(ctx, ctx.size[ctx.orientation], [symb]))
				selected_item = loc.current_path;
			ctx.size[axis2] = old; // restore full width
			ctx.position[ctx.orientation] -= ctx.size[ctx.orientation];
		}

		{
			// Caption
			ctx.position.x += 1.6f * ctx.size.y;
			scope(exit) ctx.position.x -= 1.6f * ctx.size.y;
			ctx.fontSize(ctx.size.y);
			ctx.fontFace("sans");
			ctx.fillColor(model.enabled ? ctx.theme.mTextColor : ctx.theme.mDisabledTextColor);
			if (drawItem(ctx, ctx.size.y, Data.stringof))
				selected_item = loc.current_path;
		}
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		ctx.fontSize(ctx.size.y);
		ctx.fontFace("sans");
		ctx.fillColor(ctx.theme.mTextColor);
		if (drawItem(ctx, cast(int) ctx.size[ctx.orientation], data))
			selected_item = loc.current_path;
	}
}

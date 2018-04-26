///
module nanogui.screen;

import std.algorithm : min;

import arsd.nanovega;
public import gfm.math : vec2i;

import nanogui.widget : Widget;
import nanogui.common : Vector2i, Vector2f, MouseButton, MouseAction, KeyAction;

class Screen : Widget
{
	import nanogui.window : Window;

	this(int w, int h, long timestamp)
	{
		super(null);
		size = vec2i(w, h);
		mNeedToDraw = true;
		mLastInteraction = mTimestamp = timestamp;
	}

	auto currTime() const { return mTimestamp; }
	void currTime(long value)
	{
		mTimestamp = value;
		auto elapsed = value - mLastInteraction;
		if (!mTooltipShown && elapsed > 5_000_000)
		{
			const widget = findWidget(mMousePos);
			if (widget && widget.tooltip.length)
				mNeedToDraw = true;
		}
	}

	auto lastInteraction() { return mLastInteraction; }

	override void draw(NVGContext nvg)
	{
		import arsd.simpledisplay;

		glViewport(0, 0, size.x, size.y);
		// clear window
		glClearColor(0., 0., 0., 0);
		glClear(glNVGClearFlags); // use NanoVega API to get flags for OpenGL call

		nvg.beginFrame(size.x, size.y); // begin rendering
		scope(exit) nvg.endFrame(); // and flush render queue on exit

		super.draw(nvg);

		mNeedToDraw = false;

		float elapsed = (mTimestamp - mLastInteraction)/10_000_000.0f;

		if (elapsed > 0.5f)
		{
			/* Draw tooltips */
			const widget = findWidget(mMousePos);
			if (widget && widget.tooltip.length) {
				int tooltipWidth = 150;

				float[4] bounds;
				nvg.fontFace("sans");
				nvg.fontSize(15.0f);
				NVGTextAlign algn;
	            algn.left = true;
	            algn.top = true;
	            nvg.textAlign(algn);
				nvg.textLineHeight(1.1f);
				Vector2i pos = widget.absolutePosition() +
							   Vector2i(widget.width() / 2, widget.height() + 10);

				nvg.textBounds(pos.x, pos.y,
								widget.tooltip, bounds);
				int h = cast(int) (bounds[2] - bounds[0]) / 2;

				if (h > tooltipWidth / 2) {
					algn.center = true;
		            algn.top = true;
		            nvg.textAlign(algn);
					nvg.textBoxBounds(pos.x, pos.y, tooltipWidth,
									widget.tooltip, bounds);

					h = cast(int)(bounds[2] - bounds[0]) / 2;
				}
				enum threshold = 0.8f;
				auto alpha = min(1.0, 2 * (elapsed - 0.5f)) * threshold;
				nvg.globalAlpha(alpha);
				mTooltipShown = (alpha > threshold - 0.01) ? true : false;

				nvg.beginPath;
				nvg.fillColor(Color(0, 0, 0, 255));
				nvg.roundedRect(bounds[0] - 4 - h, bounds[1] - 4,
							   cast(int) (bounds[2] - bounds[0]) + 8,
							   cast(int) (bounds[3] - bounds[1]) + 8, 3);

				int px = cast(int) ((bounds[2] + bounds[0]) / 2) - h;
				nvg.moveTo(px, bounds[1] - 10);
				nvg.lineTo(px + 7, bounds[1] + 1);
				nvg.lineTo(px - 7, bounds[1] + 1);
				nvg.fill();

				nvg.fillColor(Color(255, 255, 255, 255));
				nvg.fontBlur(0.0f);
				nvg.textBox(pos.x - h, pos.y, tooltipWidth,
						   widget.tooltip);
			}
		}
		else
			mTooltipShown = false;
	}

	bool mouseButtonCallbackEvent(MouseButton button, MouseAction action, int modifiers, long timestamp)
	{
		mNeedToDraw = true;
		mModifiers = modifiers;
		mLastInteraction = timestamp;
		try
		{
			if (mFocusPath.length > 1)
			{
				const window = cast(Window) (mFocusPath[mFocusPath.length - 2]);
				if (window && window.modal)
				{
					if (!window.contains(mMousePos))
						return false;
				}
			}

			if (action == MouseAction.Press)
				mMouseState |= 1 << button;
			else
				mMouseState &= ~(1 << button);

			const dropWidget = findWidget(mMousePos);
			if (mDragActive && action == MouseAction.Release &&
				dropWidget !is mDragWidget)
				mDragWidget.mouseButtonEvent(
					mMousePos - mDragWidget.parent.absolutePosition, button,
					false, mModifiers);

			//if (dropWidget !is null && dropWidget.cursor != mCursor)
			//{
			//	mCursor = dropWidget.cursor;
			//	glfwSetCursor(mGLFWWindow, mCursors[cast(int) mCursor]);
			//}

			if (action == MouseAction.Press && (button ==MouseButton.Left || button == MouseButton.Right)) {
				mDragWidget = findWidget(mMousePos);
				if (mDragWidget is this)
					mDragWidget = null;
				mDragActive = mDragWidget !is null;
				if (!mDragActive)
					updateFocus(null);
			} else {
				mDragActive = false;
				mDragWidget = null;
			}

			return mouseButtonEvent(mMousePos, button, action == MouseAction.Press,
									mModifiers);
		}
		catch (Exception e)
		{
			import std.stdio : stderr;
			stderr.writeln("Caught exception in event handler: ", e.msg);
			return false;
		}
	}

	/// Return the last observed mouse position value
	Vector2i mousePos() const { return mMousePos; }

	final void updateFocus(Widget widget)
	{
		mNeedToDraw = true;
		foreach (w; mFocusPath)
		{
			if (!w.focused)
				continue;
			w.focusEvent(false);
		}
		mFocusPath.clear;
		Widget window;
		while (widget)
		{
			mFocusPath.insertBack(widget);
			if (cast(Window)(widget))
				window = widget;
			widget = widget.parent;
		}
		foreach_reverse(it; mFocusPath)
			it.focusEvent(true);

		if (window)
			moveWindowToFront(cast(Window) window);
	}

	bool cursorPosCallbackEvent(double x, double y, long last_interaction)
	{
		mNeedToDraw = true;
		auto p = Vector2i(cast(int) x, cast(int) y);

		//#if defined(_WIN32) || defined(__linux__)
		//	p = (p.cast<float>() / mPixelRatio).cast<int>();
		//#endif

		bool ret;
		mLastInteraction = last_interaction;
		try
		{
			p -= Vector2i(1, 2);

			if (!mDragActive)
			{
				//const widget = findWidget(p);
				//if (widget !is null && widget.cursor != mCursor)
				//{
				//	mCursor = widget.cursor;
				//	glfwSetCursor(mGLFWWindow, mCursors[cast(int) mCursor]);
				//}
			}
			else
			{
				ret = mDragWidget.mouseDragEvent(
				p - mDragWidget.parent.absolutePosition, p - mMousePos,
				mMouseState, mModifiers);
			}

			if (!ret)
				ret = mouseMotionEvent(p, p - mMousePos, mMouseState, mModifiers);

			mMousePos = p;

			return ret;
		}
		catch (Exception e)
		{
			import std.stdio : stderr;
			stderr.writeln("Caught exception in event handler: ", e.msg);
			return false;
		}
	}

	void moveWindowToFront(Window window) {
		// mChildren.erase(std::remove(mChildren.begin(), mChildren.end(), window), mChildren.end());
		{
			// non-idiomatic way to implement erase-remove idiom in dlang
			size_t i;
			foreach(_; mChildren)
			{
				if (mChildren[i] is window)
					break;
				i++;
			}
			if (i < mChildren.length)
			{
				foreach(j; i..mChildren.length-1)
					mChildren[j] = mChildren[j+1];
				mChildren.removeBack;
			}
		}
		mChildren.insertBack(window);
		/* Brute force topological sort (no problem for a few windows..) */
		bool changed = false;
		do {
			size_t baseIndex = 0;
			for (size_t index = 0; index < mChildren.length; ++index)
				if (mChildren[index] == window)
					baseIndex = index;
			changed = false;
			for (size_t index = 0; index < mChildren.length; ++index)
			{
				import nanogui.popup : Popup;
				Popup pw = cast(Popup) mChildren[index];
				if (pw && pw.parentWindow is window && index < baseIndex) {
					moveWindowToFront(pw);
					changed = true;
					break;
				}
			}
		} while (changed);
		mNeedToDraw = true;
	}

	bool scrollCallbackEvent(double x, double y, long timestamp)
	{
		mLastInteraction = timestamp;
		try
		{
			if (mFocusPath.length > 1)
			{
				const window = cast(Window) mFocusPath[mFocusPath.length - 2];
				if (window && window.modal)
				{
					if (!window.contains(mMousePos))
						return false;
				}
			}
			return scrollEvent(mMousePos, Vector2f(x, y));
		}
		catch (Exception e)
		{
			import std.stdio : stderr;
			stderr.writeln("Caught exception in event handler: ", e.msg);
			return false;
		}
	}

	override bool keyboardEvent(int key, int scancode, KeyAction action, int modifiers)
	{
import std.stdio;
writeln(mFocusPath.length);
		if (mFocusPath.length > 0)
		{
			foreach_reverse(w; mFocusPath)
			{
writeln(w);
				if (w.focused && 
				    w.keyboardEvent(key, scancode, action, modifiers))
					return true;
			}
		}

		return false;
	}

	/// Window resize event handler
	bool resizeEvent(Vector2i size)
	{
		if (mResizeCallback) {
			mResizeCallback(size);
			mNeedToDraw = true;
			return true;
		}
		return false;
	}

	bool needToDraw() const pure @safe nothrow { return mNeedToDraw; }

protected:
	import std.container.array : Array;

	Vector2i     mMousePos;
	int          mModifiers;
	MouseButton  mMouseState;
	long         mLastInteraction;
	Array!Widget mFocusPath;
	bool         mDragActive;
	Widget       mDragWidget;
	bool         mNeedToDraw;
	long         mTimestamp;
	bool         mTooltipShown;
	void delegate(Vector2i) mResizeCallback;
}
module nanogui.nanogui;

import arsd.nanovega;
public import gfm.math : vec2i;

import nanogui.widget : Widget;
import nanogui.common : Vector2i, MouseButton, MouseAction;

class Screen : Widget
{
	import nanogui.window : Window;

	this(int w, int h)
	{
		super(null);
		size = vec2i(w, h);
	}

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
	}

	bool mouseButtonCallbackEvent(MouseButton button, int action, int modifiers, long timestamp)
	{
		mModifiers = modifiers;
		mLastInteraction = timestamp;
		//try
		//{
		//	if (mFocusPath.size() > 1)
		//	{
		//		const window = cast(Window) (mFocusPath[mFocusPath.size() - 2]);
		//		if (window && window.modal)
		//		{
		//			if (!window.contains(mMousePos))
		//				return false;
		//		}
		//	}

		//	if (action == GLFW_PRESS)
		//		mMouseState |= 1 << button;
		//	else
		//		mMouseState &= ~(1 << button);

		//	auto dropWidget = findWidget(mMousePos);
		//	if (mDragActive && action == GLFW_RELEASE &&
		//		dropWidget != mDragWidget)
		//		mDragWidget.mouseButtonEvent(
		//			mMousePos - mDragWidget.parent().absolutePosition(), button,
		//			false, mModifiers);

		//	if (dropWidget != nullptr && dropWidget.cursor() != mCursor) {
		//		mCursor = dropWidget.cursor();
		//		glfwSetCursor(mGLFWWindow, mCursors[cast(int) mCursor]);
		//	}

		//	if (action == GLFW_PRESS && (button == GLFW_MOUSE_BUTTON_1 || button == GLFW_MOUSE_BUTTON_2)) {
		//		mDragWidget = findWidget(mMousePos);
		//		if (mDragWidget == this)
		//			mDragWidget = nullptr;
		//		mDragActive = mDragWidget != nullptr;
		//		if (!mDragActive)
		//			updateFocus(nullptr);
		//	} else {
		//		mDragActive = false;
		//		mDragWidget = nullptr;
		//	}

			return mouseButtonEvent(mMousePos, button, action == MouseAction.Press,
									mModifiers);
		//}
		//catch (const exception e)
		//{
		//	import std.stdio : stderr;
		//	stderr.writeln("Caught exception in event handler: ", e.msg);
		//	return false;
		//}
	}

	/// Return the last observed mouse position value
	Vector2i mousePos() const { return mMousePos; }

	final void updateFocus(Widget widget)
	{
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
		auto p = Vector2i(cast(int) x, cast(int) y);

		//#if defined(_WIN32) || defined(__linux__)
		//	p = (p.cast<float>() / mPixelRatio).cast<int>();
		//#endif

		bool ret;
		mLastInteraction = last_interaction;
		try
		{
			p -= Vector2i(1, 2);

			//if (!mDragActive) {
			//	const widget = findWidget(p);
			//	if (widget !is null && widget.cursor != mCursor)
			//	{
			//		mCursor = widget.cursor;
			//		glfwSetCursor(mGLFWWindow, mCursors[cast(int) mCursor]);
			//	}
			//}
			//else
			//{
			//	ret = mDragWidget.mouseDragEvent(
			//		p - mDragWidget.parent.absolutePosition, p - mMousePos,
			//		mMouseState, mModifiers);
			//}

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
			//for (size_t index = 0; index < mChildren.size(); ++index)
			//{
			//	Popup pw = cast(Popup) mChildren[index];
			//	if (pw && pw.parentWindow() is window && index < baseIndex) {
			//		moveWindowToFront(pw);
			//		changed = true;
			//		break;
			//	}
			//}
		} while (changed);
	}

protected:
	import std.container.array : Array;

	Vector2i     mMousePos;
	int          mModifiers;
	MouseButton  mMouseState;
	long         mLastInteraction;
	Array!Widget mFocusPath;
}
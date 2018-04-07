module nanogui.nanogui;

import arsd.nanovega;
public import gfm.math : vec2i;

import nanogui.widget : Widget;
import nanogui.common : Vector2i, MouseButton, MouseAction;

class Screen : Widget
{
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
		//foreach (w; mFocusPath)
		//{
		//    if (!w.focused())
		//        continue;
		//    w.focusEvent(false);
		//}
		//mFocusPath.clear();
		//Widget *window = nullptr;
		//while (widget) {
		//    mFocusPath.push_back(widget);
		//    if (cast(Window)(widget))
		//        window = widget;
		//    widget = widget.parent();
		//}
		//for (auto it = mFocusPath.rbegin(); it != mFocusPath.rend(); ++it)
		//    (*it).focusEvent(true);

		//if (window)
		//    moveWindowToFront(cast(Window) window);
	}

protected:
	Vector2i mMousePos;
	int      mModifiers;
	long     mLastInteraction;
}
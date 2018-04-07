import arsd.simpledisplay;
import arsd.nanovega;

void main () {
	NVGContext nvg; // our NanoVega context
	// we need at least OpenGL3 with GLSL to use NanoVega,
	// so let's tell simpledisplay about that
	setOpenGLContextVersion(3, 0);
	// now create OpenGL window
	auto sdmain = new SimpleWindow(800, 600, "NanoVega Simple Sample", OpenGlOptions.yes, Resizability.allowResizing);
	// we need to destroy NanoVega context on window close
	// stricly speaking, it is not necessary, as nothing fatal
	// will happen if you'll forget it, but let's be polite.
	// note that we cannot do that *after* our window was closed,
	// as we need alive OpenGL context to do proper cleanup.
	sdmain.onClosing = delegate () {
		nvg.kill;
	};

	import nanogui.nanogui : Screen;
	import nanogui.widget, nanogui.theme, nanogui.checkbox, nanogui.label, nanogui.common, nanogui.window, nanogui.layout;

	Window window;
	CheckBox checkbox;
	Label label;
	Screen screen;

	// this is called just before our window will be shown for the first time.
	// we must create NanoVega context here, as it needs to initialize
	// internal OpenGL subsystem with valid OpenGL context.
	sdmain.visibleForTheFirstTime = delegate () {
		// yes, that's all
		nvg = nvgCreateContext();
		assert(nvg !is null, "cannot initialize NanoGui");

		screen = new Screen(sdmain.width, sdmain.height);

		window = new Window(screen, "Button demo");
		window.position(Vector2i(15, 15));
		window.theme = new Theme(nvg);
		window.size = Vector2i(screen.size.x - 30, screen.size.y - 30);
		window.layout(new GroupLayout());

		new Label(window, "Push buttons", "sans-bold");

		checkbox = new CheckBox(window, "Text0123456789", (bool value){ sdmain.redrawOpenGlSceneNow(); });
		checkbox.position = Vector2i(100, 190);
		checkbox.size = checkbox.preferredSize(nvg);
		checkbox.checked = true;

		label = new Label(window, "Label");
		label.position = Vector2i(100, 300);
		label.size = label.preferredSize(nvg);
		// now we should do layout manually yet
		window.performLayout(nvg);
	};

	// this callback will be called when we will need to repaint our window
	sdmain.redrawOpenGlScene = ()=>screen.draw(nvg);
	sdmain.eventLoop(0, // no pulse timer required
		delegate (KeyEvent event) {
			if (event == "*-Q" || event == "Escape") { sdmain.close(); return; } // quit on Q, Ctrl+Q, and so on
		},
		delegate (MouseEvent event) {
			import nanogui.common : MouseButton, MouseAction;

			MouseButton btn;
			MouseAction action;
			int modifiers;

			// convert event data from arsd.simpledisplay format
			// to own format
			switch(event.button)
			{
				case arsd.simpledisplay.MouseButton.left:
					btn = MouseButton.Left;
				break;
				case arsd.simpledisplay.MouseButton.right:
					btn = MouseButton.Right;
				break;
				default:
					btn = MouseButton.None;
			}

			final switch(event.type)
			{
				case arsd.simpledisplay.MouseEventType.buttonPressed:
					action = MouseAction.Press;
				break;
				case arsd.simpledisplay.MouseEventType.buttonReleased:
					action = MouseAction.Release;
				break;
				case arsd.simpledisplay.MouseEventType.motion:
					action = MouseAction.Motion;
				break;
			}

			if (event.modifierState & ModifierState.leftButtonDown)
				modifiers |= MouseButton.Left;
			if (event.modifierState & ModifierState.rightButtonDown)
				modifiers |= MouseButton.Right;
			if (event.modifierState & ModifierState.middleButtonDown)
				modifiers |= MouseButton.Middle;

			// propagating event

			if (event.type == MouseEventType.buttonPressed  ||
				event.type == MouseEventType.buttonReleased ||
				event.type == MouseEventType.motion)
			{
				import std.datetime : Clock;
				auto timestamp = Clock.currTime;
				screen.mouseButtonCallbackEvent(btn, action, modifiers, timestamp.stdTime);
			}
		},
	);
	flushGui(); // let OS do it's cleanup
}
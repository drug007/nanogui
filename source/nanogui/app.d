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

	Screen screen;

	// this is called just before our window will be shown for the first time.
	// we must create NanoVega context here, as it needs to initialize
	// internal OpenGL subsystem with valid OpenGL context.
	sdmain.visibleForTheFirstTime = delegate () {
		// yes, that's all
		nvg = nvgCreateContext();
		assert(nvg !is null, "cannot initialize NanoGui");

		screen = new Screen(sdmain.width, sdmain.height);
		screen.theme = new Theme(nvg);

		{
			auto window = new Window(screen, "Button demo");
			window.position(Vector2i(15, 15));
			window.size = Vector2i(screen.size.x - 30, screen.size.y - 30);
			window.layout(new GroupLayout());

			new Label(window, "Push buttons", "sans-bold");

			auto checkbox = new CheckBox(window, "Checkbox #1", (bool value){ sdmain.redrawOpenGlSceneNow(); });
			checkbox.position = Vector2i(100, 190);
			checkbox.size = checkbox.preferredSize(nvg);
			checkbox.checked = true;

			auto label = new Label(window, "Label");
			label.position = Vector2i(100, 300);
			label.size = label.preferredSize(nvg);
		}

		{
			auto window = new Window(screen, "Basic widgets");
			window.position(Vector2i(200, 15));
			window.layout(new GroupLayout());

			new Label(window, "Message dialog", "sans-bold");
			new CheckBox(window, "Checkbox #2", (bool value){ sdmain.redrawOpenGlSceneNow(); });
		}

		{
			auto window = new Window(screen, "Yet another window");
			window.position(Vector2i(300, 15));
			window.layout(new GroupLayout());

			new Label(window, "Message dialog", "sans-bold");
			new CheckBox(window, "Checkbox #3", (bool value){ });
		}

		{
			auto window = new Window(screen, "Yet another window");
			window.position(Vector2i(400, 15));
			window.layout(new GroupLayout());

			new Label(window, "Message dialog", "sans-bold");
			new CheckBox(window, "Checkbox #4", (bool value){ });
		}

		// now we should do layout manually yet
		screen.performLayout(nvg);
	};

	// this callback will be called when we will need to repaint our window
	sdmain.redrawOpenGlScene = ()=>screen.draw(nvg);
	sdmain.eventLoop(0, // no pulse timer required
		delegate (KeyEvent event)
		{
			if (event == "*-Q" || event == "Escape") { sdmain.close(); return; } // quit on Q, Ctrl+Q, and so on
		},
		delegate (MouseEvent event)
		{
			import std.datetime : Clock;
			import nanogui.common : MouseButton, MouseAction;

			scope(success) sdmain.redrawOpenGlSceneNow();

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
				case arsd.simpledisplay.MouseButton.middle:
					btn = MouseButton.Middle;
				break;
				case arsd.simpledisplay.MouseButton.wheelUp:
					btn = MouseButton.WheelUp;
				break;
				case arsd.simpledisplay.MouseButton.wheelDown:
					btn = MouseButton.WheelDown;
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
					screen.cursorPosCallbackEvent(event.x, event.y, Clock.currTime.stdTime);
				return;
			}

			if (event.modifierState & ModifierState.leftButtonDown)
				modifiers |= MouseButton.Left;
			if (event.modifierState & ModifierState.rightButtonDown)
				modifiers |= MouseButton.Right;
			if (event.modifierState & ModifierState.middleButtonDown)
				modifiers |= MouseButton.Middle;

			// propagating button events
			if (event.type == MouseEventType.buttonPressed  ||
				event.type == MouseEventType.buttonReleased ||
				event.type == MouseEventType.motion)
			{
				screen.mouseButtonCallbackEvent(btn, action, modifiers, Clock.currTime.stdTime);
			}
		},
	);
	flushGui(); // let OS do it's cleanup
}
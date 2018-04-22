///
module nanogui.arsdbackend;

import std.datetime : Clock;
import std.exception : enforce;

import arsd.simpledisplay;
import arsd.nanovega;

import nanogui.screen : Screen;
import nanogui.theme : Theme;
import nanogui.common : Vector2i;

class ArsdBackend
{
	this(int w, int h, string title)
	{
		// we need at least OpenGL3 with GLSL to use NanoVega,
		// so let's tell simpledisplay about that
		setOpenGLContextVersion(3, 0);

		simple_window = new SimpleWindow(w, h, title, OpenGlOptions.yes, Resizability.allowResizing);
		
		// we need to destroy NanoVega context on window close
		// stricly speaking, it is not necessary, as nothing fatal
		// will happen if you'll forget it, but let's be polite.
		// note that we cannot do that *after* our window was closed,
		// as we need alive OpenGL context to do proper cleanup.
		simple_window.onClosing = delegate () {
			nvg.kill;
		};

		simple_window.visibleForTheFirstTime = () {
			nvg = nvgCreateContext();
			enforce(nvg !is null, "cannot initialize NanoGui");

			screen = new Screen(simple_window.width, simple_window.height, Clock.currTime.stdTime);
			screen.theme = new Theme(nvg);

			// this callback will be called when we will need to repaint our window
			simple_window.redrawOpenGlScene = () {
				screen.size = Vector2i(simple_window.width, simple_window.height);
				screen.draw(nvg);
			};

			onVisibleForTheFirstTime();
		};
	}

	final void run()
	{
		simple_window.eventLoop(40,
			() {
				// unfortunately screen may be not initialized
				if (screen)
				{
					screen.currTime = Clock.currTime.stdTime;
					if (screen.needToDraw)
						simple_window.redrawOpenGlSceneNow();
				}
			},
			delegate (KeyEvent event)
			{
				if (event == "*-Q" || event == "Escape") { simple_window.close(); return; } // quit on Q, Ctrl+Q, and so on
			},
			delegate (MouseEvent event)
			{
				import std.datetime : Clock;
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
					case arsd.simpledisplay.MouseButton.middle:
						btn = MouseButton.Middle;
					break;
					case arsd.simpledisplay.MouseButton.wheelUp:
						btn = MouseButton.WheelUp;
						screen.scrollCallbackEvent(0, +1, Clock.currTime.stdTime);
					break;
					case arsd.simpledisplay.MouseButton.wheelDown:
						btn = MouseButton.WheelDown;
						screen.scrollCallbackEvent(0, -1, Clock.currTime.stdTime);
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
						assert(screen);
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

	/// this is called just before our window will be shown for the first time.
	/// we must create NanoVega context here, as it needs to initialize
	/// internal OpenGL subsystem with valid OpenGL context.
	abstract void onVisibleForTheFirstTime();

protected:
	NVGContext nvg;
	SimpleWindow simple_window;
	Screen screen;
}
module nanogui.sdlbackend;

import std.algorithm: map;
import std.array: array;
import std.exception: enforce;
import std.file: thisExePath;
import std.path: dirName, buildPath;
import std.range: iota;
import std.datetime : Clock;

import std.experimental.logger: Logger, NullLogger, FileLogger, globalLogLevel, LogLevel;

import gfm.math: mat4f, vec3f, vec4f;
import gfm.opengl: OpenGL;
import gfm.sdl2: SDL2, SDL2Window, SDL_Event, SDL_Cursor, SDL_SetCursor, 
	SDL_FreeCursor, SDL_Delay;

import arsd.nanovega : nvgCreateContext, kill, NVGContextFlag;
import nanogui.screen : Screen;
import nanogui.theme : Theme;
import nanogui.common : NanoContext, Vector2i, MouseButton, MouseAction, Cursor;

class SdlBackend : Screen
{
	this(int w, int h, string title)
	{
		/* Avoid locale-related number parsing issues */
		version(Windows) {}
		else {
			import core.stdc.locale;
			setlocale(LC_NUMERIC, "C");
		}

		import gfm.sdl2;

		this.width = w;
		this.height = h;

		// create a logger
		import std.stdio : stdout;
		_log = new FileLogger(stdout);

		// load dynamic libraries
		_sdl2 = new SDL2(_log, SharedLibVersion(2, 0, 0));
		_gl = new OpenGL(_log);
		globalLogLevel = LogLevel.error;

		// You have to initialize each SDL subsystem you want by hand
		_sdl2.subSystemInit(SDL_INIT_VIDEO);
		_sdl2.subSystemInit(SDL_INIT_EVENTS);

		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
		SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);

		// create an OpenGL-enabled SDL window
		window = new SDL2Window(_sdl2,
								SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
								width, height,
								SDL_WINDOW_OPENGL);

		window.setTitle(title);
		
		// reload OpenGL now that a context exists
		_gl.reload();

		// redirect OpenGL output to our Logger
		_gl.redirectDebugOutput();

		ctx = NanoContext(NVGContextFlag.Debug);
		enforce(ctx !is null, "cannot initialize NanoGui");

		mCursorSet[Cursor.Arrow]     = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_ARROW);
		mCursorSet[Cursor.IBeam]     = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_IBEAM);
		mCursorSet[Cursor.Crosshair] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_CROSSHAIR);
		mCursorSet[Cursor.Hand]      = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_HAND);
		mCursorSet[Cursor.HResize]   = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZEWE);
		mCursorSet[Cursor.VResize]   = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZENS);

		super(width, height, Clock.currTime.stdTime);
		theme = new Theme(ctx);
	}

	~this()
	{
		SDL_FreeCursor(mCursorSet[Cursor.Arrow]);
		SDL_FreeCursor(mCursorSet[Cursor.IBeam]);
		SDL_FreeCursor(mCursorSet[Cursor.Crosshair]);
		SDL_FreeCursor(mCursorSet[Cursor.Hand]);
		SDL_FreeCursor(mCursorSet[Cursor.HResize]);
		SDL_FreeCursor(mCursorSet[Cursor.VResize]);

		ctx.kill();
		_gl.destroy();
		window.destroy();
		_sdl2.destroy();
	}

	private void delegate () _onBeforeLoopStart;
	void onBeforeLoopStart(void delegate () dg)
	{
		_onBeforeLoopStart = dg;
	}

	void run()
	{
		import gfm.sdl2;

		window.hide;
		SDL_FlushEvents(SDL_WINDOWEVENT, SDL_SYSWMEVENT);
		window.show;

		onVisibleForTheFirstTime();

		SDL_Event event;

		uint prev_tick = SDL_GetTicks();
		while (SDL_QUIT != event.type)
		{
			if (_onBeforeLoopStart)
				_onBeforeLoopStart();

			SDL_PumpEvents();

			while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_FIRSTEVENT, SDL_SYSWMEVENT))
			{
				switch (event.type)
				{
					case SDL_WINDOWEVENT:
					{
						switch (event.window.event)
						{
							case SDL_WINDOWEVENT_MOVED:
								// window has been moved to other position
								break;

							case SDL_WINDOWEVENT_RESIZED:
							case SDL_WINDOWEVENT_SIZE_CHANGED:
							{
								// window size has been resized
								break;
							}

							case SDL_WINDOWEVENT_SHOWN:
							case SDL_WINDOWEVENT_FOCUS_GAINED:
							case SDL_WINDOWEVENT_RESTORED:
							case SDL_WINDOWEVENT_MAXIMIZED:
								// window has been activated
								break;

							case SDL_WINDOWEVENT_HIDDEN:
							case SDL_WINDOWEVENT_FOCUS_LOST:
							case SDL_WINDOWEVENT_MINIMIZED:
								// window has been deactivated
								break;

							case SDL_WINDOWEVENT_ENTER:
								// mouse cursor has entered window
								// for example default cursor can be disable
								// using SDL_ShowCursor(SDL_FALSE);
								break;

							case SDL_WINDOWEVENT_LEAVE:
								// mouse cursor has left window
								// for example default cursor can be disable
								// using SDL_ShowCursor(SDL_TRUE);
								break;

							case SDL_WINDOWEVENT_CLOSE:
								event.type = SDL_QUIT;
								break;
							default:
						}
						break;
					}
					default:
				}
			}

			// mouse update
			{
				while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_MOUSEMOTION, SDL_MOUSEWHEEL))
				{
					switch (event.type)
					{
					case SDL_MOUSEBUTTONDOWN:
						onMouseDown(event);
						// force redrawing
						mNeedToDraw = true;
						break;
					case SDL_MOUSEBUTTONUP:
						onMouseUp(event);
						// force redrawing
						mNeedToDraw = true;
						break;
					case SDL_MOUSEMOTION:
						onMouseMotion(event);
						// force redrawing
						mNeedToDraw = true;
						break;
					case SDL_MOUSEWHEEL:
						onMouseWheel(event);
						// force redrawing
						mNeedToDraw = true;
						break;
					default:
					}
				}
			}

			// keyboard update
			{
				while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_KEYDOWN, SDL_KEYUP))
				{
					switch (event.type)
					{
						case SDL_KEYDOWN:
							onKeyDown(event);
							// force redrawing
							mNeedToDraw = true;
							break;
						case SDL_KEYUP:
							onKeyUp(event);
							// force redrawing
							mNeedToDraw = true;
							break;
						default:
					}
				}
			}

			// text update
			{
				while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_TEXTINPUT, SDL_TEXTINPUT))
				{
					switch (event.type)
					{
						case SDL_TEXTINPUT:
							import core.stdc.string : strlen;
							auto len = strlen(&event.text.text[0]);
							if (!len)
								break;
							assert(len < event.text.text.sizeof);
							auto txt = event.text.text[0..len];
							import std.utf : byDchar;
							foreach(ch; txt.byDchar)
								super.keyboardCharacterEvent(ch);

							// force redrawing
							mNeedToDraw = true;
							break;
						default:
							break;
					}
				}
			}

			// user event, we use it as timer notification
			{
				while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_USEREVENT, SDL_USEREVENT))
				{
					switch (event.type)
					{
						case SDL_USEREVENT:
							// force redrawing
							mNeedToDraw = true;
							break;
						default:
							break;
					}
				}
			}

			// perform drawing if needed
			{
				import std.datetime : dur;

				currTime = Clock.currTime.stdTime;
				if (currTime - mBlinkingCursorTimestamp > dur!"msecs"(500).total!"hnsecs")
				{
					mBlinkingCursorVisible = !mBlinkingCursorVisible;
					mNeedToDraw = true;
					mBlinkingCursorTimestamp = currTime;
				}

				if (needToDraw)
				{
					size = Vector2i(width, height);
					super.draw(ctx);

					window.swapBuffers();
				}
				else
					SDL_Delay(1);
			}
		}
	}

	abstract void onVisibleForTheFirstTime();

	auto gl() { return _gl; }

protected:
	SDL2Window window;
	int width;
	int height;

	MouseButton btn;
	MouseAction action;
	int modifiers;

	Logger _log;
	OpenGL _gl;
	SDL2 _sdl2;

	NanoContext ctx;

	SDL_Cursor*[6] mCursorSet;

	public void onKeyDown(ref const(SDL_Event) event)
	{
		import nanogui.common : KeyAction;

		auto key = event.key.keysym.sym.convertSdlKeyToNanoguiKey;
		int modifiers = event.key.keysym.mod.convertSdlModifierToNanoguiModifier;
		super.keyboardEvent(key, event.key.keysym.scancode, KeyAction.Press, modifiers);
	}

	public void onKeyUp(ref const(SDL_Event) event)
	{
		
	}

	public void onMouseWheel(ref const(SDL_Event) event)
	{
		if (event.wheel.y > 0)
		{
			btn = MouseButton.WheelUp;
			super.scrollCallbackEvent(0, +1, Clock.currTime.stdTime);
		}
		else if (event.wheel.y < 0)
		{
			btn = MouseButton.WheelDown;
			super.scrollCallbackEvent(0, -1, Clock.currTime.stdTime);
		}
	}
	
	public void onMouseMotion(ref const(SDL_Event) event)
	{
		import gfm.sdl2 : SDL_BUTTON_LMASK, SDL_BUTTON_RMASK, SDL_BUTTON_MMASK;

		ctx.mouse.x = event.motion.x;
		ctx.mouse.y = event.motion.y;

		if (event.motion.state & SDL_BUTTON_LMASK)
			btn = MouseButton.Left;
		else if (event.motion.state & SDL_BUTTON_RMASK)
			btn = MouseButton.Right;
		else if (event.motion.state & SDL_BUTTON_MMASK)
			btn = MouseButton.Middle;

		if (event.motion.state & SDL_BUTTON_LMASK)
			modifiers |= MouseButton.Left;
		if (event.motion.state & SDL_BUTTON_RMASK)
			modifiers |= MouseButton.Right;
		if (event.motion.state & SDL_BUTTON_MMASK)
			modifiers |= MouseButton.Middle;

		action = MouseAction.Motion;
		super.cursorPosCallbackEvent(ctx.mouse.x, ctx.mouse.y, Clock.currTime.stdTime);
	}

	public void onMouseUp(ref const(SDL_Event) event)
	{
		import gfm.sdl2 : SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT, SDL_BUTTON_MIDDLE;

		switch(event.button.button)
		{
			case SDL_BUTTON_LEFT:
				btn = MouseButton.Left;
			break;
			case SDL_BUTTON_RIGHT:
				btn = MouseButton.Right;
			break;
			case SDL_BUTTON_MIDDLE:
				btn = MouseButton.Middle;
			break;
			default:
		}
		action = MouseAction.Release;
		super.mouseButtonCallbackEvent(btn, action, modifiers, Clock.currTime.stdTime);
	}

	public void onMouseDown(ref const(SDL_Event) event)
	{
		import gfm.sdl2 : SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT, SDL_BUTTON_MIDDLE;

		switch(event.button.button)
		{
			case SDL_BUTTON_LEFT:
				btn = MouseButton.Left;
			break;
			case SDL_BUTTON_RIGHT:
				btn = MouseButton.Right;
			break;
			case SDL_BUTTON_MIDDLE:
				btn = MouseButton.Middle;
			break;
			default:
		}
		action = MouseAction.Press;
		super.mouseButtonCallbackEvent(btn, action, modifiers, Clock.currTime.stdTime);
	}

	override void cursor(Cursor value)
	{
		mCursor = value;
		SDL_SetCursor(mCursorSet[mCursor]);
	}

	override Cursor cursor() const
	{
		return mCursor;
	}
}

private auto convertSdlKeyToNanoguiKey(int sdlkey)
{
	import gfm.sdl2;
	import nanogui.common : KeyAction, Key;

	int nanogui_key;
	switch(sdlkey)
	{
		case SDLK_LEFT:
			nanogui_key = Key.Left;
		break;
		case SDLK_RIGHT:
			nanogui_key = Key.Right;
		break;
		case SDLK_UP:
			nanogui_key = Key.Up;
		break;
		case SDLK_DOWN:
			nanogui_key = Key.Down;
		break;
		case SDLK_BACKSPACE:
			nanogui_key = Key.Backspace;
		break;
		case SDLK_DELETE:
			nanogui_key = Key.Delete;
		break;
		case SDLK_HOME:
			nanogui_key = Key.Home;
		break;
		case SDLK_END:
			nanogui_key = Key.End;
		break;
		case SDLK_RETURN:
			nanogui_key = Key.Enter;
		break;
		case SDLK_a:
			nanogui_key = Key.A;
		break;
		case SDLK_x:
			nanogui_key = Key.X;
		break;
		case SDLK_c:
			nanogui_key = Key.C;
		break;
		case SDLK_v:
			nanogui_key = Key.V;
		break;
		default:
			nanogui_key = sdlkey;
	}

	return nanogui_key;
}

private auto convertSdlModifierToNanoguiModifier(int mod)
{
	import gfm.sdl2;
	import nanogui.common : KeyMod;

	int nanogui_mod;

	if (mod & KMOD_LCTRL)
		nanogui_mod |= KeyMod.Ctrl;
	if (mod & KMOD_LSHIFT)
		nanogui_mod |= KeyMod.Shift;
	if (mod & KMOD_LALT)
		nanogui_mod |= KeyMod.Alt;
	if (mod & KMOD_RCTRL)
		nanogui_mod |= KeyMod.Ctrl;
	if (mod & KMOD_RSHIFT)
		nanogui_mod |= KeyMod.Shift;
	if (mod & KMOD_RALT)
		nanogui_mod |= KeyMod.Alt;

	return nanogui_mod;
}
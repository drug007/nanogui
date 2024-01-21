module nanogui.sdlapp;

import std.exception: enforce;

import std.experimental.logger: Logger, FileLogger, globalLogLevel, LogLevel;

import gfm.opengl: OpenGL;
import gfm.sdl2: SDL2, SDL2Window, SDL_Event, SDL_Cursor, SDL_SetCursor, 
	SDL_FreeCursor, SDL_Delay;

class SdlApp
{
	alias Event = SDL_Event;

	this(int w, int h, string title, int scale = 1)
	{
		/* Avoid locale-related number parsing issues */
		version(Windows) {}
		else {
			import core.stdc.locale;
			setlocale(LC_NUMERIC, "C");
		}

		import gfm.opengl : GLSupport, loadOpenGL;
		import bindbc.sdl : SDLSupport, sdlSupport, loadSDL, SDL_INIT_VIDEO, SDL_INIT_EVENTS,
			SDL_GL_SetAttribute, SDL_WINDOWPOS_UNDEFINED, SDL_GL_CONTEXT_MAJOR_VERSION,
			SDL_GL_CONTEXT_MINOR_VERSION,SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE,
			SDL_GL_STENCIL_SIZE, SDL_WINDOW_OPENGL, SDL_WINDOW_RESIZABLE, SDL_WINDOW_HIDDEN;

		this.width = w;
		this.height = h;
		_dirty = true;

		// create a logger
		import std.stdio : stdout;
		_log = new FileLogger(stdout);

		// load dynamic libraries
		SDLSupport ret = loadSDL();
		if(ret != sdlSupport) {
			if(ret == SDLSupport.noLibrary) {
				/*
				The system failed to load the library. Usually this means that either the library or one of its dependencies could not be found.
				*/
			}
			else if(SDLSupport.badLibrary) {
				/*
				This indicates that the system was able to find and successfully load the library, but one or more symbols the binding expected to find was missing. This usually indicates that the loaded library is of a lower API version than the binding was configured to load, e.g., an SDL 2.0.2 library loaded by an SDL 2.0.10 configuration.

				For many C libraries, including SDL, this is perfectly fine and the application can continue as long as none of the missing functions are called.
				*/
			}
		}
		_sdl2 = new SDL2(_log);
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
								width * scale, height * scale,
								SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN );

		window.setTitle(title);

		GLSupport retVal = loadOpenGL();
		if(retVal >= GLSupport.gl33)
		{
			// configure renderer for OpenGL 3.3
			import std.stdio;
			writefln("Available version of opengl: %s", retVal);
		}
		else
		{
			import std.stdio;
			if (retVal == GLSupport.noLibrary)
				writeln("opengl is not available");
			else
				writefln("Unsupported version of opengl %s", retVal);
			import std.exception;
			enforce(0);
		}

		_gl = new OpenGL(_log);

		// redirect OpenGL output to our Logger
		_gl.redirectDebugOutput();
	}

	~this()
	{
		_gl.destroy();
		window.destroy();
		_sdl2.destroy();
	}

	Logger logger() { return _log; }

	private void delegate () _onBeforeLoopStart;
	void onBeforeLoopStart(void delegate () dg)
	{
		_onBeforeLoopStart = dg;
	}
	auto onBeforeLoopStart() { return _onBeforeLoopStart; }

	alias OnDraw = void delegate();
	private OnDraw _onDraw;
	void onDraw(OnDraw handler)
	{
		_onDraw = handler;
	}
	auto onDraw() { return _onDraw; }

	alias OnResize = void delegate(int w, int h);
	private OnResize _onResize;
	void onResize(OnResize handler)
	{
		_onResize = handler;
	}
	auto onResize() { return _onResize; }

	alias OnKeyboardChar = bool delegate(dchar ch);
	private OnKeyboardChar _onKeyboardChar;
	void onKeyboardChar(OnKeyboardChar handler)
	{
		_onKeyboardChar = handler;
	}
	auto onKeyboardChar() { return _onKeyboardChar; }

	alias OnSdlEvent = bool delegate(ref const(SDL_Event) event);
	private OnSdlEvent _onKeyDown;
	void onKeyDown(OnSdlEvent handler)
	{
		_onKeyDown = handler;
	}
	auto onKeyDown() { return _onKeyDown; }

	private OnSdlEvent _onKeyUp;
	void onKeyUp(OnSdlEvent handler)
	{
		_onKeyUp = handler;
	}
	auto onKeyUp() { return _onKeyUp; }

	private OnSdlEvent _onMouseWheel;
	void onMouseWheel(OnSdlEvent handler)
	{
		_onMouseWheel = handler;
	}
	auto onMouseWheel() { return _onMouseWheel; }

	private OnSdlEvent _onMouseMotion;
	void onMouseMotion(OnSdlEvent handler)
	{
		_onMouseMotion = handler;
	}
	auto onMouseMotion() { return _onMouseMotion; }

	private OnSdlEvent _onMouseUp;
	void onMouseUp(OnSdlEvent handler)
	{
		_onMouseUp = handler;
	}
	auto onMouseUp() { return _onMouseUp; }

	private OnSdlEvent _onMouseDown;
	void onMouseDown(OnSdlEvent handler)
	{
		_onMouseDown = handler;
	}
	auto onMouseDown() { return _onMouseDown; }

	alias OnClose = bool delegate();
	private OnClose _onClose;
	void onClose(OnClose handler)
	{
		_onClose = handler;
	}
	auto onClose() { return _onClose; }

	private bool _running = true;
	void close() { _running = false; }

	void addHandler(alias currentHandler)(OnSdlEvent newHandler)
	{
		auto oldHandler = currentHandler;
		if (oldHandler)
		{
			currentHandler = (ref const(SDL_Event) event)
			{
				if (oldHandler(event))
					return true;
				return newHandler(event);
			};
		}
		else
		{
			currentHandler = newHandler;
		}
	}

	void invalidate()
	{
		_dirty = true;
	}

	void run()
	{
		import gfm.sdl2;

		window.hide;
		SDL_FlushEvents(SDL_WINDOWEVENT, SDL_SYSWMEVENT);

		window.show;

		SDL_Event event;

		while (_running)
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
								with(event.window)
								{
									width = data1;
									height = data2;
									if (_onResize)
										_onResize(width, height);
								}
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
								_running = (_onClose) ? !_onClose() : false;
								// if we continue running then update the screen
								// to improve responce time
								if (_running)
									invalidate;
								break;
							default:
						}
						break;
					}
					default:
				}
			}

			// mouse update
			while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_MOUSEMOTION, SDL_MOUSEWHEEL))
			{
				switch (event.type)
				{
				case SDL_MOUSEBUTTONDOWN:
					if (_onMouseDown)
						_onMouseDown(event);
					break;
				case SDL_MOUSEBUTTONUP:
					if (_onMouseUp)
						_onMouseUp(event);
					break;
				case SDL_MOUSEMOTION:
					if (_onMouseMotion)
						_onMouseMotion(event);
					break;
				case SDL_MOUSEWHEEL:
					if (_onMouseWheel)
						_onMouseWheel(event);
					break;
				default:
				}
			}

			// keyboard update
			while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_KEYDOWN, SDL_KEYUP))
			{
				switch (event.type)
				{
					case SDL_KEYDOWN:
						if (_onKeyDown)
							_onKeyDown(event);
						break;
					case SDL_KEYUP:
						if (_onKeyUp)
							_onKeyUp(event);
						break;
					default:
				}
			}

			// text update
			while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_TEXTINPUT, SDL_TEXTINPUT))
			{
				switch (event.type)
				{
					case SDL_TEXTINPUT:
						if (_onKeyboardChar is null)
							break;
						import core.stdc.string : strlen;
						auto len = strlen(&event.text.text[0]);
						if (!len)
							break;
						assert(len < event.text.text.sizeof);
						auto txt = event.text.text[0..len];
						import std.utf : byDchar;
						foreach(ch; txt.byDchar)
							_onKeyboardChar(ch);
						break;
					default:
						break;
				}
			}

			// user event, we use it as timer notification
			while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_USEREVENT, SDL_USEREVENT))
			{
				switch (event.type)
				{
					case SDL_USEREVENT:
						invalidate();
						break;
					default:
						break;
				}
			}

			// perform drawing if needed
			if (_dirty)
			{
				pauseTimeMs = 0;

				if (_onDraw)
					_onDraw();

				window.swapBuffers();
				_dirty = false;
			}
			else
			{
				pauseTimeMs = pauseTimeMs * 2 + 1; // exponential pause
				if (pauseTimeMs > 100)
					pauseTimeMs = 100; // max 100ms of pause
				SDL_Delay(pauseTimeMs);
			}
		}
	}

protected:
	SDL2Window window;
	int width;
	int height;
	bool _dirty;
	int pauseTimeMs;

	Logger _log;
	OpenGL _gl;
	SDL2 _sdl2;
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
		case SDLK_ESCAPE:
			nanogui_key = Key.Esc;
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

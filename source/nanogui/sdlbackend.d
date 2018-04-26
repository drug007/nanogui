module nanogui.sdlbackend;

import std.algorithm: map;
import std.array: array;
import std.exception: enforce;
import std.file: thisExePath;
import std.path: dirName, buildPath;
import std.range: iota;
import std.datetime : Clock;

import std.experimental.logger: Logger, NullLogger, FileLogger;

import gfm.math: mat4f, vec3f, vec4f;
import gfm.opengl: OpenGL, GLProgram, GLBuffer, VertexSpecification, GLVAO,
	glClearColor, glEnable, glBlendFunc, glDisable, glViewport, glClear,
	glDrawArrays, glDrawElements, glPointSize, 
	GL_ARRAY_BUFFER, GL_BLEND, GL_TRIANGLES, GL_POINTS, GL_STATIC_DRAW, 
	GL_COLOR_BUFFER_BIT, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_DEPTH_TEST,
	GL_DEPTH_BUFFER_BIT, GL_LINE_STRIP, GL_UNSIGNED_INT;
import gfm.sdl2: SDL2, SDL2Window, SDL_GL_SetAttribute, SharedLibVersion,
	SDL_Event,
	SDL_WINDOWPOS_UNDEFINED, SDL_INIT_VIDEO, SDL_GL_CONTEXT_MAJOR_VERSION,
	SDL_INIT_EVENTS, SDL_WINDOW_OPENGL, SDL_GL_CONTEXT_MINOR_VERSION,
	SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE, SDLK_ESCAPE,
	SDLK_LEFT, SDLK_RIGHT, SDLK_KP_PLUS, SDLK_KP_MINUS, SDLK_KP_MULTIPLY,
	SDL_WINDOW_FULLSCREEN_DESKTOP, SDL_BUTTON_LMASK, SDL_BUTTON_RMASK, 
	SDL_BUTTON_MMASK, SDL_QUIT, SDL_KEYDOWN, SDL_MOUSEBUTTONDOWN,
	SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION, SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT,
	SDL_BUTTON_MIDDLE, SDLK_SPACE, SDL_MOUSEWHEEL, SDL_KEYUP, SDL_GL_STENCIL_SIZE;

import arsd.nanovega : NVGContext, nvgCreateContext, kill, NVGContextFlag;
import nanogui.screen : Screen;
import nanogui.theme : Theme;
import nanogui.common : Vector2i, MouseButton, MouseAction;

class SdlBackend
{
	this(int w, int h, string title)
	{
		this.width = w;
		this.height = h;

		// create a logger
		import std.stdio : stdout;
		_log = new FileLogger(stdout);

		// load dynamic libraries
		_sdl2 = new SDL2(_log, SharedLibVersion(2, 0, 0));
		_gl = new OpenGL(_log); // отключаем лог, потому что на одной из машин
								// сыпется в консоль очень подробный лог

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
		
		import derelict.opengl3.gl3 : GLVersion;
		// reload OpenGL now that a context exists
		_gl.reload(GLVersion.GL30, GLVersion.HighestSupported);

		// redirect OpenGL output to our Logger
		_gl.redirectDebugOutput();

		nvg = nvgCreateContext(NVGContextFlag.Debug);
		enforce(nvg !is null, "cannot initialize NanoGui");

		screen = new Screen(width, height, Clock.currTime.stdTime);
		screen.theme = new Theme(nvg);
	}

	~this()
	{
		nvg.kill();
		_gl.destroy();
		window.destroy();
		_sdl2.destroy();
	}

	auto run()
	{
		import gfm.sdl2: SDL_GetTicks, SDL_QUIT, SDL_KEYDOWN, SDL_KEYDOWN, SDL_KEYUP, SDL_MOUSEBUTTONDOWN,
			SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION, SDL_MOUSEWHEEL, SDLK_ESCAPE;

		onVisibleForTheFirstTime();

		while(!_sdl2.keyboard.isPressed(SDLK_ESCAPE)) 
		{
			SDL_Event event;
			while(_sdl2.pollEvent(&event))
			{
				switch(event.type)
				{
					case SDL_QUIT:            return;
					case SDL_KEYDOWN:         onKeyDown(event);
					break;
					case SDL_KEYUP:           onKeyUp(event);
					break;
					case SDL_MOUSEBUTTONDOWN: onMouseDown(event);
					break;
					case SDL_MOUSEBUTTONUP:   onMouseUp(event);
					break;
					case SDL_MOUSEMOTION:     onMouseMotion(event);
					break;
					case SDL_MOUSEWHEEL:      onMouseWheel(event);
					break;
					default:
				}
			}

			screen.size = Vector2i(width, height);
			screen.draw(nvg);

			window.swapBuffers();
		}
	}

	abstract void onVisibleForTheFirstTime();

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

	NVGContext nvg;
	Screen screen;

	public void onKeyDown(ref const(SDL_Event) event)
	{
		import nanogui.common : KeyAction;
		int modifiers;
		screen.keyboardEvent(event.key.keysym.sym, event.key.keysym.scancode, KeyAction.Press, modifiers);
import std.stdio;
with(event.key.keysym)
	writefln("scancode: %s, sym: %s, mod: %s, unicode: %s", scancode, sym, mod, unicode);
		screen.keyboardCharacterEvent(event.key.keysym.sym);
	}

	public void onKeyUp(ref const(SDL_Event) event)
	{
		
	}

	public void onMouseWheel(ref const(SDL_Event) event)
	{
		if (event.wheel.y > 0)
		{
			btn = MouseButton.WheelUp;
			screen.scrollCallbackEvent(0, +1, Clock.currTime.stdTime);
		}
		else if (event.wheel.y < 0)
		{
			btn = MouseButton.WheelDown;
			screen.scrollCallbackEvent(0, -1, Clock.currTime.stdTime);
		}
	}
	
	public void onMouseMotion(ref const(SDL_Event) event)
	{
		auto mouse_x = event.motion.x;
		auto mouse_y = event.motion.y;

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
		screen.cursorPosCallbackEvent(mouse_x, mouse_y, Clock.currTime.stdTime);
	}

	public void onMouseUp(ref const(SDL_Event) event)
	{
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
		screen.mouseButtonCallbackEvent(btn, action, modifiers, Clock.currTime.stdTime);
	}

	public void onMouseDown(ref const(SDL_Event) event)
	{
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
		screen.mouseButtonCallbackEvent(btn, action, modifiers, Clock.currTime.stdTime);
	}
}

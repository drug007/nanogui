///
module nanogui.glfwbackend;

import std.datetime : Clock;
import std.exception : enforce;
import std.string : toStringz;
import std.format : format;

import derelict.opengl;
import derelict.glfw3.glfw3;
import arsd.nanovega;

import nanogui.screen : Screen;
import nanogui.theme : Theme;
import nanogui.common : Vector2i, Color, MouseButton, Cursor;

private __gshared Screen[GLFWwindow*] __nanogui_screens;

class GlfwBackend : Screen
{
	this(int w, int h, string title)
	{
		super(w, h, Clock.currStdTime);

		DerelictGL3.load();
		// Load the GLFW 3 library.
    	DerelictGLFW3.load();

		glfwSetErrorCallback(
			(error, descr) {
				import core.stdc.stdio : stderr, fprintf;
				if (error == GLFW_NOT_INITIALIZED)
					fprintf(stderr, "GLFW is not initialized!\n");
				else
					fprintf(stderr, "GLFW error %d: %s\n", error, descr);
			}
		);

		if (!glfwInit())
		{
			glfwTerminate();
			throw new Exception("Could not initialize GLFW!");
		}

		int  colorBits   = 8;
		int  alphaBits   = 8;
		int  depthBits   = 24;
		int  stencilBits = 8;
		int  nSamples    = 0;
		uint glMajor     = 3;
		uint glMinor     = 3;
		bool resizable   = true;
		bool fullscreen  = false;

		mBackground = Color(0.3f, 0.3f, 0.32f, 1.0f);

		/* Request a forward compatible OpenGL glMajor.glMinor core profile context.
		Default value is an OpenGL 3.3 core profile context. */
		glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, glMajor);
		glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, glMinor);
		glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
		glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

		glfwWindowHint(GLFW_SAMPLES, nSamples);
		glfwWindowHint(GLFW_RED_BITS, colorBits);
		glfwWindowHint(GLFW_GREEN_BITS, colorBits);
		glfwWindowHint(GLFW_BLUE_BITS, colorBits);
		glfwWindowHint(GLFW_ALPHA_BITS, alphaBits);
		glfwWindowHint(GLFW_STENCIL_BITS, stencilBits);
		glfwWindowHint(GLFW_DEPTH_BITS, depthBits);
		glfwWindowHint(GLFW_VISIBLE, GL_TRUE);
		glfwWindowHint(GLFW_RESIZABLE, resizable ? GL_TRUE : GL_FALSE);

		if (fullscreen) {
			GLFWmonitor *monitor = glfwGetPrimaryMonitor();
			const GLFWvidmode *mode = glfwGetVideoMode(monitor);
			mGLFWWindow = glfwCreateWindow(mode.width, mode.height,
										title.toStringz, monitor, null);
		} else {
			mGLFWWindow = glfwCreateWindow(w, h,
										title.toStringz, null, null);
		}

		if (!mGLFWWindow)
			throw new Exception(
				format("Could not create an OpenGL %d.%d context!", glMajor, glMinor));

		glfwMakeContextCurrent(mGLFWWindow);
		DerelictGL3.reload();

	// #if defined(NANOGUI_GLAD)
	// 	if (!gladInitialized) {
	// 		gladInitialized = true;
	// 		if (!gladLoadGLLoader((GLADloadproc) glfwGetProcAddress))
	// 			throw std::runtime_error("Could not initialize GLAD!");
	// 		glGetError(); // pull and ignore unhandled errors like GL_INVALID_ENUM
	// 	}
	// #endif

		glfwGetFramebufferSize(mGLFWWindow, &mFBSize[0], &mFBSize[1]);
		glViewport(0, 0, mFBSize[0], mFBSize[1]);
		glClearColor(mBackground[0], mBackground[1], mBackground[2], mBackground[3]);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
		glfwSwapInterval(0);
		glfwSwapBuffers(mGLFWWindow);

	// #if defined(__APPLE__)
	// 	/* Poll for events once before starting a potentially
	// 	lengthy loading process. This is needed to be
	// 	classified as "interactive" by other software such
	// 	as iTerm2 */

	// 	glfwPollEvents();
	// #endif

		{
			// extern(C) void callback(GLFWwindow *w, double x, double y) nothrow {
			// 	// auto it = __nanogui_screens.find(w);
			// 	// if (it == __nanogui_screens.end())
			// 	// 	return;
			// 	// Screen *s = it.second;
			// 	// if (!s.mProcessEvents)
			// 	// 	return;
			// 	// s.cursorPosCallbackEvent(x, y);
			// 	try
			// 	{
			// 		auto screen = __nanogui_screens.get(w, null);
			// 		if (screen is null)
			// 			return;
			// 		if (!screen.processEvents)
			// 			return;
			// 		screen.cursorPosCallbackEvent(x, y, Clock.currTime.stdTime);
			// 	}
			// 	catch(Exception e)
			// 	{
			// 		// do nothing
			// 	}
			// }

			/* Propagate GLFW events to the appropriate Screen instance */
			glfwSetCursorPosCallback(mGLFWWindow,
				(window, x, y) {
				// auto it = __nanogui_screens.find(w);
				// if (it == __nanogui_screens.end())
				// 	return;
				// Screen *s = it.second;
				// if (!s.mProcessEvents)
				// 	return;
				// s.cursorPosCallbackEvent(x, y);
				try
				{
					auto screen = __nanogui_screens.get(window, null);
					if (screen is null)
						return;
					if (!screen.processEvents)
						return;
					screen.cursorPosCallbackEvent(x, y, Clock.currTime.stdTime);
				}
				catch(Exception e)
				{
					// do nothing
				}
			}
			);
		}

		glfwSetMouseButtonCallback(mGLFWWindow,
			(w, button, action, modifiers) nothrow {
				// auto it = __nanogui_screens.find(w);
				// if (it == __nanogui_screens.end())
				// 	return;
				// Screen *s = it.second;
				// if (!s.mProcessEvents)
				// 	return;
				// s.mouseButtonCallbackEvent(button, action, modifiers);
			}
		);

	// 	glfwSetKeyCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, int key, int scancode, int action, int mods) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;
	// 			Screen *s = it.second;
	// 			if (!s.mProcessEvents)
	// 				return;
	// 			s.keyCallbackEvent(key, scancode, action, mods);
	// 		}
	// 	);

	// 	glfwSetCharCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, unsigned int codepoint) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;
	// 			Screen *s = it.second;
	// 			if (!s.mProcessEvents)
	// 				return;
	// 			s.charCallbackEvent(codepoint);
	// 		}
	// 	);

	// 	glfwSetDropCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, int count, const char **filenames) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;
	// 			Screen *s = it.second;
	// 			if (!s.mProcessEvents)
	// 				return;
	// 			s.dropCallbackEvent(count, filenames);
	// 		}
	// 	);

	// 	glfwSetScrollCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, double x, double y) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;
	// 			Screen *s = it.second;
	// 			if (!s.mProcessEvents)
	// 				return;
	// 			s.scrollCallbackEvent(x, y);
	// 		}
	// 	);

	// 	/* React to framebuffer size events -- includes window
	// 	size events and also catches things like dragging
	// 	a window from a Retina-capable screen to a normal
	// 	screen on Mac OS X */
	// 	glfwSetFramebufferSizeCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, int width, int height) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;
	// 			Screen *s = it.second;

	// 			if (!s.mProcessEvents)
	// 				return;

	// 			s.resizeCallbackEvent(width, height);
	// 		}
	// 	);

	// 	// notify when the screen has lost focus (e.g. application switch)
	// 	glfwSetWindowFocusCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, int focused) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;

	// 			Screen *s = it.second;
	// 			// focused: 0 when false, 1 when true
	// 			s.focusEvent(focused != 0);
	// 		}
	// 	);

		initialize();
	}

	void initialize()
	{
		mShutdownGLFWOnDestruct = true;
		glfwGetWindowSize(mGLFWWindow, &mSize[0], &mSize[1]);
		glfwGetFramebufferSize(mGLFWWindow, &mFBSize[0], &mFBSize[1]);
import std.stdio;

		mPixelRatio = get_pixel_ratio(mGLFWWindow);

	// #if defined(_WIN32) || defined(__linux__)
	// 	if (mPixelRatio != 1 && !mFullscreen)
	// 		glfwSetWindowSize(window, mSize.x() * mPixelRatio, mSize.y() * mPixelRatio);
	// #endif

	// #if defined(NANOGUI_GLAD)
	// 	if (!gladInitialized) {
	// 		gladInitialized = true;
	// 		if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
	// 			throw std::runtime_error("Could not initialize GLAD!");
	// 		glGetError(); // pull and ignore unhandled errors like GL_INVALID_ENUM
	// 	}
	// #endif

		/* Detect framebuffer properties and set up compatible NanoVG context */
		GLint nStencilBits = 8, nSamples = 0;
		glGetFramebufferAttachmentParameteriv(GL_DRAW_FRAMEBUFFER, 
			GL_STENCIL, GL_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE, &nStencilBits);
		glGetIntegerv(GL_SAMPLES, &nSamples);

		NVGContextFlag[] flags;
		if (nStencilBits >= 8)
			flags ~= NVGContextFlag.StencilStrokes;
		if (nSamples <= 1)
			flags ~= NVGContextFlag.Antialias;
		debug
			flags ~= NVGContextFlag.Debug;

		mNVGContext = nvgCreateContext(flags);
		if (!mNVGContext.valid)
			throw new Exception("Could not initialize NanoVG!");

		mVisible = glfwGetWindowAttrib(mGLFWWindow, GLFW_VISIBLE) != 0;
		mTheme = new Theme(mNVGContext);
		mMousePos = Vector2i(0, 0);
		mMouseState = MouseButton.None;
		mModifiers = 0;
		mDragActive = false;
		mLastInteraction = Clock.currStdTime;
		mProcessEvents = true;
		__nanogui_screens[mGLFWWindow] = this;

		for (int i=cast(int) Cursor.min; i < cast(int) Cursor.max; ++i)
			mCursors[i] = glfwCreateStandardCursor(GLFW_ARROW_CURSOR + i);

		onVisibleForTheFirstTime();
		/// Fixes retina display-related font rendering issue (#185)
		mNVGContext.beginFrame(size[0], size[1], mPixelRatio);
		mNVGContext.endFrame();
		glfwSwapBuffers(mGLFWWindow);
	}

	final void run()
	{
		if (mMainloopActive)
			throw new Exception("Main loop is already running!");

		mMainloopActive = true;

		import core.thread : Thread;
		Thread refresh_thread;
		// if (refresh > 0) 
		{
			/* If there are no mouse/keyboard events, try to refresh the
			view roughly every 50 ms (default); this is to support animations
			such as progress bars while keeping the system load
			reasonably low */
			refresh_thread = new Thread({
				import std.datetime : dur;
				auto time = dur!("msecs")(1500);
				while (mMainloopActive) {
					Thread.sleep(time);
					glfwPostEmptyEvent();
				}
			});
			refresh_thread.start();
		}

		try {
			while (mMainloopActive) {
				int numScreens = 0;

				foreach(k, v; __nanogui_screens)
				{
					auto screen = v;
					auto backend = cast(GlfwBackend) v;
					if (!screen.visible)
					{
						numScreens++;
						continue;
					}
					else if (backend && glfwWindowShouldClose(backend.mGLFWWindow))
					{
						screen.visible = false;
						continue;
					}
					// if (backend) 
					// {
					// 	// glfwMakeContextCurrent(backend.mGLFWWindow);
					// 	glClearColor(mBackground[0], mBackground[1], mBackground[2], mBackground[3]);
					// 	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

					// 	backend.draw(backend.mNVGContext);

					// 	glfwSwapBuffers(backend.mGLFWWindow);
					// }
					numScreens++;
				}

				if (numScreens == 0) {
					/* Give up if there was nothing to draw */
					mMainloopActive = false;
					break;
				}

				/* Wait for mouse/keyboard or empty refresh events */
				glfwWaitEvents();
			}

			/* Process events once more */
			glfwPollEvents();
		} 
		catch (Exception e)
		{
			import std.stdio : stderr;
			stderr.writeln("Caught exception in main loop: ", e.msg);
			mMainloopActive = false;
		}

		// if (refresh > 0)
		refresh_thread.join();
	}

	/// this is called just before our window will be shown for the first time.
	/// we must create NanoVega context here, as it needs to initialize
	/// internal OpenGL subsystem with valid OpenGL context.
	abstract void onVisibleForTheFirstTime();

	// override void visible(bool visible)
	// {
	// 	if (mVisible != visible) {
	// 		mVisible = visible;

	// 		if (visible)
	// 			glfwShowWindow(mGLFWWindow);
	// 		else
	// 			glfwHideWindow(mGLFWWindow);
	// 	}
	// }

	auto mScreen() { return cast(Screen) this; } //TODO this shouldn't be public

protected:
	NVGContext mNVGContext;
	GLFWwindow* mGLFWWindow;
	Vector2i mFBSize;
    Color mBackground;
	bool mShutdownGLFWOnDestruct;
	bool mMainloopActive;
	GLFWcursor*[Cursor.max-Cursor.min] mCursors;
}

/* Calculate pixel ratio for hi-dpi devices. */
private float get_pixel_ratio(GLFWwindow *window)
{
	return 1.0f;
}
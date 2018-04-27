///
module nanogui.glfwbackend;

import std.datetime : Clock;
import std.exception : enforce;
import std.string : toStringz;
import std.format : format;

import gfm.opengl;
import derelict.glfw3.glfw3;
import arsd.nanovega;

import nanogui.screen : Screen;
import nanogui.theme : Theme;
import nanogui.common : Vector2i;

class GlfwBackend
{
	this(int w, int h, string title)
	{
		// Load the GLFW 3 library.
    	DerelictGLFW3.load();

		int  colorBits   = 8;
		int  alphaBits   = 8;
		int  depthBits   = 24;
		int  stencilBits = 8;
		int  nSamples    = 0;
		uint glMajor     = 3;
		uint glMinor     = 0;
		bool resizable   = true;
		bool fullscreen  = false;

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
		glfwWindowHint(GLFW_VISIBLE, GL_FALSE);
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

	// // #if defined(NANOGUI_GLAD)
	// // 	if (!gladInitialized) {
	// // 		gladInitialized = true;
	// // 		if (!gladLoadGLLoader((GLADloadproc) glfwGetProcAddress))
	// // 			throw std::runtime_error("Could not initialize GLAD!");
	// // 		glGetError(); // pull and ignore unhandled errors like GL_INVALID_ENUM
	// // 	}
	// // #endif

	// 	glfwGetFramebufferSize(mGLFWWindow, &mFBSize[0], &mFBSize[1]);
	// 	glViewport(0, 0, mFBSize[0], mFBSize[1]);
	// 	glClearColor(mBackground[0], mBackground[1], mBackground[2], mBackground[3]);
	// 	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
	// 	glfwSwapInterval(0);
	// 	glfwSwapBuffers(mGLFWWindow);

	// #if defined(__APPLE__)
	// 	/* Poll for events once before starting a potentially
	// 	lengthy loading process. This is needed to be
	// 	classified as "interactive" by other software such
	// 	as iTerm2 */

	// 	glfwPollEvents();
	// #endif

	// 	/* Propagate GLFW events to the appropriate Screen instance */
	// 	glfwSetCursorPosCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, double x, double y) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;
	// 			Screen *s = it.second;
	// 			if (!s.mProcessEvents)
	// 				return;
	// 			s.cursorPosCallbackEvent(x, y);
	// 		}
	// 	);

	// 	glfwSetMouseButtonCallback(mGLFWWindow,
	// 		[](GLFWwindow *w, int button, int action, int modifiers) {
	// 			auto it = __nanogui_screens.find(w);
	// 			if (it == __nanogui_screens.end())
	// 				return;
	// 			Screen *s = it.second;
	// 			if (!s.mProcessEvents)
	// 				return;
	// 			s.mouseButtonCallbackEvent(button, action, modifiers);
	// 		}
	// 	);

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

	// 	initialize(mGLFWWindow, true);
	}

	final void run()
	{
		
	}

	/// this is called just before our window will be shown for the first time.
	/// we must create NanoVega context here, as it needs to initialize
	/// internal OpenGL subsystem with valid OpenGL context.
	abstract void onVisibleForTheFirstTime();

protected:
	NVGContext nvg;
	Screen screen;
	GLFWwindow *mGLFWWindow;
}
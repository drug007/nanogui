module nanogui.nanogui;

import arsd.nanovega;
public import gfm.math : vec2i;

import nanogui.widget : Widget;

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
}
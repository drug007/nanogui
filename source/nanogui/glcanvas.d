/*
    NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
    The widget drawing code is based on the NanoVG demo application
    by Mikko Mononen.

    All rights reserved. Use of this source code is governed by a
    BSD-style license that can be found in the LICENSE.txt file.
*/
/**
 * \file nanogui/glcanvas.h
 *
 * \brief Canvas widget for rendering OpenGL content.  This widget was
 *        contributed by Jan Winkler.
 */

import nanogui.widget;
// #include <nanogui/opengl.h>
// #include <nanogui/glutil.h>

/**
 * \class GLCanvas glcanvas.d
 *
 * \brief Canvas widget for rendering OpenGL content.  This widget was
 *        contributed by Jan Winkler.
 *
 * Canvas widget that can be used to display arbitrary OpenGL content. This is
 * useful to display and manipulate 3D objects as part of an interactive
 * application. The implementation uses scissoring to ensure that rendered
 * objects don't spill into neighboring widgets.
 *
 * \rst
 * **Usage**
 *     Override :func:`nanogui.GLCanvas.drawGL` in subclasses to provide
 *     custom drawing code.
 *
 * \endrst
 */
class GLCanvas : Widget
{
	import nanogui.common : Vector2f, Vector2i, Vector4i;	
public:
    /**
     * Creates a GLCanvas attached to the specified parent.
     *
     * \param parent
     *     The Widget to attach this GLCanvas to.
     */
    this(Widget parent)
	{
		super(parent);
		mBackgroundColor = Vector4i(128, 128, 128, 255);
		mDrawBorder = true;
		mSize = Vector2i(250, 250);
	}

    /// Returns the background color.
    final const(Color) backgroundColor() const { return mBackgroundColor; }

    /// Sets the background color.
    final void backgroundColor(const Color backgroundColor) { mBackgroundColor = backgroundColor; }

    /// Set whether to draw the widget border or not.
    final void drawBorder(const bool bDrawBorder) { mDrawBorder = bDrawBorder; }

    /// Return whether the widget border gets drawn or not.
    bool drawBorder() const { return mDrawBorder; }

    /// Draw the canvas.
    override void draw(NanoContext ctx)
	{
		Widget.draw(ctx);

		if (mDrawBorder)
			drawWidgetBorder(ctx);

		ctx.endFrame;

		const screen = this.screen();
		assert(screen);

		float pixelRatio = screen.pixelRatio;
		auto screenSize = cast(Vector2f) screen.size;
		Vector2i positionInScreen = absolutePosition;

		auto size = cast(Vector2i)(cast(Vector2f)mSize * pixelRatio);
		auto imagePosition = cast(Vector2i)(Vector2f(positionInScreen[0],
			screenSize[1] - positionInScreen[1] -
			cast(float) mSize[1]) * pixelRatio);

		import gfm.opengl;
		GLint[4] storedViewport;
		glGetIntegerv(GL_VIEWPORT, storedViewport.ptr);

		glViewport(imagePosition[0], imagePosition[1], size[0] , size[1]);

		glEnable(GL_SCISSOR_TEST);
		glScissor(imagePosition[0], imagePosition[1], size[0], size[1]);
		glClearColor(mBackgroundColor[0], mBackgroundColor[1],
					mBackgroundColor[2], mBackgroundColor[3]);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

		this.drawGL();

		glDisable(GL_SCISSOR_TEST);
		glViewport(storedViewport[0], storedViewport[1],
				storedViewport[2], storedViewport[3]);

		ctx.beginFrame(screen.size.x, screen.size.y);
	}

    /// Draw the GL scene. Override this method to draw the actual GL content.
    void drawGL() {}

    // /// Save the state of this GLCanvas to the specified Serializer.
    // virtual void save(Serializer &s) const override;

    // /// Set the state of this GLCanvas from the specified Serializer.
    // virtual bool load(Serializer &s) override;

protected:
    /// Internal helper function for drawing the widget border
    void drawWidgetBorder(NanoContext ctx) const
	{
		// import arsd.nanovega;
		ctx.beginPath;
		ctx.strokeWidth(1.0f);
		ctx.roundedRect(mPos.x - 0.5f, mPos.y - 0.5f,
					mSize.x + 1, mSize.y + 1, mTheme.mWindowCornerRadius);
		ctx.strokeColor(mTheme.mBorderLight);
		ctx.roundedRect(mPos.x - 1.0f, mPos.y - 1.0f,
					mSize.x + 2, mSize.y + 2, mTheme.mWindowCornerRadius);
		ctx.strokeColor(mTheme.mBorderDark);
		ctx.stroke;
	}

protected:
    /// The background color (what is used with ``glClearColor``).
    Color mBackgroundColor;

    /// Whether to draw the widget border or not.
    bool mDrawBorder;

}

module nanogui.glcanvas;
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
    this(Widget parent, int w, int h)
	{
		super(parent);
		mBackgroundColor = Vector4i(128, 128, 128, 255);
		mDrawBorder = true;
		mSize = Vector2i(w, h);
		lastWidth = w;
		lastHeight = h;

		initBuffers;

		screen.addGLCanvas(this);
	}

	~this()
	{
		screen.removeGLCanvas(this);
		releaseBuffers;
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
    override void draw(ref NanoContext ctx)
	{
		Widget.draw(ctx);

		if (mDrawBorder)
			drawWidgetBorder(ctx);

		const scale = screen.scale; // TODO PERFORMANCE it can be expensive operation
		auto mImage = glCreateImageFromOpenGLTexture(ctx, mColorBuf.handle, width, height, NVGImageFlag.NoDelete);
		assert(mImage.valid);
		auto mPaint = ctx.imagePattern(
			mPos.x + 1,
			mPos.y + 1.0f,
			mSize.x/scale - 2,
			mSize.y/scale - 2,
			0,
			mImage);

		ctx.beginPath;
		ctx.rect(
			mPos.x + 1,
			mPos.y + 1.0f,
			mSize.x - 2,
			mSize.y - 2
		);
		ctx.fillPaint(mPaint);
		ctx.fill;
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

import gfm.opengl : GLTexture2D, GLFBO, GL_LINEAR_MIPMAP_LINEAR, GL_LINEAR,
	GL_CLAMP_TO_EDGE, GL_RGBA, GL_UNSIGNED_BYTE, glClear, GL_COLOR_BUFFER_BIT,
	GL_DEPTH_BUFFER_BIT, GL_STENCIL_BUFFER_BIT, GLRenderBuffer, GL_DEPTH_COMPONENT;

    /// The background color (what is used with ``glClearColor``).
    Color mBackgroundColor;

    /// Whether to draw the widget border or not.
    bool mDrawBorder;
	GLTexture2D mColorBuf;
	GLRenderBuffer mDepthBuf;

package:
	GLFBO mFbo;
	int lastWidth, lastHeight;

	void initBuffers()
	{
		mColorBuf = new GLTexture2D();
		mColorBuf.setMinFilter(GL_LINEAR_MIPMAP_LINEAR);
		mColorBuf.setMagFilter(GL_LINEAR);
		mColorBuf.setWrapS(GL_CLAMP_TO_EDGE);
		mColorBuf.setWrapT(GL_CLAMP_TO_EDGE);
		mColorBuf.setImage(0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
		mColorBuf.generateMipmap();

		mDepthBuf = new GLRenderBuffer(GL_DEPTH_COMPONENT, width, height);

		mFbo = new GLFBO();
		mFbo.use();
		mFbo.color(0).attach(mColorBuf);
		mFbo.depth.attach(mDepthBuf);
		mFbo.unuse();
	}

	void releaseBuffers()
	{
		mFbo.destroy();
		mDepthBuf.destroy();
		mColorBuf.destroy();
	}
}

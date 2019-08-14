///
module nanogui.textbox;

/*
	nanogui.textbox.d -- Fancy text box with builtin regular
	expression-based validation

	The text box widget was contributed by Christian Schueller.

	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/

import std.array : replaceInPlace;
import std.algorithm : swap;
import std.math : abs;
import std.traits : isIntegral, isFloatingPoint, isSigned;

import arsd.nanovega;
import nanogui.widget : Widget;
import nanogui.theme : Theme;
import nanogui.common : Vector2i, MouseAction, MouseButton, Cursor, 
    Color, boxGradient, fillColor, Vector2f, Key, KeyAction, KeyMod,
	NanoContext;

private auto squeezeGlyphs(T)(T[] glyphs_buffer, T[] glyphs)
{
    import std.algorithm : uniq;
    size_t i;
    foreach(e; glyphs.uniq!"a.x==b.x")
        glyphs_buffer[i++] = e;

    return glyphs_buffer[0..i];
}

/**
 * Fancy text box with builtin regular expression-based validation.
 *
 * Remark:
 *     This class overrides `nanogui.Widget.mIconExtraScale` to be `0.8f`,
 *     which affects all subclasses of this Widget.  Subclasses must explicitly
 *     set a different value if needed (e.g., in their constructor).
 */
class TextBox : Widget
{
public:
	/// How to align the text in the text box.
	enum Alignment {
		Left,
		Center,
		Right
	};

	this(Widget parent, string value = "Untitled")
	{
		super(parent);
		mEditable  = false;
		mSpinnable = false;
		mCommitted = true;
		mValue     = value;
		mDefaultValue = "";
		mAlignment = Alignment.Center;
		mUnits = "";
		mFormat = "";
		mUnitsImage = NVGImage();
		mValidFormat = true;
		mValueTemp = value;
		mCursorPos = -1;
		mSelectionPos = -1;
		mMousePos = Vector2i(-1,-1);
		mMouseDownPos = Vector2i(-1,-1);
		mMouseDragPos = Vector2i(-1,-1);
		mMouseDownModifier = 0;
		mTextOffset = 0;
		mLastClick = 0;
		if (mTheme) mFontSize = mTheme.mTextBoxFontSize;
		mIconExtraScale = 0.8f;// widget override
	}

	bool editable() const { return mEditable; }
	final void editable(bool editable)
	{
		mEditable = editable;
		cursor = editable ? Cursor.IBeam : Cursor.Arrow;
	}

	final bool spinnable() const { return mSpinnable; }
	final void spinnable(bool spinnable) { mSpinnable = spinnable; }

	final string value() const { return mValue; }
	final void value(string value) { mValue = value; }

	final string defaultValue() const { return mDefaultValue; }
	final void defaultValue(string defaultValue) { mDefaultValue = defaultValue; }

	final Alignment alignment() const { return mAlignment; }
	final void alignment(Alignment al) { mAlignment = al; }

	final string units() const { return mUnits; }
	final void units(string units) { mUnits = units; }

	final auto unitsImage() const { return mUnitsImage; }
	final void unitsImage(NVGImage image) { mUnitsImage = image; }

	/// Return the underlying regular expression specifying valid formats
	final string format() const { return mFormat; }
	/// Specify a regular expression specifying valid formats
	final void format(string format) { mFormat = format; }

	/// Return the placeholder text to be displayed while the text box is empty.
	final string placeholder() const { return mPlaceholder; }
	/// Specify a placeholder text to be displayed while the text box is empty.
	final void placeholder(string placeholder) { mPlaceholder = placeholder; }

	/// Set the `Theme` used to draw this widget
	override void theme(Theme theme)
	{
		Widget.theme(theme);
		if (mTheme)
			mFontSize = mTheme.mTextBoxFontSize;
	}

	/// The callback to execute when the value of this TextBox has changed.
	final bool delegate(string str) callback() const { return mCallback; }

	/// Sets the callback to execute when the value of this TextBox has changed.
	final void callback(bool delegate(string str) callback) { mCallback = callback; }

	override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
    {
        if (button == MouseButton.Left && down && !mFocused)
        {
            if (!mSpinnable || spinArea(p) == SpinArea.None) /* not on scrolling arrows */
                requestFocus();
        }

        if (mEditable && focused)
        {
            if (down)
            {
                mMouseDownPos = p;
                mMouseDownModifier = modifiers;

// double time = glfwGetTime();
// if (time - mLastClick < 0.25) {
//     /* Double-click: select all text */
//     mSelectionPos = 0;
//     mCursorPos = (int) mValueTemp.size();
//     mMouseDownPos = Vector2i(-1, -1);
// }
// mLastClick = time;
            }
            else
            {
                mMouseDownPos = Vector2i(-1, -1);
                mMouseDragPos = Vector2i(-1, -1);
            }
            return true;
        }
        else if (mSpinnable && !focused)
        {
            if (down)
            {
                if (spinArea(p) == SpinArea.None)
                {
                    mMouseDownPos = p;
                    mMouseDownModifier = modifiers;

// double time = glfwGetTime();
// if (time - mLastClick < 0.25) {
//     /* Double-click: reset to default value */
//     mValue = mDefaultValue;
//     if (mCallback)
//         mCallback(mValue);

//     mMouseDownPos = Vector2i(-1, -1);
// }
// mLastClick = time;
                }
                else
                {
                    mMouseDownPos = Vector2i(-1, -1);
                    mMouseDragPos = Vector2i(-1, -1);
                }
            }
            else
            {
                mMouseDownPos = Vector2i(-1, -1);
                mMouseDragPos = Vector2i(-1, -1);
            }
            return true;
        }

        return false;
    }

	override bool mouseMotionEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
    {
        mMousePos = p;

        if (!mEditable)
            cursor = Cursor.Arrow;
        else if (mSpinnable && !focused && spinArea(mMousePos) != SpinArea.None) /* scrolling arrows */
            cursor = Cursor.Hand;
        else
            cursor = Cursor.IBeam;

        if (mEditable && focused)
        {
            return true;
        }
        return false;
    }

	override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
    {
        mMousePos = p;
        mMouseDragPos = p;

        if (mEditable && focused)
            return true;

        return false;
    }

	override bool focusEvent(bool focused)
    {
        super.focusEvent(focused);

        string backup = mValue;

        if (mEditable)
        {
            if (focused)
            {
                mValueTemp = mValue;
                mCommitted = false;
                mCursorPos = 0;
            }
            else
            {
                if (mValidFormat)
                {
                    if (mValueTemp == "")
                        mValue = mDefaultValue;
                    else
                        mValue = mValueTemp;
                }

                if (mCallback && !mCallback(mValue))
                    mValue = backup;

                mValidFormat = true;
                mCommitted = true;
                mCursorPos = -1;
                mSelectionPos = -1;
                mTextOffset = 0;
            }

            mValidFormat = (mValueTemp == "") || checkFormat(mValueTemp, mFormat);
        }

        return true;
    }

	override bool keyboardEvent(int key, int scancode, KeyAction action, int modifiers)
    {
        if (mEditable && focused)
        {
            if (action == KeyAction.Press || action == KeyAction.Repeat)
            {
                import std.uni : byGrapheme;
                import std.range : walkLength;

                if (key == Key.Left)
                {
                    if (modifiers == KeyMod.Shift)
                    {
                        if (mSelectionPos == -1)
                            mSelectionPos = mCursorPos;
                    }
                    else
                        mSelectionPos = -1;

                    if (mCursorPos > 0)
                        mCursorPos--;
                }
                else if (key == Key.Right)
                {
                    if (modifiers == KeyMod.Shift)
                    {
                        if (mSelectionPos == -1)
                            mSelectionPos = mCursorPos;
                    }
                    else
                        mSelectionPos = -1;

                    if (mCursorPos < cast(int) mValueTemp.byGrapheme.walkLength)
                        mCursorPos++;
                }
                else if (key == Key.Home)
                {
                    if (modifiers == KeyMod.Shift)
                    {
                        if (mSelectionPos == -1)
                            mSelectionPos = mCursorPos;
                    }
                    else
                        mSelectionPos = -1;

                    mCursorPos = 0;
                }
                else if (key == Key.End)
                {
                    if (modifiers == KeyMod.Shift)
                    {
                        if (mSelectionPos == -1)
                            mSelectionPos = mCursorPos;
                    }
                    else
                        mSelectionPos = -1;

                    mCursorPos = cast(int) mValueTemp.byGrapheme.walkLength;
                }
                else if (key == Key.Backspace)
                {
                    if (!deleteSelection())
                    {
                        if (mCursorPos > 0)
                        {
                            auto begin = symbolLengthToBytes(mValueTemp, mCursorPos - 1);
                            auto end   = symbolLengthToBytes(mValueTemp, mCursorPos);
                            mValueTemp.replaceInPlace(begin, end, (char[]).init);
                            mCursorPos--;
                        }
                    }
                }
                else if (key == Key.Delete)
                {
                    if (!deleteSelection())
                    {
                        if (mCursorPos < cast(int) mValueTemp.byGrapheme.walkLength)
                        {
                            auto begin = symbolLengthToBytes(mValueTemp, mCursorPos);
                            auto end   = symbolLengthToBytes(mValueTemp, mCursorPos+1);
                            mValueTemp.replaceInPlace(begin, end, (char[]).init);
                        }
                    }
                }
                else if (key == Key.Enter)
                {
                    if (!mCommitted)
                        focusEvent(false);
                }
                else if (key == Key.A && modifiers == KeyMod.Ctrl)
                {
                    mCursorPos = cast(int) mValueTemp.byGrapheme.walkLength;
                    mSelectionPos = 0;
                }
                else if (key == Key.X && modifiers == KeyMod.Ctrl)
                {
                    copySelection();
                    deleteSelection();
                }
                else if (key == Key.C && modifiers == KeyMod.Ctrl)
                {
                    copySelection();
                }
                else if (key == Key.V && modifiers == KeyMod.Ctrl)
                {
                    deleteSelection();
                    pasteFromClipboard();
                }

                mValidFormat =
                    (mValueTemp == "") || checkFormat(mValueTemp, mFormat);
            }

            return true;
        }

        return false;
    }

	/// converts length in symbols to length in bytes
    private auto symbolLengthToBytes(string txt, size_t count)
    {
        import std.uni : graphemeStride;
        size_t pos; // current position in string
        size_t total_len; // length of pos symbols in bytes
        while(total_len != txt.length && pos < count)
        {
            assert(total_len <= txt.length);
            // get length of the current graphem in bytes
            auto len = graphemeStride(txt, total_len);
            total_len += len;
            pos++;
        }
        return total_len;
    }

	override bool keyboardCharacterEvent(dchar codepoint)
    {
        if (mEditable && focused)
        {
            deleteSelection();
            import std.conv : to;
            auto replacement = codepoint.to!string;
            auto pos = symbolLengthToBytes(mValueTemp, mCursorPos);
            mValueTemp = mValueTemp[0..pos] ~ 
                         replacement ~ 
                         mValueTemp[pos..$];
            mCursorPos++;

            mValidFormat = (mValueTemp == "") || checkFormat(mValueTemp, mFormat);

            return true;
        }

        return false;
    }

	override Vector2i preferredSize(NanoContext ctx) const
	{
		Vector2i size = Vector2i(0, cast(int) (fontSize * 1.4f));

		float uw = 0;
		if (mUnitsImage.valid) 
		{
			int w, h;
			ctx.imageSize(mUnitsImage, w, h);
			float uh = size[1] * 0.4f;
			uw = w * uh / h;
		} else if (mUnits.length)
		{
			uw = ctx.textBounds(0, 0, mUnits, null);
		}
		float sw = 0;
		if (mSpinnable)
			sw = 14.0f;

		float ts = ctx.textBounds(0, 0, mValue, null);
		size[0] = size[1] + cast(int)(ts + uw + sw);
		return size;
	}

	override void draw(NanoContext ctx)
    {
        super.draw(ctx);

        NVGPaint bg = ctx.boxGradient(
            mPos.x + 1, mPos.y + 1 + 1.0f, mSize.x - 2, mSize.y - 2,
            3, 4, Color(255, 255, 255, 32), Color(32, 32, 32, 32));
        NVGPaint fg1 = ctx.boxGradient(
            mPos.x + 1, mPos.y + 1 + 1.0f, mSize.x - 2, mSize.y - 2,
            3, 4, Color(150, 150, 150, 32), Color(32, 32, 32, 32));
        NVGPaint fg2 = ctx.boxGradient(
            mPos.x + 1, mPos.y + 1 + 1.0f, mSize.x - 2, mSize.y - 2,
            3, 4, Color(255, 0, 0, 100), Color(255, 0, 0, 50));

        ctx.beginPath;
        ctx.roundedRect(mPos.x + 1, mPos.y + 1 + 1.0f, mSize.x - 2,
                    mSize.y - 2, 3);

        if (mEditable && focused)
            mValidFormat ? ctx.fillPaint(fg1) : ctx.fillPaint(fg2);
        else if (mSpinnable && mMouseDownPos.x != -1)
            ctx.fillPaint(fg1);
        else
            ctx.fillPaint(bg);

        ctx.fill;

        ctx.beginPath;
        ctx.roundedRect(mPos.x + 0.5f, mPos.y + 0.5f, mSize.x - 1,
                    mSize.y - 1, 2.5f);
        ctx.strokeColor(NVGColor(0, 0, 0, 48));
        ctx.stroke;

        ctx.fontSize(fontSize());
        if (mTheme !is null)
            ctx.fontFaceId(mTheme.mFontNormal);
        else
            ctx.fontFace("sans");

        auto draw_pos = Vector2i(mPos.x, cast(int) (mPos.y + mSize.y * 0.5f + 1));

        float xSpacing = mSize.y * 0.3f;

        float unitWidth = 0;

        if (mUnitsImage.valid)
        {
            int w, h;
            ctx.imageSize(mUnitsImage, w, h);
            float unitHeight = mSize.y * 0.4f;
            unitWidth = w * unitHeight / h;
            NVGPaint imgPaint = ctx.imagePattern(
                mPos.x + mSize.x - xSpacing - unitWidth,
                draw_pos.y - unitHeight * 0.5f, unitWidth, unitHeight, 0,
                mUnitsImage, mEnabled ? 0.7f : 0.35f);
            ctx.beginPath;
            ctx.rect(mPos.x + mSize.x - xSpacing - unitWidth,
                    draw_pos.y - unitHeight * 0.5f, unitWidth, unitHeight);
            ctx.fillPaint(imgPaint);
            ctx.fill;
            unitWidth += 2;
        }
        else if (mUnits.length)
        {
            unitWidth = ctx.textBounds(0, 0, mUnits, null);
            ctx.fillColor(Color(255, 255, 255, mEnabled ? 64 : 32));
            NVGTextAlign algn;
			algn.right = true;
			algn.middle = true;
			ctx.textAlign(algn);
            ctx.text(mPos.x + mSize.x - xSpacing, draw_pos.y,
                    mUnits);
            unitWidth += 2;
        }

        float spinArrowsWidth = 0.0f;

        if (mSpinnable && !focused()) {
            spinArrowsWidth = 14.0f;

            ctx.fontFace("icons");
            ctx.fontSize(((mFontSize < 0) ? mTheme.mButtonFontSize : mFontSize) * icon_scale());

            bool spinning = mMouseDownPos.x != -1;

            /* up button */ {
                bool hover = mMouseFocus && spinArea(mMousePos) == SpinArea.Top;
                ctx.fillColor((mEnabled && (hover || spinning)) ? mTheme.mTextColor : mTheme.mDisabledTextColor);
                auto icon = mTheme.mTextBoxUpIcon;
                NVGTextAlign algn;
                algn.left = true;
                algn.middle = true;
                ctx.textAlign(algn);
                auto iconPos = Vector2f(mPos.x + 4.0f,
                                mPos.y + mSize.y/2.0f - xSpacing/2.0f);
                ctx.text(iconPos.x, iconPos.y, [icon]);
            }

            /* down button */ {
                bool hover = mMouseFocus && spinArea(mMousePos) == SpinArea.Bottom;
                ctx.fillColor((mEnabled && (hover || spinning)) ? mTheme.mTextColor : mTheme.mDisabledTextColor);
                auto icon = mTheme.mTextBoxDownIcon;
                NVGTextAlign algn;
                algn.left = true;
                algn.middle = true;
                ctx.textAlign(algn);
                auto iconPos = Vector2f(mPos.x + 4.0f,
                                mPos.y + mSize.y/2.0f + xSpacing/2.0f + 1.5f);
                ctx.text(iconPos.x, iconPos.y, [icon]);
            }

            ctx.fontSize(fontSize());
            ctx.fontFace("sans");
        }

        final switch (mAlignment) {
            case Alignment.Left:
                NVGTextAlign algn;
                algn.left = true;
                algn.middle = true;
                ctx.textAlign(algn);
                draw_pos.x += cast(int)(xSpacing + spinArrowsWidth);
                break;
            case Alignment.Right:
                NVGTextAlign algn;
                algn.right = true;
                algn.middle = true;
                ctx.textAlign(algn);
                draw_pos.x += cast(int)(mSize.x - unitWidth - xSpacing);
                break;
            case Alignment.Center:
                NVGTextAlign algn;
                algn.center = true;
                algn.middle = true;
                ctx.textAlign(algn);
                draw_pos.x += cast(int)(mSize.x * 0.5f);
                break;
        }

        ctx.fontSize(fontSize());
        ctx.fillColor(mEnabled && (!mCommitted || mValue.length) ?
            mTheme.mTextColor :
            mTheme.mDisabledTextColor);

        // clip visible text area
        float clipX = mPos.x + xSpacing + spinArrowsWidth - 1.0f;
        float clipY = mPos.y + 1.0f;
        float clipWidth = mSize.x - unitWidth - spinArrowsWidth - 2 * xSpacing + 2.0f;
        float clipHeight = mSize.y - 3.0f;

        ctx.save;
        ctx.intersectScissor(clipX, clipY, clipWidth, clipHeight);

        auto old_draw_pos = Vector2i(draw_pos);
        draw_pos.x += cast(int) mTextOffset;

        if (mCommitted) {
            ctx.text(draw_pos.x, draw_pos.y,
                !mValue.length ? mPlaceholder : mValue);
        } else {
            const int maxGlyphs = 1024;
            NVGGlyphPosition[maxGlyphs] glyphs_buffer;
            float[4] textBound;
            ctx.textBounds(draw_pos.x, draw_pos.y, mValueTemp,
                        textBound);
            float lineh = textBound[3] - textBound[1];

            // find cursor positions
            auto glyphs =
                ctx.textGlyphPositions(draw_pos.x, draw_pos.y,
                                    mValueTemp, glyphs_buffer);
            glyphs = squeezeGlyphs(glyphs_buffer[], glyphs);
            updateCursor(ctx, textBound[2], glyphs);

            // compute text offset
            int prevCPos = mCursorPos > 0 ? mCursorPos - 1 : 0;
            int len = cast(int) glyphs.length;
            int nextCPos = mCursorPos < len ? mCursorPos + 1 : len;
            float prevCX = cursorIndex2Position(prevCPos, textBound[2], glyphs);
            float nextCX = cursorIndex2Position(nextCPos, textBound[2], glyphs);

            if (nextCX > clipX + clipWidth)
                mTextOffset -= nextCX - (clipX + clipWidth) + 1;
            if (prevCX < clipX)
                mTextOffset += clipX - prevCX + 1;

            draw_pos.x = cast(int) (old_draw_pos.x + mTextOffset);

            // draw text with offset
            ctx.text(draw_pos.x, draw_pos.y, mValueTemp);
            ctx.textBounds(draw_pos.x, draw_pos.y, mValueTemp, textBound);

            // recompute cursor positions
            glyphs = ctx.textGlyphPositions(draw_pos.x, draw_pos.y,
                    mValueTemp, glyphs_buffer);
            glyphs = squeezeGlyphs(glyphs_buffer[], glyphs);

            if (mCursorPos > -1) {
                if (mSelectionPos > -1) {
                    float caretx = cursorIndex2Position(mCursorPos, textBound[2],
                                                        glyphs);
                    float selx = cursorIndex2Position(mSelectionPos, textBound[2],
                                                    glyphs);

                    if (caretx > selx)
                    {
                        swap(caretx, selx);
                    }

                    // draw selection
                    ctx.beginPath;
                    ctx.fillColor(Color(255, 255, 255, 80));
                    ctx.rect(caretx, draw_pos.y - lineh * 0.5f, selx - caretx,
                            lineh);
                    ctx.fill;
                }

                float caretx = cursorIndex2Position(mCursorPos, textBound[2], glyphs);

                // draw cursor
                ctx.beginPath;
                ctx.moveTo(caretx, draw_pos.y - lineh * 0.5f);
                ctx.lineTo(caretx, draw_pos.y + lineh * 0.5f);
                ctx.strokeColor(nvgRGBA(255, 192, 0, 255));
                ctx.strokeWidth(1.0f);
                ctx.stroke;
            }
        }
        ctx.restore;
    }

// override void save(Serializer &s) const;
// override bool load(Serializer &s);
protected:

    // hide method
    override void cursor(Cursor value)
    {
        super.cursor(value);
    }

	bool checkFormat(string input, string format)
    {
        if (!format.length)
            return true;
        // try
        // {
            import std.regex : regex, matchAll;
            import std.range : walkLength;
            auto r = regex(format);
            auto ma = input.matchAll(r);
            return ma.walkLength == 1;
        // }
        // catch (RegexException)
        // {
        //     throw;
        // }
    }

	bool copySelection()
    {
        import nanogui.screen : Screen;
        if (mSelectionPos > -1) {
            Screen sc = cast(Screen) (window.parent);
            if (!sc)
                return false;

            int begin = mCursorPos;
            int end = mSelectionPos;

            if (begin > end)
                swap(begin, end);

// glfwSetClipboardString(sc->glfwWindow(),
//                     mValueTemp.substr(begin, end).c_str());
            return true;
        }

        return false;
    }

	void pasteFromClipboard()
    {
        import nanogui.screen : Screen;
        Screen sc = cast(Screen) (window.parent);
        if (!sc)
            return;
        // const char* cbstr = glfwGetClipboardString(sc->glfwWindow());
        // if (cbstr)
        //     mValueTemp.insert(mCursorPos, std::string(cbstr));
    }
	bool deleteSelection()
    {
        if (mSelectionPos > -1) {
            size_t begin = symbolLengthToBytes(mValueTemp, mCursorPos);
            size_t end = symbolLengthToBytes(mValueTemp, mSelectionPos);

            if (begin > end)
                swap(begin, end);

            if (begin == end - 1)
                mValueTemp.replaceInPlace(begin, begin+1, (char[]).init);
            else
                mValueTemp.replaceInPlace(begin, end, (char[]).init);

            import std.utf : count;
            mCursorPos = cast(int) mValueTemp[0..begin].count;
            mSelectionPos = -1;
            return true;
        }

        return false;
    }

	void updateCursor(NanoContext ctx, float lastx,
					  const(NVGGlyphPosition)[] glyphs)
    {
        // handle mouse cursor events
        if (mMouseDownPos.x != -1) {
            if (mMouseDownModifier == KeyMod.Shift)
            {
                if (mSelectionPos == -1)
                    mSelectionPos = mCursorPos;
            } else
                mSelectionPos = -1;

            mCursorPos =
                position2CursorIndex(mMouseDownPos.x, lastx, glyphs);

            mMouseDownPos = Vector2i(-1, -1);
        } else if (mMouseDragPos.x != -1) {
            if (mSelectionPos == -1)
                mSelectionPos = mCursorPos;

            mCursorPos =
                position2CursorIndex(mMouseDragPos.x, lastx, glyphs);
        } else {
            // set cursor to last character
            if (mCursorPos == -2)
                mCursorPos = cast(int) glyphs.length;
        }

        if (mCursorPos == mSelectionPos)
            mSelectionPos = -1;
    }
	float cursorIndex2Position(int index, float lastx,
							   const(NVGGlyphPosition)[] glyphs)
    {
        float pos = 0;
        if (index == glyphs.length)
            pos = lastx; // last character
        else
            pos = glyphs[index].x;

        return pos;
    }

	int position2CursorIndex(float posx, float lastx,
							 const(NVGGlyphPosition)[] glyphs)
    {
        int mCursorId = 0;
        float caretx = glyphs[mCursorId].x;
        for (int j = 1; j < glyphs.length; j++) {
            if (abs(caretx - posx) > abs(glyphs[j].x - posx)) {
                mCursorId = j;
                caretx = glyphs[mCursorId].x;
            }
        }
        if (abs(caretx - posx) > abs(lastx - posx))
            mCursorId = cast(int) glyphs.length;

        return mCursorId;
    }

	/// The location (if any) for the spin area.
	enum SpinArea { None, Top, Bottom }
	SpinArea spinArea(Vector2i pos)
    {
        if (0 <= pos.x - mPos.x && pos.x - mPos.x < 14.0f) { /* on scrolling arrows */
            if (mSize.y >= pos.y - mPos.y && pos.y - mPos.y <= mSize.y / 2.0f) { /* top part */
                return SpinArea.Top;
            } else if (0.0f <= pos.y - mPos.y && pos.y - mPos.y > mSize.y / 2.0f) { /* bottom part */
                return SpinArea.Bottom;
            }
        }
        return SpinArea.None;
    }

	bool mEditable;
	bool mSpinnable;
	bool mCommitted;
	string mValue;
	string mDefaultValue;
	Alignment mAlignment;
	string mUnits;
	string mFormat;
	NVGImage mUnitsImage;
	bool delegate(string str) mCallback;
	bool mValidFormat;
	string mValueTemp;
	string mPlaceholder;
	int mCursorPos;
	int mSelectionPos;
	Vector2i mMousePos;
	Vector2i mMouseDownPos;
	Vector2i mMouseDragPos;
	int mMouseDownModifier;
	float mTextOffset;
	double mLastClick;
}

/**
 * \class IntBox textbox.h nanogui/textbox.h
 *
 * \brief A specialization of TextBox for representing integral values.
 *
 * Template parameters should be integral types, e.g. `int`, `long`,
 * `uint32_t`, etc.
 */
class IntBox(Scalar) : TextBox if (isIntegral!Scalar) {
public:
	this(Widget parent, Scalar v = cast(Scalar) 0)
	{
		super(parent);
		defaultValue("0");
		format(isSigned!Scalar ? "[-]?[0-9]*" : "[0-9]*");
		valueIncrement(cast(Scalar) 1);
		minMaxValues(Scalar.min, Scalar.max);
		value(v);
		spinnable(false);
	}

	final Scalar value() const
	{
		import std.conv : to;
		return TextBox.value.to!Scalar;
	}

	final void value(Scalar v)
	{
		import std.algorithm : min, max;
		import std.conv : to;
		Scalar clampedValue = min(max(v, mMinValue), mMaxValue);
		TextBox.value = to!string(clampedValue);
	}

	final void callback(void delegate(Scalar) cb)
	{
		TextBox.callback((string str)
		{
			import std.conv : to, ConvOverflowException;
			Scalar scalar;
			try {
				scalar = str.to!Scalar;
			} catch (ConvOverflowException ex) {
				// TODO
			}
			value(scalar);
			cb(scalar);
			return true;
		});
	}

	final void valueIncrement(Scalar value)
	{
		mValueIncrement = value;
	}

	final void minValue(Scalar value)
	{
		mMinValue = value;
	}

	final void maxValue(Scalar value)
	{
		mMaxValue = value;
	}

	final void minMaxValues(Scalar min_value, Scalar max_value)
	{
		minValue(min_value);
		maxValue(max_value);
	}

	override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
	{
		if ((mEditable || mSpinnable) && down)
			mMouseDownValue = value();

		SpinArea area = spinArea(p);
		if (mSpinnable && area != SpinArea.None && down && !focused()) {
			if (area == SpinArea.Top) {
				value(cast(Scalar) (value() + mValueIncrement));
				if (mCallback)
					mCallback(mValue);
			} else if (area == SpinArea.Bottom) {
				value(cast(Scalar) (value() - mValueIncrement));
				if (mCallback)
					mCallback(mValue);
			}
			return true;
		}

		return TextBox.mouseButtonEvent(p, button, down, modifiers);
	}

	override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
	{
		if (TextBox.mouseDragEvent(p, rel, button, modifiers)) {
			return true;
		}
		if (mSpinnable && !focused() && button == 2 /* 1 << GLFW_MOUSE_BUTTON_2 */ && mMouseDownPos.x != -1) {
			int valueDelta = cast(int) ((p.x - mMouseDownPos.x) / float(10));
			value(cast (Scalar)(mMouseDownValue + valueDelta * mValueIncrement));
			if (mCallback)
				mCallback(mValue);
			return true;
		}
		return false;
	}

	override bool scrollEvent(Vector2i p, Vector2f rel)
	{
		if (Widget.scrollEvent(p, rel)) {
			return true;
		}
		if (mSpinnable && !focused()) {
			const valueDelta = (rel.y > 0) ? 1 : -1;
			value(cast(Scalar) (value() + valueDelta*mValueIncrement));
			if (mCallback)
				mCallback(mValue);
			return true;
		}
		return false;
	}

private:
	Scalar mMouseDownValue;
	Scalar mValueIncrement;
	Scalar mMinValue, mMaxValue;
}

/**
 * \class FloatBox textbox.d nanogui/textbox.d
 *
 * \brief A specialization of TextBox representing floating point values.

 * Template parameters should be float types, e.g. `float`, `double`,
 * `float64_t`, etc.
 */
class FloatBox(Scalar) : TextBox if (isFloatingPoint!Scalar) {
public:
	this(Widget parent, Scalar v = cast(Scalar) 0.0f)
	{
		super(parent);
		mNumberFormat = Scalar.sizeof == float.sizeof ? "%.4g" : "%.7g";
		defaultValue("0");
		format("[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?");valueIncrement(cast(Scalar) 0.1);
		minMaxValues(Scalar.min_exp, Scalar.max);
		value(v);
		spinnable(false);
	}

	final string numberFormat() const { return mNumberFormat; }
	final void numberFormat(string format) { mNumberFormat = format; }

	final Scalar value() const {
		import std.conv : to;
		return TextBox.value.to!Scalar;
	}

	final void value(Scalar v) {
		import std.algorithm : min, max;
		import std.string : fromStringz;
		import core.stdc.stdio : snprintf;

		Scalar clampedValue = min(max(v, mMinValue), mMaxValue);
		char[50] buffer;
		snprintf(buffer.ptr, 50, mNumberFormat.ptr, clampedValue);
		TextBox.value(buffer.ptr.fromStringz.dup);
	}

	final void callback(void delegate(Scalar) cb) {
		TextBox.callback((string str) {
			import std.conv : to;
			Scalar scalar = str.to!Scalar;
			value(scalar);
			cb(scalar);
			return true;
		});
	}

	final void valueIncrement(Scalar value) {
		mValueIncrement = value;
	}

	final void minValue(Scalar value) {
		mMinValue = value;
	}

	final void maxValue(Scalar value) {
		mMaxValue = value;
	}

	final void minMaxValues(Scalar min_value, Scalar max_value) {
		minValue(min_value);
		maxValue(max_value);
	}

	override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
	{
		if ((mEditable || mSpinnable) && down)
			mMouseDownValue = value();

		SpinArea area = spinArea(p);
		if (mSpinnable && area != SpinArea.None && down && !focused()) {
			if (area == SpinArea.Top) {
				value(value() + mValueIncrement);
				if (mCallback)
					mCallback(mValue);
			} else if (area == SpinArea.Bottom) {
				value(value() - mValueIncrement);
				if (mCallback)
					mCallback(mValue);
			}
			return true;
		}

		return TextBox.mouseButtonEvent(p, button, down, modifiers);
	}

	override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
	{
		if (TextBox.mouseDragEvent(p, rel, button, modifiers)) {
			return true;
		}
		if (mSpinnable && !focused() && button == 2 /* 1 << GLFW_MOUSE_BUTTON_2 */ && mMouseDownPos.x != -1) {
			int valueDelta = cast(int)((p.x - mMouseDownPos.x) / float(10));
			value(mMouseDownValue + valueDelta * mValueIncrement);
			if (mCallback)
				mCallback(mValue);
			return true;
		}
		return false;
	}

	override bool scrollEvent(Vector2i p, Vector2f rel)
	{
		if (Widget.scrollEvent(p, rel)) {
			return true;
		}
		if (mSpinnable && !focused()) {
			const valueDelta = (rel.y > 0) ? 1 : -1;
			value(value() + valueDelta*mValueIncrement);
			if (mCallback)
				mCallback(mValue);
			return true;
		}
		return false;
	}

private:
	string mNumberFormat;
	Scalar mMouseDownValue;
	Scalar mValueIncrement;
	Scalar mMinValue, mMaxValue;
}

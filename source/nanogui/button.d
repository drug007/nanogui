///
module nanogui.button;
/*
    NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
    The widget drawing code is based on the NanoVG demo application
    by Mikko Mononen.

    All rights reserved. Use of this source code is governed by a
    BSD-style license that can be found in the LICENSE.txt file.
*/

import std.container.array : Array;
import std.typecons : RefCounted;

import nanogui.widget;
import nanogui.common;

/**
 * Defines the [Normal/Toggle/Radio/Popup] `nanogui.Button` widget.
 */
class Button : Widget
{
public:
    /// Flags to specify the button behavior (can be combined with binary OR)
    enum Flags
    {
        NormalButton = (1 << 0), ///< A normal Button.
        RadioButton  = (1 << 1), ///< A radio Button.
        ToggleButton = (1 << 2), ///< A toggle Button.
        PopupButton  = (1 << 3)  ///< A popup Button.
    }

    /// The available icon positions.
    enum IconPosition
    {
        Left,         ///< Button icon on the far left.
        LeftCentered, ///< Button icon on the left, centered (depends on caption text length).
        RightCentered,///< Button icon on the right, centered (depends on caption text length).
        Right         ///< Button icon on the far right.
    }

    /**
     * Creates a button attached to the specified parent.
     *
     * Params:
     * parent  = The `nanogui.Widget` this Button will be attached to.
     * caption = The name of the button (default `"Untitled"`).
     */
    this(Widget parent, string caption = "Untitled")
    {
        super(parent);
        mCaption = caption;
        mIcon = 0;
        mImage = NVGImage();
        mIconPosition = IconPosition.LeftCentered;
        mPushed = false;
        mFlags = Flags.NormalButton;
        mBackgroundColor = Color(0, 0, 0, 0);
        mTextColor = Color(0, 0, 0, 0);
    }
    
    /**
     * Creates a button attached to the specified parent.
     *
     * Params:
     * parent  = The `nanogui.Widget` this Button will be attached to.
     * caption = The name of the button (default `"Untitled"`).
     * icon    = The icon to display with this Button. See `nanogui.Button.mIcon`.
     */
    this(Widget parent, string caption, dchar icon)
    {
        this(parent, caption);
        mIcon = icon;
    }
    
    /**
     * Creates a button attached to the specified parent.
     *
     * Params:
     * parent  = The `nanogui.Widget` this Button will be attached to.
     * caption = The name of the button (default `"Untitled"`).
     * image   = The image to display with this Button. See `nanogui.Button.mImage`.
     */
    this(Widget parent, string caption, ref const(NVGImage) image)
    {
        this(parent, caption);
        mImage = NVGImage(image);
    }

    /// Returns the caption of this Button.
    final string caption() const { return mCaption; }

    /// Sets the caption of this Button.
    final void caption(string caption) { mCaption = caption; }

    /// Returns the background color of this Button.
    final Color backgroundColor() const { return mBackgroundColor; }

    /// Sets the background color of this Button.
    final void backgroundColor(const Color backgroundColor) { mBackgroundColor = backgroundColor; }

    /// Returns the text color of the caption of this Button.
    final Color textColor() const { return mTextColor; }

    /// Sets the text color of the caption of this Button.
    final void textColor(const Color textColor) { mTextColor = textColor; }

    /// Returns the icon of this Button.  See `nanogui.Button.mIcon`.
    final dchar icon() const { return mIcon; }

    /// Sets the icon of this Button.  See `nanogui.Button.mIcon`.
    final void icon(int icon) { mIcon = icon; }

    /// The current flags of this Button (see `nanogui.Button.Flags` for options).
    final int flags() const { return mFlags; }

    /// Sets the flags of this Button (see `nanogui.Button.Flags` for options).
    final void flags(int buttonFlags) { mFlags = buttonFlags; }

    /// The position of the icon for this Button.
    final IconPosition iconPosition() const { return mIconPosition; }

    /// Sets the position of the icon for this Button.
    final void iconPosition(IconPosition iconPosition) { mIconPosition = iconPosition; }

    /// Whether or not this Button is currently pushed.
    final bool pushed() const { return mPushed; }

    /// Sets whether or not this Button is currently pushed.
    final void pushed(bool pushed) { mPushed = pushed; }

    /// The current callback to execute (for any type of button).
    final void delegate() callback() const { return mCallback; }

    /// Set the push callback (for any type of button).
    final void callback(void delegate() callback) { mCallback = callback; }

    /// The current callback to execute (for toggle buttons).
    final void delegate(bool) changeCallback() const { return mChangeCallback; }

    /// Set the change callback (for toggle buttons).
    final void changeCallback(void delegate(bool) callback) { mChangeCallback = callback; }

    /// Set the button group (for radio buttons).
    final void buttonGroup(ButtonGroup buttonGroup) { mButtonGroup = buttonGroup; }

    /// The current button group (for radio buttons).
    final buttonGroup() { return mButtonGroup; }

    /// The preferred size of this Button.
    override Vector2i preferredSize(NanoContext ctx) const
    {
        int fontSize = mFontSize == -1 ? mTheme.mButtonFontSize : mFontSize;
        ctx.fontSize(fontSize);
        ctx.fontFace("sans-bold");
        const tw = ctx.textBounds(0,0, mCaption, null);
        float iw = 0.0f, ih = fontSize;

        if (mIcon)
        {
            ih *= icon_scale();
            ctx.fontFace("icons");
            ctx.fontSize(ih);
            iw = ctx.textBounds(0, 0, [mIcon], null)
                + mSize.y * 0.15f;
        }
        else if (mImage.valid)
        {
            int w, h;
            ih *= 0.9f;
            ctx.imageSize(mImage, w, h);
            iw = w * ih / h;
        }
        return Vector2i(cast(int)(tw + iw) + 20, fontSize + 10);
    }

    /// The callback that is called when any type of mouse button event is issued to this Button.
    override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers)
    {
        Widget.mouseButtonEvent(p, button, down, modifiers);
        /* Temporarily increase the reference count of the button in case the
           button causes the parent window to be destructed */
        auto self = this;

        if (button == MouseButton.Left && mEnabled)
        {
            bool pushedBackup = mPushed;
            if (down)
            {
                if (mFlags & Flags.RadioButton)
                {
                    if (mButtonGroup.empty)
                    {
                        foreach (widget; parent.children)
                        {
                            auto b = cast(Button) widget;
                            if (b != this && b && (b.flags & Flags.RadioButton) && b.mPushed)
                            {
                                b.mPushed = false;
                                if (b.mChangeCallback)
                                    b.mChangeCallback(false);
                            }
                        }
                    } else {
                        foreach (b; mButtonGroup)
                        {
                            if (b != this && (b.flags & Flags.RadioButton) && b.mPushed)
                            {
                                b.mPushed = false;
                                if (b.mChangeCallback)
                                    b.mChangeCallback(false);
                            }
                        }
                    }
                }
                if (mFlags & Flags.PopupButton)
                {
                    foreach (widget; parent.children)
                    {
                        auto b = cast(Button) widget;
                        if (b != this && b && (b.flags & Flags.PopupButton) && b.mPushed)
                        {
                            b.mPushed = false;
                            if (b.mChangeCallback)
                                b.mChangeCallback(false);
                        }
                    }
                }
                if (mFlags & Flags.ToggleButton)
                    mPushed = !mPushed;
                else
                    mPushed = true;
            } else if (mPushed)
            {
                if (contains(p) && mCallback)
                    mCallback();
                if (mFlags & Flags.NormalButton)
                    mPushed = false;
            }
            if (pushedBackup != mPushed && mChangeCallback)
                mChangeCallback(mPushed);

            return true;
        }
        return false;
    }

    /// Responsible for drawing the Button.
    override void draw(NanoContext ctx)
    {
        super.draw(ctx);

        auto gradTop = mTheme.mButtonGradientTopUnfocused;
        auto gradBot = mTheme.mButtonGradientBotUnfocused;

        if (mPushed)
        {
            gradTop = mTheme.mButtonGradientTopPushed;
            gradBot = mTheme.mButtonGradientBotPushed;
        }
        else if (mMouseFocus && mEnabled)
        {
            gradTop = mTheme.mButtonGradientTopFocused;
            gradBot = mTheme.mButtonGradientBotFocused;
        }

        ctx.beginPath;

        ctx.roundedRect(mPos.x + 1, mPos.y + 1.0f, mSize.x - 2,
                       mSize.y - 2, mTheme.mButtonCornerRadius - 1);

        if (mBackgroundColor.w != 0)
        {
            ctx.fillColor(Color(mBackgroundColor.rgb, 1.0f));
            ctx.fill;
            if (mPushed)
            {
                gradTop.a = gradBot.a = 0.8f;
            }
            else
            {
                const v = 1 - mBackgroundColor.w;
                gradTop.a = gradBot.a = mEnabled ? v : v * .5f + .5f;
            }
        }

        NVGPaint bg = ctx.linearGradient(mPos.x, mPos.y, mPos.x,
                                        mPos.y + mSize.y, gradTop, gradBot);

        ctx.fillPaint(bg);
        ctx.fill;

        ctx.beginPath;
        ctx.strokeWidth(1.0f);
        ctx.roundedRect(mPos.x + 0.5f, mPos.y + (mPushed ? 0.5f : 1.5f), mSize.x - 1,
                       mSize.y - 1 - (mPushed ? 0.0f : 1.0f), mTheme.mButtonCornerRadius);
        ctx.strokeColor(mTheme.mBorderLight);
        ctx.stroke;

        ctx.beginPath;
        ctx.roundedRect(mPos.x + 0.5f, mPos.y + 0.5f, mSize.x - 1,
                       mSize.y - 2, mTheme.mButtonCornerRadius);
        ctx.strokeColor(mTheme.mBorderDark);
        ctx.stroke;

        int fontSize = mFontSize == -1 ? mTheme.mButtonFontSize : mFontSize;
        ctx.fontSize(fontSize);
        ctx.fontFace("sans-bold");
        const tw = ctx.textBounds(0,0, mCaption, null);

        Vector2f center = mPos + cast(Vector2f) mSize * 0.5f;
        auto textPos = Vector2f(center.x - tw * 0.5f, center.y - 1);
        auto textColor =
            mTextColor.w == 0 ? mTheme.mTextColor : mTextColor;
        if (!mEnabled)
            textColor = mTheme.mDisabledTextColor;

        float iw, ih;
        float d = (mPushed ? 1.0f : 0.0f);
        if (mIcon)
        {
            ih = fontSize*icon_scale;
            ctx.fontSize(ih);
            ctx.fontFace("icons");
            iw = ctx.textBounds(0, 0, [mIcon], null);
        } else if (mImage.valid)
        {
            int w, h;
            ctx.imageSize(mImage, w, h);
            import std.algorithm : min;
            ih = min(h*0.9f, height);
            iw = w * ih / h;
        }
        import std.math : isNaN;
        if (!iw.isNaN)
        {
            if (mCaption != "")
                iw += mSize.y * 0.15f;
            ctx.fillColor(textColor);
            NVGTextAlign algn;
            algn.left = true;
            algn.middle = true;
            ctx.textAlign(algn);
            Vector2f iconPos = center;
            iconPos.y -= 1;

            if (mIconPosition == IconPosition.LeftCentered)
            {
                iconPos.x -= (tw + iw) * 0.5f;
                textPos.x += iw * 0.5f;
            }
            else if (mIconPosition == IconPosition.RightCentered)
            {
                textPos.x -= iw * 0.5f;
                iconPos.x += tw * 0.5f;
            }
            else if (mIconPosition == IconPosition.Left)
            {
                iconPos.x = mPos.x + 8;
            }
            else if (mIconPosition == IconPosition.Right)
            {
                iconPos.x = mPos.x + mSize.x - iw - 8;
            }

            if (mIcon)
            {
                ctx.text(iconPos.x, iconPos.y + d + 1, [mIcon]);
            }
            else
            {
                NVGPaint imgPaint = ctx.imagePattern(
                       iconPos.x, iconPos.y + d - ih/2, iw, ih, 0, mImage, mEnabled ? 0.5f : 0.25f);

                ctx.fillPaint(imgPaint);
                ctx.fill;
            }
        }

        ctx.fontSize(fontSize);
        ctx.fontFace("sans-bold");
        NVGTextAlign algn;
        algn.left = true;
        algn.middle = true;
        ctx.textAlign(algn);
        ctx.fillColor(mTheme.mTextColorShadow);
        ctx.text(textPos.x, textPos.y + d, mCaption,);
        ctx.fillColor(textColor);
        ctx.text(textPos.x, textPos.y + d + 1, mCaption);
    }

    // // Saves the state of this Button provided the given Serializer.
    //override void save(Serializer &s) const;

    // // Sets the state of this Button provided the given Serializer.
    //override bool load(Serializer &s);

protected:
    /// The caption of this Button.
    string mCaption;

    /// The icon to display with this Button (`0` means icon is represented by mImage).
    dchar mIcon;
    /// The icon to display with this Button (it's used if mIcon is `0` and mImage.valid
    /// returns `true`).
    NVGImage mImage;

    /// The position to draw the icon at.
    IconPosition mIconPosition;

    /// Whether or not this Button is currently pushed.
    bool mPushed;

    /// The current flags of this button (see `nanogui.Button.Flags` for options).
    int mFlags;

    /// The background color of this Button.
    Color mBackgroundColor;

    /// The color of the caption text of this Button.
    Color mTextColor;

    /// The callback issued for all types of buttons.
    void delegate() mCallback;

    /// The callback issued for toggle buttons.
    void delegate(bool) mChangeCallback;

    /// The button group for radio buttons.
    ButtonGroup mButtonGroup;
}

alias ButtonGroup = RefCounted!(Array!Button);
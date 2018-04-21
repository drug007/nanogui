module nanogui.popupbutton;
/*
    nanogui/popupbutton.h -- Button which launches a popup widget

    NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
    The widget drawing code is based on the NanoVG demo application
    by Mikko Mononen.

    All rights reserved. Use of this source code is governed by a
    BSD-style license that can be found in the LICENSE.txt file.
*/

import nanogui.button;
import nanogui.popup;
import nanogui.entypo;
import nanogui.widget;
import nanogui.window;
import nanogui.common;

/**
 * Button which launches a popup widget.
 *
 * Remark:
 *     This class overrides `nanogui.Widget.mIconExtraScale`` to be `0.8f`,
 *     which affects all subclasses of this Widget.  Subclasses must explicitly
 *     set a different value if needed (e.g., in their constructor).
 */
class PopupButton : Button
{
public:
    this(Widget parent, string caption = "Untitled",
                int buttonIcon = 0)
    {
        super(parent, caption, buttonIcon);

        mChevronIcon = mTheme.mPopupChevronRightIcon;

        flags(Flags.ToggleButton | Flags.PopupButton);

        Window parentWindow = window;
        mPopup = new Popup(parentWindow.parent, window);
        mPopup.size(Vector2i(320, 250));
        mPopup.visible(false);

        mIconExtraScale = 0.8f;// widget override
    }

    final void chevronIcon(int icon) { mChevronIcon = icon; }
    final dchar chevronIcon() const { return mChevronIcon; }

    final void side(Popup.Side popupSide);
    final Popup.Side side() const { return mPopup.side(); }

    final Popup popup() { return mPopup; }
    final auto popup() const { return mPopup; }

    override void draw(NVGContext nvg)
    {
        if (!mEnabled && mPushed)
            mPushed = false;

        mPopup.visible(mPushed);
        Button.draw(nvg);

        if (mChevronIcon != dchar.init)
        {
            auto icon = mChevronIcon;
            auto textColor =
                mTextColor.w == 0 ? mTheme.mTextColor : mTextColor;

            nvg.fontSize((mFontSize < 0 ? mTheme.mButtonFontSize : mFontSize) * icon_scale());
            nvg.fontFace("icons");
            nvg.fillColor(mEnabled ? textColor : mTheme.mDisabledTextColor);
            auto algn = NVGTextAlign();
            algn.left = true;
            algn.middle = true;
            nvg.textAlign(algn);

            float iw = nvg.textBounds(0, 0, [icon], null);
            auto iconPos = Vector2f(0, mPos.y + mSize.y * 0.5f - 1);

            if (mPopup.side == Popup.Side.Right)
                iconPos[0] = mPos.x + mSize.x - iw - 8;
            else
                iconPos[0] = mPos.x + 8;

            nvg.text(iconPos.x, iconPos.y, [icon]);
        }
    }
    override Vector2i preferredSize(NVGContext nvg) const
    {
        return Button.preferredSize(nvg) + Vector2i(15, 0);
    }
    override void performLayout(NVGContext nvg)
    {
        Widget.performLayout(nvg);

        const Window parentWindow = window;

        int posY = absolutePosition.y - parentWindow.position.y + mSize.y/2;
        if (mPopup.side == Popup.Side.Right)
            mPopup.anchorPos(Vector2i(parentWindow.width + 15, posY));
        else
            mPopup.anchorPos(Vector2i(0 - 15, posY));
    }

    //virtual void save(Serializer &s) const override;
    //virtual bool load(Serializer &s) override;
protected:
    Popup mPopup;
    dchar mChevronIcon;
}

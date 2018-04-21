///
module nanogui.popup;
/*
    nanogui/popup.h -- Simple popup widget which is attached to another given
    window (can be nested)

    NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
    The widget drawing code is based on the NanoVG demo application
    by Mikko Mononen.

    All rights reserved. Use of this source code is governed by a
    BSD-style license that can be found in the LICENSE.txt file.
*/

import nanogui.window : Window;
import nanogui.widget : Widget, NVGContext;
import nanogui.common : Vector2i;

/**
 * Popup window for combo boxes, popup buttons, nested dialogs etc.
 *
 * Usually the Popup instance is constructed by another widget (e.g. `PopupButton`)
 * and does not need to be created by hand.
 */
class Popup : Window
{
public:
    enum Side { Left = 0, Right }

    /// Create a new popup parented to a screen (first argument) and a parent window
    this(Widget parent, Window parentWindow)
    {
        super(parent, "");
        mParentWindow = parentWindow;
        mAnchorHeight = 30;
        mAnchorPos    = Vector2i(0, 0);
        mSide         = Side.Right;
    }

    /// Return the anchor position in the parent window; the placement of the popup is relative to it
    final void anchorPos(Vector2i anchorPos) { mAnchorPos = anchorPos; }
    /// Set the anchor position in the parent window; the placement of the popup is relative to it
    final Vector2i anchorPos() const { return mAnchorPos; }

    /// Set the anchor height; this determines the vertical shift relative to the anchor position
    final void anchorHeight(int anchorHeight) { mAnchorHeight = anchorHeight; }
    /// Return the anchor height; this determines the vertical shift relative to the anchor position
    final int anchorHeight() const { return mAnchorHeight; }

    /// Set the side of the parent window at which popup will appear
    final void setSide(Side popupSide) { mSide = popupSide; }
    /// Return the side of the parent window at which popup will appear
    final Side side() const { return mSide; }

    /// Return the parent window of the popup
    final Window parentWindow() { return mParentWindow; }
    /// Return the parent window of the popup
    final parentWindow() const { return mParentWindow; }

    /// Invoke the associated layout generator to properly place child widgets, if any
    override void performLayout(NVGContext nvg)
    {
        if (mLayout || mChildren.length != 1) {
            Widget.performLayout(nvg);
        } else {
            mChildren[0].position(Vector2i(0, 0));
            mChildren[0].size(mSize);
            mChildren[0].performLayout(nvg);
        }
        if (mSide == Side.Left)
            mAnchorPos[0] -= size[0];
    }

    /// Draw the popup window
    override void draw(NVGContext nvg)
    {
        import arsd.nanovega;
        import nanogui.common;

        refreshRelativePlacement();

        if (!mVisible)
            return;

        int ds = mTheme.mWindowDropShadowSize, cr = mTheme.mWindowCornerRadius;

        nvg.save;
        nvg.resetScissor;

        /* Draw a drop shadow */
        NVGPaint shadowPaint = nvg.boxGradient(
            mPos.x, mPos.y, mSize.x, mSize.y, cr*2, ds*2,
            mTheme.mDropShadow, mTheme.mTransparent);

        nvg.beginPath;
        nvg.rect(mPos.x-ds,mPos.y-ds, mSize.x+2*ds, mSize.y+2*ds);
        nvg.roundedRect(mPos.x, mPos.y, mSize.x, mSize.y, cr);
        nvg.pathWinding(NVGSolidity.Hole);
        nvg.fillPaint(shadowPaint);
        nvg.fill;

        /* Draw window */
        nvg.beginPath;
        nvg.roundedRect(mPos.x, mPos.y, mSize.x, mSize.y, cr);

        Vector2i base = mPos + Vector2i(0, mAnchorHeight);
        int sign = -1;
        if (mSide == Side.Left) {
            base.x += mSize.x;
            sign = 1;
        }

        nvg.moveTo(base.x + 15*sign, base.y);
        nvg.lineTo(base.x - 1*sign, base.y - 15);
        nvg.lineTo(base.x - 1*sign, base.y + 15);

        nvg.fillColor(mTheme.mWindowPopup);
        nvg.fill;
        nvg.restore;

        Widget.draw(nvg);
    }

    //virtual void save(Serializer &s) const override;
    //virtual bool load(Serializer &s) override;
protected:
    /// Internal helper function to maintain nested window position values
    override void refreshRelativePlacement()
    {
        mParentWindow.refreshRelativePlacement();
        mVisible &= mParentWindow.visibleRecursive;
        mPos = mParentWindow.position + mAnchorPos - Vector2i(0, mAnchorHeight);
    }

    Window mParentWindow;
    Vector2i mAnchorPos;
    int mAnchorHeight;
    Side mSide;
}

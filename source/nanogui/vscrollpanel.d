///
module nanogui.vscrollpanel;

/*
    nanogui/vscrollpanel.h -- Adds a vertical scrollbar around a widget
    that is too big to fit into a certain area

    NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
    The widget drawing code is based on the NanoVG demo application
    by Mikko Mononen.

    All rights reserved. Use of this source code is governed by a
    BSD-style license that can be found in the LICENSE.txt file.
*/
import std.algorithm : min, max;
import nanogui.widget;
import nanogui.common : MouseButton, Vector2f, Vector2i, NVGContext;

/**
 * Adds a vertical scrollbar around a widget that is too big to fit into
 * a certain area.
 */
class VScrollPanel : Widget {
public:
    this(Widget parent)
    {
        super(parent);
        mChildPreferredHeight = 0;
        mScroll = 0.0f;
        mUpdateLayout = false;
    }

    /// Return the current scroll amount as a value between 0 and 1. 0 means scrolled to the top and 1 to the bottom.
    float scroll() const { return mScroll; }
    /// Set the scroll amount to a value between 0 and 1. 0 means scrolled to the top and 1 to the bottom.
    void setScroll(float scroll) { mScroll = scroll; }

    override void performLayout(NVGContext nvg)
    {
        super.performLayout(nvg);

        if (mChildren.empty)
            return;
        if (mChildren.length > 1)
            throw new Exception("VScrollPanel should have one child.");

        Widget child = mChildren[0];
        mChildPreferredHeight = child.preferredSize(nvg).y;

        if (mChildPreferredHeight > mSize.y)
        {
            auto y = cast(int) (-mScroll*(mChildPreferredHeight - mSize.y));
            child.position(Vector2i(0, y));
            child.size(Vector2i(mSize.x-12, mChildPreferredHeight));
        }
        else 
        {
            child.position(Vector2i(0, 0));
            child.size(mSize);
            mScroll = 0;
        }
        child.performLayout(nvg);
    }

    override Vector2i preferredSize(NVGContext nvg) const
    {
        if (mChildren.empty)
            return Vector2i(0, 0);
        return mChildren[0].preferredSize(nvg) + Vector2i(12, 0);
    }
    
    override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers)
    {
        if (!mChildren.empty && mChildPreferredHeight > mSize.y) {
            float scrollh = height *
                min(1.0f, height / cast(float)mChildPreferredHeight);

            mScroll = max(cast(float) 0.0f, min(cast(float) 1.0f,
                        mScroll + rel.y / cast(float)(mSize.y - 8 - scrollh)));
            mUpdateLayout = true;
            return true;
        } else {
            return super.mouseDragEvent(p, rel, button, modifiers);
        }
    }

    override bool scrollEvent(Vector2i p, Vector2f rel)
    {
        if (!mChildren.empty && mChildPreferredHeight > mSize.y)
        {
            const scrollAmount = rel.y * (mSize.y / 20.0f);
            float scrollh = height *
                min(1.0f, height / cast(float)mChildPreferredHeight);

            mScroll = max(cast(float) 0.0f, min(cast(float) 1.0f,
                    mScroll - scrollAmount / cast(float)(mSize.y - 8 - scrollh)));
            mUpdateLayout = true;
            return true;
        } else {
            return super.scrollEvent(p, rel);
        }
    }

    override void draw(NVGContext nvg)
    {
        if (mChildren.empty)
            return;
        Widget child = mChildren[0];
        auto y = cast(int) (-mScroll*(mChildPreferredHeight - mSize.y));
        child.position(Vector2i(0, y));
        mChildPreferredHeight = child.preferredSize(nvg).y;
        float scrollh = height *
            min(1.0f, height / cast(float) mChildPreferredHeight);

        if (mUpdateLayout)
            child.performLayout(nvg);

        nvg.save;
        nvg.translate(mPos.x, mPos.y);
        nvg.intersectScissor(0, 0, mSize.x, mSize.y);
        if (child.visible)
            child.draw(nvg);
        nvg.restore;

        if (mChildPreferredHeight <= mSize.y)
            return;

        NVGPaint paint = nvg.boxGradient(
            mPos.x + mSize.x - 12 + 1, mPos.y + 4 + 1, 8,
            mSize.y - 8, 3, 4, Color(0, 0, 0, 32), Color(0, 0, 0, 92));
        nvg.beginPath;
        nvg.roundedRect(mPos.x + mSize.x - 12, mPos.y + 4, 8,
                    mSize.y - 8, 3);
        nvg.fillPaint(paint);
        nvg.fill;

        paint = nvg.boxGradient(
            mPos.x + mSize.x - 12 - 1,
            mPos.y + 4 + (mSize.y - 8 - scrollh) * mScroll - 1, 8, scrollh,
            3, 4, Color(220, 220, 220, 100), Color(128, 128, 128, 100));

        nvg.beginPath;
        nvg.roundedRect(mPos.x + mSize.x - 12 + 1,
                    mPos.y + 4 + 1 + (mSize.y - 8 - scrollh) * mScroll, 8 - 2,
                    scrollh - 2, 2);
        nvg.fillPaint(paint);
        nvg.fill;
    }
    // override void save(Serializer &s) const;
    // override bool load(Serializer &s);
protected:
    int mChildPreferredHeight;
    float mScroll;
    bool mUpdateLayout;
}

module nanogui.slider;
/*
    nanogui.slider.d -- Fractional slider widget with mouse control
    NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
    The widget drawing code is based on the NanoVG demo application
    by Mikko Mononen.
    All rights reserved. Use of this source code is governed by a
    BSD-style license that can be found in the LICENSE.txt file.
*/

import std.algorithm : min, max;

import arsd.nanovega;
import nanogui.widget : Widget;
import nanogui.common : Vector2i, MouseButton, Color, boxGradient, 
	fillColor, Vector2f, radialGradient, linearGradient;

/// Fractional slider widget with mouse control
class Slider(T) : Widget {
	import std.typecons : tuple, Tuple;
	import std.datetime : dur, Duration;
public:

	import std.traits : isIntegral, isFloatingPoint;

	static assert(isIntegral!T || isFloatingPoint!T || is(T == Duration));

	this(Widget parent)
	{
		super(parent);
		static if (is(T == Duration))
		{
			mValue = dur!"seconds"(0);
			mRange = tuple(dur!"seconds"(0), dur!"seconds"(100));
		}
		else
		{
			mValue = cast(T) 0;
			mRange = tuple(0, 100);
		}

		highlightedRange = tuple(mRange[0], mValue);
		mHighlightColor = Color(255, 80, 80, 70);
		mPreferredWidth = 70;
	}

	final T value() const { return mValue; }
	final void  value(T value)
	{
		if (value < mRange[0])
			return;
		if (value > mRange[1])
			return;
		mValue = value;
		if (mCallback)
			mCallback(mValue);
	}

	final ref const(Color) highlightColor() const { return mHighlightColor; }
	final void highlightColor(ref const(Color) highlightColor) { mHighlightColor = highlightColor; }

	final Tuple!(T, T) range() const { return mRange; }
	final void range(T lo, T hi)
	{
		import std.exception : enforce;
		enforce(lo < hi, "Low boundary should be less than right boundary");
		mRange = tuple(lo, hi);
	}

	final void range(Tuple!(T, T) range) { mRange = range; }

	final Tuple!(T, T) highlightedRange() const
	{
		static if(is(T == Duration))
		{
			const total = (mRange[1] - mRange[0]).total!"hnsecs";
			T l = dur!"hnsecs"(cast(long)(mHighlightedRange[0]*total)) + mRange[0];
			T h = dur!"hnsecs"(cast(long)(mHighlightedRange[1]*total)) + mRange[0];
		}
		else
		{
			const total = (mRange[1] - mRange[0]);
			T l = cast(T) (mHighlightedRange[0]*total + mRange[0]);
			T h = cast(T) (mHighlightedRange[1]*total + mRange[0]);
		}
		return tuple(l, h);
	}

	final void highlightedRange(Tuple!(T, T) highlightedRange)
	{
		static if(is(T == Duration))
		{
			const total = (mRange[1] - mRange[0]).total!"hnsecs";
			mHighlightedRange[0] = (highlightedRange[0] - mRange[0]).total!"hnsecs"/cast(double) total;
			mHighlightedRange[1] = (highlightedRange[1] - mRange[0]).total!"hnsecs"/cast(double) total;
		}
		else
		{
			const total = (mRange[1] - mRange[0]);
			mHighlightedRange[0] = (highlightedRange[0] - mRange[0])/cast(double) total;
			mHighlightedRange[1] = (highlightedRange[1] - mRange[0])/cast(double) total;
		}
	}

	final bool delegate(T) callback() const { return mCallback; }
	final void callback(bool delegate(T) callback) { mCallback = callback; }

	final bool delegate(T) finalCallback() const { return mCallback; }
	final void finalCallback(bool delegate(T) callback) { mCallback = callback; }

	final void preferredWidth(int width)
	{
		mPreferredWidth = width;
	}

	override Vector2i preferredSize(NanoContext ctx) const
	{
		return Vector2i(mPreferredWidth, 16);
	}

	private auto calculateNewValue(const Vector2i p)
	{
		const double kr = cast(int) (mSize.y * 0.4f);
		const double kshadow = 3;
		const double startX = kr + kshadow + mPos.x - 1;
		const double widthX = mSize.x - 2 * (kr + kshadow);

		static if (is(T == Duration))
		{
			import std.conv : to;

			// used to save precision during converting from floating to int types
			enum factor = 2^^13;
			const v1 = factor*(p.x - startX) / cast(double) widthX;
			const v2 = to!long(v1);
			const v3 = (mRange[1] - mRange[0])*v2/factor + mRange[0];
			mValue = min(max(v3, mRange[0]), mRange[1]);
		}
		else
		{
			double v = (p.x - startX) / cast(double) widthX;
			v = v * (mRange[1] - mRange[0]) + mRange[0];
			mValue = cast(T) min(max(v, mRange[0]), mRange[1]);
		}
	}

	override bool mouseDragEvent(const Vector2i p, const Vector2i rel, MouseButton button, int modifiers)
	{
		if (!mEnabled)
			return false;

		calculateNewValue(p);

		if (mCallback)
			mCallback(mValue);
		return true;
	}

	override bool mouseButtonEvent(const Vector2i p, MouseButton button, bool down, int modifiers)
	{
		if (!mEnabled)
			return false;

		calculateNewValue(p);

		if (mCallback)
			mCallback(mValue);
		if (mFinalCallback && !down)
			mFinalCallback(mValue);
		return true;
	}

	override void draw(NanoContext ctx)
	{
		Vector2f center = cast(Vector2f) mPos + 0.5f * cast(Vector2f) mSize;
		float kr = cast(int) (mSize.y * 0.4f);
		float kshadow = 3;

		float startX = kr + kshadow + mPos.x;
		float widthX = mSize.x - 2*(kr+kshadow);

		static if (is(T == Duration))
		{
			auto knobPos = Vector2f(startX + (mValue - mRange[0]).total!"hnsecs" /
					cast(double)(mRange[1] - mRange[0]).total!"hnsecs" * widthX,
					center.y + 0.5f);
		}
		else
		{
			auto knobPos = Vector2f(startX + (mValue - mRange[0]) /
					cast(double)(mRange[1] - mRange[0]) * widthX,
					center.y + 0.5f);
		}

		NVGPaint bg = ctx.boxGradient(
			startX, center.y - 3 + 1, widthX, 6, 3, 3,
			Color(0, 0, 0, mEnabled ? 32 : 10), Color(0, 0, 0, mEnabled ? 128 : 210));

		ctx.beginPath;
		ctx.roundedRect(startX, center.y - 3 + 1, widthX, 6, 2);
		ctx.fillPaint(bg);
		ctx.fill;

		if (mHighlightedRange[1] != mHighlightedRange[0]) {
			ctx.beginPath;
			ctx.roundedRect(startX + mHighlightedRange[0] * mSize.x,
				center.y - kshadow + 1,
				widthX * (mHighlightedRange[1] - mHighlightedRange[0]),
				kshadow * 2, 2);
			ctx.fillColor(mHighlightColor);
			ctx.fill;
		}

		NVGPaint knobShadow =
			ctx.radialGradient(knobPos.x, knobPos.y, kr - kshadow,
							kr + kshadow, Color(0, 0, 0, 64), mTheme.mTransparent);

		ctx.beginPath;
		ctx.rect(knobPos.x - kr - 5, knobPos.y - kr - 5, kr * 2 + 10,
				kr * 2 + 10 + kshadow);
		ctx.circle(knobPos.x, knobPos.y, kr);
		ctx.pathWinding(NVGSolidity.Hole);
		ctx.fillPaint(knobShadow);
		ctx.fill;

		NVGPaint knob = ctx.linearGradient(
			mPos.x, center.y - kr, mPos.x, center.y + kr,
			mTheme.mBorderLight, mTheme.mBorderMedium);
		NVGPaint knobReverse = ctx.linearGradient(
			mPos.x, center.y - kr, mPos.x, center.y + kr,
			mTheme.mBorderMedium,
			mTheme.mBorderLight);

		ctx.beginPath;
		ctx.circle(knobPos.x, knobPos.y, kr);
		with (mTheme.mBorderDark)
			ctx.strokeColor(nvgRGBA(cast(int)(r/255), cast(int)(g/255), cast(int)(b/255), cast(int)(a/255)));
		ctx.fillPaint(knob);
		ctx.stroke;
		ctx.fill;
		ctx.beginPath;
		ctx.circle(knobPos.x, knobPos.y, kr/2);
		ctx.fillColor(Color(150, 150, 150, mEnabled ? 255 : 100));
		ctx.strokePaint(knobReverse);
		ctx.stroke;
		ctx.fill;
	}
	// void save(Serializer &s) const;
	// bool load(Serializer &s);

protected:
	T mValue;
	bool delegate(T) mCallback;
	bool delegate(T) mFinalCallback;
	Tuple!(T, T) mRange;
	Tuple!(float, float) mHighlightedRange;
	Color mHighlightColor;
	int mPreferredWidth;
}

// void Slider::save(Serializer &s) const {
//     Widget::save(s);
//     s.set("value", mValue);
//     s.set("range", mRange);
//     s.set("highlightedRange", mHighlightedRange);
//     s.set("highlightColor", mHighlightColor);
// }

// bool Slider::load(Serializer &s) {
//     if (!Widget::load(s)) return false;
//     if (!s.get("value", mValue)) return false;
//     if (!s.get("range", mRange)) return false;
//     if (!s.get("highlightedRange", mHighlightedRange)) return false;
//     if (!s.get("highlightColor", mHighlightColor)) return false;
//     return true;
// }
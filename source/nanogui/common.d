///
module nanogui.common;

import gfm.math : vec2i, vec2f, vec3f, vec4f, vec4i;
import arsd.nanovega : NVGContext;
public import arsd.nanovega;

struct NanoContext
{
	import std.typecons : Rebindable;
	import nanogui.theme : Theme;

	NVGContext nvg;
	alias nvg this;

	@disable this();

	this(NVGContextFlag flag)
	{
		nvg = nvgCreateContext(flag);
		algn.left = true;
		algn.top = true;
	}

	NVGTextAlign algn;
	Vector2i position;
	Vector2i mouse;
	Rebindable!(const Theme) theme;
	// current width or height (other dimension is passed to drawing function explicitely)
	float current_size;
	// nesting level of current item
	int tree_view_nesting_level;
}

alias Vector2i = vec2i;
alias Vector2f = vec2f;
alias Vector3f = vec3f;
alias Vector4i = vec4i;
alias Color = vec4f;

enum MouseButton : int
{
	None      =  0,
	Left      =  1,
	Right     =  2,
	Middle    =  4,
	WheelUp   =  8,
	WheelDown = 16, 
}

enum MouseAction : int
{
	Press   = 0,
	Release = 1,
	Motion  = 2,
}

enum KeyAction : int
{
	Press   = 0,
	Release = 1,
	Repeat  = 2,
}

enum KeyMod : int
{
	Shift = 1,
	Alt   = 2,
	Ctrl  = 4,
}

enum Key : int
{
	Left,
	Right,
	Up,
	Down,
	Home,
	End,
	Backspace,
	Delete,
	Enter,
	Shift,
	System,
	A,
	X,
	C,
	V,
	Esc,
}

/// Cursor shapes available to use in nanogui.  Shape of actual cursor determined by Operating System.
enum Cursor {
	Arrow = 0,  /// The arrow cursor.
	IBeam,      /// The I-beam cursor.
	Crosshair,  /// The crosshair cursor.
	Hand,       /// The hand cursor.
	HResize,    /// The horizontal resize cursor.
	VResize,    /// The vertical resize cursor.
}

/// Sets current fill style to a solid color.
/// Group: render_styles
public void fillColor (NanoContext ctx, Color color) nothrow @trusted @nogc {
  NVGColor clr = void;
  clr.rgba = color[];
  clr.rgba[] /= 255f;
  arsd.nanovega.fillColor(ctx, clr);
}

/** Creates and returns a box gradient. Box gradient is a feathered rounded rectangle, it is useful for rendering
 * drop shadows or highlights for boxes. Parameters (x, y) define the top-left corner of the rectangle,
 * (w, h) define the size of the rectangle, r defines the corner radius, and f feather. Feather defines how blurry
 * the border of the rectangle is. Parameter icol specifies the inner color and ocol the outer color of the gradient.
 * The gradient is transformed by the current transform when it is passed to [fillPaint] or [strokePaint].
 *
 * Group: paints
 */
public NVGPaint boxGradient (NanoContext ctx, in float x, in float y, in float w, in float h, in float r, in float f, Color icol, Color ocol) nothrow @trusted @nogc
{
	NVGColor clr1 = void, clr2 = void;
	clr1.rgba = icol[];
	clr1.rgba[] /= 255f;
	clr2.rgba = ocol[];
	clr2.rgba[] /= 255f;
	return arsd.nanovega.boxGradient(ctx, x, y, w, h, r, f, clr1, clr2);
}

/** Creates and returns a linear gradient. Parameters `(sx, sy) (ex, ey)` specify the start and end coordinates
 * of the linear gradient, icol specifies the start color and ocol the end color.
 * The gradient is transformed by the current transform when it is passed to [fillPaint] or [strokePaint].
 *
 * Group: paints
 */
public NVGPaint linearGradient (NanoContext ctx, in float sx, in float sy, in float ex, in float ey, Color icol, Color ocol) nothrow @trusted @nogc
{
	NVGColor clr1 = void, clr2 = void;
	clr1.rgba = icol[];
	clr1.rgba[] /= 255f;
	clr2.rgba = ocol[];
	clr2.rgba[] /= 255f;
	return arsd.nanovega.linearGradient(ctx, sx, sy, ex, ey, clr1, clr2);
}

/** Creates and returns a radial gradient. Parameters (cx, cy) specify the center, inr and outr specify
 * the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
 * The gradient is transformed by the current transform when it is passed to [fillPaint] or [strokePaint].
 *
 * Group: paints
 */
public NVGPaint radialGradient (NanoContext ctx, in float cx, in float cy, in float inr, in float outr, Color icol, Color ocol) nothrow @trusted @nogc {
	NVGColor clr1 = void, clr2 = void;
	clr1.rgba = icol[];
	clr1.rgba[] /= 255f;
	clr2.rgba = ocol[];
	clr2.rgba[] /= 255f;
	return arsd.nanovega.radialGradient(ctx, cx, cy, inr, outr, clr1, clr2);
}

/// Sets current stroke style to a solid color.
/// Group: render_styles
public void strokeColor (NanoContext ctx, Color color) nothrow @trusted @nogc
{
	NVGColor clr = void;
	clr.rgba = color[];
	clr.rgba[] /= 255f;
	arsd.nanovega.strokeColor(ctx, clr);
}
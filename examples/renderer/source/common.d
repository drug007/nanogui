module common;

/* 
GUI technology stack:
* program text is parsed to
* DOM that is traversed by high level renderer that issues
* graphics command independent on anything like OS, drivers et al
* low level renderer that renders gfx command to target
* target - framebuffer, texture etc

every visual has x, y (origin), width and height. but all of them may be optional. for example the root visual has x and y equal to zero. Also child visuals parameter can be calculated and doen't need to be set. 

Only mandatory values are:
	current x, y, width and height. Current x and y are given in parent visual coordinate system.
	count of widgets
	direction
	alignment
	justification
	wrapping
*/

/// What direction the children are laid out in
enum Direction { 
	row,           // items are placed in row from start to end
	column,        // items are placed in column from start to end
	rowReverse,    // items are placed in row from end to start
	columnReverse, // items are placed in column from end to start
}
/// Cross axis aligment
enum Alignment { 
	stretch,  // items fill the parent in the direction of the cross axis
	center,   // items maintain their intrinsic dimensions, but are centered along the cross axis
	start,    // items are aligned at the start of the cross axis
	end,      // items are aligned at the end of the cross axis
}

/// Main axis alignment
enum Justification {
	start,   // items sit at the start of the main axis
	end,     // items sit at the end of the main axis
	center,  // items sit in the center of the main axis
	around,  // items are evenly distributed along the main axis, with a bit of space left at either end
	between, // like `around` except that it doesn't leave any space at either end.
}

struct WorkArea
{
	float x, y, w, h, margin, padding;
}

struct Attributes
{
	import std.typecons : Nullable;

	private Nullable!Direction _direction;
	private Nullable!int _margin;
	private Nullable!int _padding;

	ref auto direction()
	{
		return _direction;
	}

	ref auto margin()
	{
		return _margin;
	}

	ref auto padding()
	{
		return _padding;
	}
}

/// Full description of current renderer state
/// for debug use
struct RenderState
{
	// node(widget) name
	string name;
	WorkArea area;
	Direction direction;

	// for debug purposes
	long misc;
	int nestingLevel;
}

class DomNode
{
	bool state;
	DomNode[] child;
	Attributes attributes;
	string name;

	this(bool s, DomNode[] ch)
	{
		state = s;
		child = ch;
	}
}

auto makeDom(Data)(Data data)
{
	import traverse : traverseImpl;

	static struct DomMaker
	{
		DomNode[] current;
	}

	auto dommaker = DomMaker();
	dommaker.current ~= new DomNode(false, null);
	traverseImpl!(domLeaf, domNodeEnter, domNodeLeave)(dommaker, data);
	assert(dommaker.current.length);
	assert(dommaker.current[0].child.length);

	return dommaker.current[0].child[0];
}

auto domLeaf(Context, Data)(ref Context ctx, Data data)
{
	// do nothing
}

auto domNodeEnter(Context, Data)(ref Context ctx, Data data)
{
	import std.array : back;
	auto node = new DomNode(false, null);
	node.name = typeof(data).stringof;
	ctx.current.back.child ~= node;
	ctx.current ~= node;
}

auto domNodeLeave(Context, Data)(ref Context ctx, Data data)
{
	import std.array : popBack;
	ctx.current.popBack;
}

void printDom(Context, Node)(ref Context ctx, Node mn)
{
	import std.stdio;
	import std.range;

	write("\n", "-".repeat(ctx.indent).join, "state: ");
	ctx.indent += 4;
	scope(exit) ctx.indent -= 4;
	write(mn.state, " '", mn.name, "' ", mn.child.length);
	foreach(ch; mn.child)
		printDom(ctx, ch);
}

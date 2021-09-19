module auxil.test2d;

version(unittest) import unit_threaded : Name, should, be, shouldBeTrue;

import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator : make;
import automem.vector : Vector, vector;

import auxil.model;
import auxil.default_visitor : TreePathVisitorImpl, MeasuringVisitor;
import auxil.location : SizeType, Axis;

extern(C++) class Node
{
	import std.algorithm : equal, map;

	extern(D):
	@safe:

	string name;
	Axis x, y;

	alias Children = Vector!(Node, Mallocator);
	Children children;
	Orientation orientation;

	this(string name, ref Axis x, ref Axis y, Children children) @nogc
	{
		this.name = name;
		this.x = x;
		this.y = y;
		this.children = children;
	}

	this(string name, SizeType x, SizeType y, SizeType w, SizeType h, Children children = Children()) @nogc
	{
		this.name = name;
		this.x.position = x;
		this.y.position = y;
		this.x.size = w;
		this.y.size = h;
		this.children = children;
	}

	this(string name, Orientation o, ref Axis x, ref Axis y, Children children = Children()) @nogc
	{
		this.name = name;
		this.x = x;
		this.y = y;
		this.orientation = o;
		this.children = children;
	}

	this(string name, Orientation o, SizeType x, SizeType y, SizeType w, SizeType h, Children children = Children()) @nogc
	{
		this.name = name;
		this.x.position = x;
		this.y.position = y;
		this.x.size = w;
		this.y.size = h;
		this.orientation = o;
		this.children = children;
	}

	void addChild(Node n) @trusted
	{
		children ~= n;
	}

	alias ThisType = typeof(this);

	void toString(void delegate(in char[]) sink) @trusted const
	{
		import std.algorithm : copy;
		import std.conv : text;

		string O;
		() @trusted {
			if (children.length)
			{
				O = orientation == Orientation.Horizontal ? "H, " : "V, ";
			}
		} ();

		sink(text(ThisType.stringof, "(`", 
			name, "`, ",
			O,
			x.position, ", ",
			y.position, ", ",
			x.size, ", ",
			y.size,
		));

		() @trusted {
			if (children.length)
			{
				sink(", [ ");
				children[0].toString(sink);
				foreach(i; 1..children.length)
				{
					sink(", ");
					children[i].toString(sink);
				}
				sink(" ]");
			}
		} ();
		sink(")");
	}
}

auto node(Args...)(Args args)
{
	return Mallocator.instance.make!Node(args);
}

enum CompareBy {
	none        = 0,
	name        = 1,
	Xpos        = 2, 
	Xsize       = 4, 
	Ypos        = 8, 
	Ysize       = 16, 
	children    = 32,
	orientation = 64,
	allFields   = none | name | Xpos | Xsize | Ypos | Ysize | children | orientation,
}

struct Comparator
{
	import auxil.treepath : TreePath;

	TreePath path, current;
	bool bResult;
	string sResult;

	bool compare(Node lhs, Node rhs, ubyte flags = CompareBy.allFields)
	{
		import std.algorithm : all;
		import std.range : zip;
		import std.format : format;

		if (!compareField(this, lhs, rhs, flags))
			return false;

		if (lhs.children.length != rhs.children.length)
		{
			bResult = false;
			sResult = "Different children count";
			return bResult;
		}

		static struct Record
		{
			size_t idx, total;
			Node test, etalon;
		}

		Record[] stack;
		stack ~= Record(0, 1, lhs, rhs);
		current.put(0);
		while(stack.length)
		{
			auto i = cast(int) stack[$-1].idx;
			current.back = i;

			if (!compareField(this, lhs, rhs, flags))
				return false;

			if (lhs.children.length)
			{
				i = 0;
				stack ~= Record(i, lhs.children.length, lhs, rhs);
				current.put(i);
			}

			if (i < stack[$-1].total)
			{
				lhs = stack[$-1].test.children[i];
				rhs = stack[$-1].etalon.children[i];
				stack[$-1].idx++;
			}
			else
			{
				lhs = stack[$-1].test;
				rhs = stack[$-1].etalon;
				stack = stack[0..$-1];
			}
		}

		return true;
	}
}

bool compareField(ref Comparator cmpr, Node lhs, Node rhs, ubyte flags = CompareBy.allFields)
{
	import std.algorithm : all;
	import std.range : zip;
	import std.format : format;

	if (lhs is null || rhs is null)
	{
		cmpr.bResult = false;
		cmpr.sResult = "At least one of instances is null";
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	if (flags == CompareBy.none)
	{
		cmpr.bResult = true;
		cmpr.sResult = "None of fields enabled for comparing";
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	if ((flags & CompareBy.name)  && lhs.name != rhs.name)
	{
		cmpr.bResult = false;
		cmpr.sResult = format("test   has name: %s\netalon has name: %s", lhs.name, rhs.name);
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	if ((flags & CompareBy.Xpos)  && lhs.x.position != rhs.x.position)
	{
		cmpr.bResult = false;
		cmpr.sResult = format("test   has x.position: %s\netalon has x.position: %s", lhs.x.position, rhs.x.position);
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	if ((flags & CompareBy.Xsize) && lhs.x.size != rhs.x.size)
	{
		cmpr.bResult = false;
		cmpr.sResult = format("test   has x.size: %s\netalon has x.size: %s", lhs.x.size, rhs.x.size);
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	if ((flags & CompareBy.Ypos)  && lhs.y.position != rhs.y.position)
	{
		cmpr.bResult = false;
		cmpr.sResult = format("test   has y.position: %s\netalon has y.position: %s", lhs.y.position, rhs.y.position);
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	if ((flags & CompareBy.Ysize) && lhs.y.size != rhs.y.size)
	{
		cmpr.bResult = false;
		cmpr.sResult = format("test   has y.size: %s\netalon has y.size: %s", lhs.y.size, rhs.y.size);
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	if ((flags & CompareBy.orientation) && lhs.orientation != rhs.orientation)
	{
		cmpr.bResult = false;
		cmpr.sResult = format("test   has orientation: %s\netalon has orientation: %s", lhs.orientation, rhs.orientation);
		cmpr.path = cmpr.current;
		return cmpr.bResult;
	}

	return true;
}

/// Entity state
struct State
{
	import std.algorithm : equal, map;

	@safe:
	Axis x, y;
	alias Children = Vector!(State*, Mallocator);
	Children children;
	string name;
	Orientation orientation;

	enum IgnoreField {
		none        = 0,
		name        = 1,
		Xpos        = 2, 
		Xsize       = 4, 
		Ypos        = 8, 
		Ysize       = 16, 
		children    = 32,
		orientation = 64,
		all         = none | name | Xpos | Xsize | Ypos | Ysize | children | orientation,
	}

	static ubyte ignoreField;

	this(string name, ref Axis x, ref Axis y, Children children) @nogc
	{
		this.name = name;
		this.x = x;
		this.y = y;
		this.children = children;
	}

	this(string name, SizeType x, SizeType y, SizeType w, SizeType h, Children children) @nogc
	{
		this.name = name;
		this.x.position = x;
		this.y.position = y;
		this.x.size = w;
		this.y.size = h;
		this.children = children;
	}

	this(string name, ref Axis x, ref Axis y, State[] children = null) @nogc @system
	{
		this.name = name;
		this.x = x;
		this.y = y;
		this.children = children.map!"&a".vector!Mallocator;
	}

	this(string name, SizeType x, SizeType y, SizeType w, SizeType h, State[] children = null) @nogc @system
	{
		this.name = name;
		this.x.position = x;
		this.y.position = y;
		this.x.size = w;
		this.y.size = h;
		this.children = children.map!"&a".vector!Mallocator;
	}

	this(string name, Orientation o, ref Axis x, ref Axis y, Children children = Children()) @nogc
	{
		this(name, x, y, children);
		this.orientation = o;
	}

	this(string name, Orientation o, SizeType x, SizeType y, SizeType w, SizeType h, Children children = Children()) @nogc
	{
		this(name, x, y, w, h, children);
		this.orientation = o;
	}

	auto opEquals(ref const(State) other) const
	{
		if (ignoreField == IgnoreField.all)
			return true;

		if (name != other.name)
			return false || (ignoreField & IgnoreField.name);
		if (x.position != other.x.position)
			return false || (ignoreField & IgnoreField.Xpos);
		if (x.size != other.x.size)
			return false || (ignoreField & IgnoreField.Xsize);
		if (y.position != other.y.position)
			return false || (ignoreField & IgnoreField.Ypos);
		if (y.size != other.y.size)
			return false || (ignoreField & IgnoreField.Ysize);
		if (() @trusted { return !children[].map!"*a".equal(other.children[].map!"*a"); } ())
			return false || (ignoreField & IgnoreField.children);
		if (orientation != other.orientation)
			return false || (ignoreField & IgnoreField.orientation);

		return true;
	}

	alias ThisType = typeof(this);

	void toString(W)(ref W w) const
	{
		import std.algorithm : copy;
		import std.conv : text;

		string O;
		() @trusted {
			if (children.length)
			{
				O = orientation == Orientation.Horizontal ? "H, " : "V, ";
			}
		} ();

		text(ThisType.stringof, "(`", 
			name, "`, ",
			O,
			x.position, ", ",
			y.position, ", ",
			x.size, ", ",
			y.size,
		).copy(w);

		() @trusted {
			if (children.length)
			{
				", [ ".copy(w);
				children[0].toString(w);
				foreach(i; 1..children.length)
				{
					", ".copy(w);
					children[i].toString(w);
				}
				" ]".copy(w);
			}
		} ();
		w.put(')');
	}
}

auto state(Args...)(Args args)
{
	return Mallocator.instance.make!State(args);
}

private enum H = Orientation.Horizontal;
private enum V = Orientation.Vertical;

@safe private
struct Visitor2D
{
	alias TreePathVisitor = TreePathVisitorImpl!(typeof(this));
	TreePathVisitor default_visitor;
	alias default_visitor this;

	State* position;
	Vector!(State*, Mallocator) pos_stack;
	Node current;
	Vector!(Node, Mallocator) node_stack;

	this(SizeType[2] size) @nogc nothrow
	{
		default_visitor = TreePathVisitor(size);
	}

	private void printPrefix()
	{
		enum prefix = "\t";
		import std;
		foreach(_; 0..pos_stack.length)
			write(prefix);
	}

	void enterTree(Order order, Data, Model)(ref const(Data) data, ref Model model) {}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (Model.Collapsable || order == Order.Sinking)
		{
			() @trusted {
				auto v = Mallocator.instance.make!State(Data.stringof, orientation, loc.x, loc.y);
				if (position !is null)
				{
					position.children ~= v;
					pos_stack ~= position;
				}
				position = v;

				auto n = new Node(Data.stringof, orientation, loc.x, loc.y);
				if (current !is null)
				{
					current.addChild(n);
					node_stack ~= current;
				}
				current = n;
				
{
	import std;
	printPrefix;
	writeln(*position);
}
			} ();
		}
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		() @trusted {
			if (!pos_stack.empty)
			{
				position = pos_stack[$-1];
				pos_stack.popBack;
			}

			if (!node_stack.empty)
			{
				current = node_stack[$-1];
				node_stack.popBack;
			}
		} ();
	}

	void beforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void afterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
}

/// test for 2D positioning using text mode only (no coordinates)
version(unittest) @Name("text2D")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	Test[2] data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model[0].collapsed = false;
	model[1].collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}

	model.size.should.be == 90;
	model.header_size.should.be == 10;
	model.length.should.be == 2;
	model[0].size.should.be == 40;
	model[1].size.should.be == 40;

	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		(*visitor.position).should.be ==
			State("Test[2]", 0, 0, 300, 10, vector!Mallocator([
				state("Test", 10, 10, 290, 10, vector!Mallocator([ 
					state("float", 20, 20, 280, 10), 
					state("int", 20, 30, 280, 10), 
					state("string", 20, 40, 280, 10),
				])),
				state("Test", 10, 50, 290, 10, vector!Mallocator([
					state("float", 20, 60, 280, 10), 
					state("int", 20, 70, 280, 10), 
					state("string", 20, 80, 280, 10),
				])),
			]));
	}();

	model[0].orientation = Orientation.Horizontal;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);

		model.size.should.be == 60;

		with(model[0])
		{
			size.should.be == 290;
			header_size.should.be == 10;
			f.size.should.be == 96;
			i.size.should.be == 97;
			s.size.should.be == 97;
		}
		with(model[1])
		{
			size.should.be == 40;
			header_size.should.be == 10;
			f.size.should.be == 10;
			i.size.should.be == 10;
			s.size.should.be == 10;
		}
	}
	visitor.loc.y.position = 0;
	model.visitForward(data, visitor);

	() @trusted
	{
		(*visitor.position).should.be ==
			State("", 0, 0, 300, 10, vector!Mallocator([
				state("", 10, 10, 290, 10, vector!Mallocator([ 
					state("", 10, 10, 96, 10,), state("", 10+96, 10, 97, 10), state("", 10+96+97, 10, 290-96-97, 10),
				])),
				state("", 10, 20, 290, 10, vector!Mallocator([
					state("", 20, 30, 280, 10), 
					state("", 20, 40, 280, 10), 
					state("", 20, 50, 280, 10),
				])), 
			]));
	}();
}

version(unittest) @Name("staticAttribute")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	static struct Wrapper
	{
		@("Orientation.Horizontal")
		Test t1;
		Test t2;
	}

	Wrapper data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model.t1.collapsed = false;
	model.t2.collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}
	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		Comparator cmpr;
		auto etalon = node("Wrapper", V, 0, 0, 300, 10, vector!(Mallocator, Node)([ 
				node("Test", H, 10, 10, 290, 10, vector!(Mallocator, Node)([
					node("float", 10, 10, 96, 10), node("int", 10+96, 10, 97, 10), node("string", 10+96+97, 10, 290-96-97, 10),
				])), 
				node("Test", V, 10, 20, 290, 10, vector!(Mallocator, Node)([ 
					node("float", 20, 30, 280, 10), 
					node("int", 20, 40, 280, 10), 
					node("string", 20, 50, 280, 10),
				])),
		]));

		const ubyte byAllFieldsButXpos = CompareBy.allFields;// & !CompareBy.Xpos;
		cmpr.compare(visitor.current, etalon, byAllFieldsButXpos);
		import std;
		writeln(cmpr.sResult);
		writeln(cmpr.path);
		cmpr.bResult.shouldBeTrue;
	}();
}

version(unittest) @Name("twoHorizontalAggregate")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	struct Test1
	{
		double d;
		short sh;
		Test t;
	}

	static struct Wrapper
	{
		@("Orientation.Horizontal")
		Test1 t1;
		@("Orientation.Horizontal")
		Test1 t2;
	}

	Wrapper data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model.t1.collapsed = false;
	model.t2.collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}
	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		(*visitor.position).should.be ==
			State("Wrapper", 0, 0, 300, 590, vector!Mallocator([
				state("Test1", 10, 10, 290, 10, vector!Mallocator([ 
					state("double", 10, 10, 96, 10), state("short", 106, 10, 97, 10), state("Test", 203, 10, 97, 10), 
				])),
				state("Test1", 10, 20, 290, 10, vector!Mallocator([ 
					state("double", 10, 20, 96, 10), state("short", 106, 20, 97, 10), state("Test", 203, 20, 97, 10)
				])),
		]));
	}();
}

version(unittest) @Name("MixedLayoutN0")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	static struct Test1
	{
		double d;
		@("Orientation.Vertical")
		Test t;
		short sh;
	}

	static struct Test2
	{
		double d = 9.98;
		@("Orientation.Horizontal")
		Test1 t1;
		string str = "cool";
	}

	Test2 data;

	auto visitor = Visitor2D([299, 9]);
	visitor.orientation = visitor.orientation.Vertical;
	auto model = makeModel(data);
	model.collapsed = false;
	model.t1.collapsed = false;
	model.t1.t.collapsed = false;
	{
		auto mv = MeasuringVisitor([299, 9]);
		model.visitForward(data, mv);
	}
	visitor.loc.y.destination = visitor.loc.y.destination.max;
	model.visitForward(data, visitor);

	() @trusted
	{
		(*visitor.position).should.be ==
			State("Test2", 0, 0, 300, 10, vector!Mallocator([     /* Test2 (Header) */
				state("double", 10, 10, 290, 10),  /* Test2.d */
				state("Test1", 10, 20, 290, 10, vector!Mallocator([  /* Test2.t1 (Header) */
					// Test1.d           Test1.t (Header)                      Test1.sh
					state("double", 10, 20, 96, 10), state("Test", 106, 20, 96, 10, vector!Mallocator([ 
					                        state("float", 116, 30, 86, 10), /* Test.f */
					                        state("int", 116, 40, 86, 10), /* Test.i */
					                        state("string", 116, 50, 86, 10), /* Test.s */
										])),
					                                                           state("short", 203, 20, 97, 10), 
				])),
				state("string", 10, 60, 290, 10),  /* Test2.str */
		]));
	}();
}
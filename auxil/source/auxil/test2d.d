module auxil.test2d;

version(unittest) import unit_threaded : Name, should, be;

import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator : make;
import automem.vector : Vector, vector;

import auxil.model;
import auxil.default_visitor : TreePathVisitorImpl, MeasuringVisitor;
import auxil.location : SizeType, Axis;

extern(C++) class Base
{
	extern(D):

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

	alias ThisType = typeof(this);

	void toString(void delegate(in char[]) sink) const
	{
		sink(ThisType.stringof);
		sink("()");
	}

	string toString() const
	{
		import std.array : appender;
		import std.exception : assumeUnique;

		auto a = appender!(char[]);
		toString((in char[] data) { a.put(data); });

		return assumeUnique(a.data);
	}
}

extern(C++) class Leaf : Base
{
	extern(D):
	@safe:
	string name;
	Axis x, y;

	this(string name, ref Axis x, ref Axis y) @nogc
	{
		this.name = name;
		this.x = x;
		this.y = y;
	}

	this(string name, SizeType x, SizeType y, SizeType w, SizeType h) @nogc
	{
		this.name = name;
		this.x.position = x;
		this.y.position = y;
		this.x.size = w;
		this.y.size = h;
	}

	alias ThisType = typeof(this);

	override void toString(void delegate(in char[]) sink) @trusted const
	{
		import std.algorithm : copy;
		import std.conv : text;

		text(ThisType.stringof, "(`", 
			name, "`, ",
			x.position, ", ",
			y.position, ", ",
			x.size, ", ",
			y.size, ")"
		).copy(sink);
	}

	bool opEquals(Base other)
	{
		Leaf o;
		() @trusted { o = cast(Leaf) other; } ();
		if (o)
		{
			if (ignoreField == IgnoreField.all)
				return true;

			if (name != o.name)
				return false || (ignoreField & IgnoreField.name);
			if (x.position != o.x.position)
				return false || (ignoreField & IgnoreField.Xpos);
			if (x.size != o.x.size)
				return false || (ignoreField & IgnoreField.Xsize);
			if (y.position != o.y.position)
				return false || (ignoreField & IgnoreField.Ypos);
			if (y.size != o.y.size)
				return false || (ignoreField & IgnoreField.Ysize);

			return true;
		}

		return false;
	}
}

auto leaf(Args...)(Args args)
{
	return Mallocator.instance.make!Leaf(args);
}

extern(C++) class Node : Leaf
{
	import std.algorithm : equal, map;

	extern(D):
	@safe:

	alias Children = Vector!(Node, Mallocator);
	Children children;
	Orientation orientation;

	this(string name, ref Axis x, ref Axis y, Children children) @nogc
	{
		super(name, x, y);
		this.children = children;
	}

	this(string name, SizeType x, SizeType y, SizeType w, SizeType h, Children children = Children()) @nogc
	{
		super(name, x, y, w, h);
		this.children = children;
	}

	this(string name, Orientation o, ref Axis x, ref Axis y, Children children = Children()) @nogc
	{
		super(name, x, y);
		this.orientation = o;
		this.children = children;
	}

	this(string name, Orientation o, SizeType x, SizeType y, SizeType w, SizeType h, Children children = Children()) @nogc
	{
		this(name, x, y, w, h);
		this.orientation = o;
		this.children = children;
	}

	void addChild(Node n) @trusted
	{
		children ~= n;
	}

	alias ThisType = typeof(this);

	override void toString(void delegate(in char[]) sink) @trusted const
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

	override bool opEquals(Base other)
	{
		Leaf o;
		() @trusted { o = cast(Leaf) other; } ();
		if (o)
		{
			if (!super.opEquals(o))
				return false;
		}
		Node node;
		() @trusted { node = cast(Node) other; } ();
		if (node)
		{
			if (() @trusted { return !children[].equal(node.children[]); } ())
				return false || (ignoreField & IgnoreField.children);
			if (orientation != node.orientation)
				return false || (ignoreField & IgnoreField.orientation);

			return true;
		}
		return false;
	}
}

auto node(Args...)(Args args)
{
	return Mallocator.instance.make!Node(args);
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
		import std;
		visitor.current.writeln;
		// version(all) Base.ignoreField |= Base.IgnoreField.Xpos;
		writeln(cast(Node) visitor.current);
		assert(visitor.current.opEquals( 
			node("Wrapper", V, 0, 0, 300, 10, vector!(Mallocator, Node)([ 
				node("Test", H, 10, 10, 290, 10, vector!(Mallocator, Node)([
					node("float", 10, 10, 96, 10), node("int", 10+96, 10, 97, 10), node("string", 10+96+97, 10, 290-96-97, 10),
				])), 
				node("Test", V, 10, 20, 290, 10, vector!(Mallocator, Node)([ 
					node("float", 20, 30, 280, 10), 
					node("int", 20, 40, 280, 10), 
					node("string", 20, 50, 280, 10),
				])),
		]))));

		// version(all) State.ignoreField |= State.IgnoreField.Xpos;
		// (*visitor.position).should.be ==
		// 	State("Wrapper", V, 0, 0, 300, 10, vector!Mallocator([ 
		// 		state("Test", H, 10, 10, 290, 10, vector!Mallocator([
		// 			state("float", H, 10, 10, 96, 10), state("int", H, 10+96, 10, 97, 10), state("string", H, 10+96+97, 10, 290-96-97, 10),
		// 		])), 
		// 		state("Test", V, 10, 20, 290, 10, vector!Mallocator([ 
		// 			state("float", V, 20, 30, 280, 10), 
		// 			state("int", V, 20, 40, 280, 10), 
		// 			state("string", V, 20, 50, 280, 10),
		// 		])),
		// ]));
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
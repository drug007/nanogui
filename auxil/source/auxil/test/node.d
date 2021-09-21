module auxil.test.node;

import std.experimental.allocator.mallocator : Mallocator;
import automem.vector : Vector;

import auxil.model : Orientation;
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

	this(string name, Orientation o, SizeType x, SizeType y, SizeType w, SizeType h, Node[] children) @nogc
	{
		this.name = name;
		this.x.position = x;
		this.y.position = y;
		this.x.size = w;
		this.y.size = h;
		this.orientation = o;
		this.children = children;
		this.children = Children(children);
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
	import std.experimental.allocator : make;
	return Mallocator.instance.make!Node(args);
}

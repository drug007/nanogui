import std.stdio;
import std.algorithm : map;
import std.container.rbtree;
import core.thread.fiber;

struct Item
{
	uint id;
	string description;
}

struct ItemPtr
{
	uint id;
	Item* payload;

	this(uint i)
	{
		id = i;
		payload = null;
	}

	this(ref Item i)
	{
		id = i.id;
		payload = &i;
	}

	this(uint i, Item* p)
	{
		id = i;
		payload = p;
	}
}

struct ItemIndex
{
	alias Impl = RedBlackTree!(ItemPtr, "a.id < b.id");
	Impl _impl;
	alias _impl this;

	auto keys()
	{
		import std.array : array;
		return _impl[].map!"a.id".array;
	}

	struct Range
	{
		import std.array : back, empty, front, popBack, popFront;

		alias Type = ItemPtr;
		alias Keys = typeof(ItemIndex.init.keys());
		private ItemIndex* _idx;
		private Keys _keys;

		this(ref ItemIndex si)
		{
			_idx = &si;
			_keys = si.keys;
		}

		this(ItemIndex* i, Keys k)
		{
			_idx = i;
			_keys = k;
		}

		@disable this();

		bool empty()
		{
			return _keys.empty;
		}

		Type front()
		{
			auto e = ItemPtr(_keys.front);
			return _idx.equalRange(e).front;
		}

		void popFront()
		{
			_keys.popFront;
		}

		Type back()
		{
			auto e = ItemPtr(_keys.front);
			return _idx.equalRange(e).front;
		}

		void popBack()
		{
			_keys.popBack;
		}

		typeof(this) save()
		{
			auto instance = this;
			instance._keys = _keys.dup;
			return instance;
		}

		Type opIndex(size_t idx)
		{
			auto e = ItemPtr(_keys.front);
			return _idx.equalRange(e).front;
		}

		size_t length()
		{
			return _keys.length;
		}
	}

	auto opIndex(uint i)
	{
		return _impl.equalRange(ItemPtr(i, null)).front;
	}

	auto opSlice()
	{
		return Range(this);
	}
}

struct A
{
	int i;
	string s;
}

struct B
{
	float f;
	double d;
	long l;
}

struct C
{
	A a;
	int i;
	B[2] b2;
}

struct D
{
	A a;
	B b;
	C[3] c;
}

void main()
{
	Item[] data = [
		Item(100, "item100"),
		Item(200, "item200"),
		Item(50, "item50"),
	];

	auto index = ItemIndex();
	index._impl = new ItemIndex.Impl(data.map!((ref a)=>ItemPtr(a.id, &a)));

	writeln(index[].map!"*a.payload");
	writeln(*index[100].payload);

	auto idx = index[];
	
	void fiberFunc()
	{
		while(!idx.empty)
		{
			writeln(*idx.front.payload);
			idx.popFront;
			Fiber.yield();
		}
	}

	// create instances of each type
	scope Fiber composed = new Fiber( &fiberFunc );

	composed.call();
	composed.call();
	composed.call();
	composed.call();

	// since each fiber has run to completion, each should have state TERM
	assert( composed.state == Fiber.State.TERM );

	import auxil.model;

	D d;
	auto model = makeModel(d);
	
	MyVisitor visitor;
	writeln("start");
	model.visitForward(d, visitor);
}

struct Positioner
{
	string indentation;

	void nextLine()
	{
		write("\n", indentation);
	}

	void put(Args...)(Args args)
	{
		write(indentation, args);
	}

	void indent()
	{
		indentation ~= "  ";
	}

	void unindent()
	{
		if (indentation.length)
			indentation = indentation[0..$-2];
	}
}

struct Styler
{

}

struct MyVisitor
{
	import auxil.model : TreePath;

	enum treePathNGEnabled = true;
	enum treePathEnabled = false;
	enum sizeEnabled = false;

	TreePath tree_path;
	Positioner p;

	bool complete() @safe @nogc { return false; }
	void enterTree(alias order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		p.put("Enter Tree: ", Data.stringof);
		p.nextLine;
	}

	auto enterNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		p.put("Enter Node: ", Data.stringof, " ", tree_path);
		p.indent;
		p.nextLine;

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		p.put("Leave Node: ", Data.stringof);
		p.unindent;
		p.nextLine;
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		p.put("Process Leaf: ", Data.stringof, " ", data, " ", tree_path);
		p.nextLine;
	}

}

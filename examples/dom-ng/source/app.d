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

struct Main
{
	NodeA a;
	NodeA2 a2;
}

struct NodeA
{
	NodeB b;
}

struct NodeA2
{
	double d;
	NodeB b;
}

struct NodeB
{
	int i;
	float f;
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

	// create instances of each type
	scope Fiber composed = new Fiber(()
	{
		while(!idx.empty)
		{
			writeln(*idx.front.payload);
			idx.popFront;
			Fiber.yield();
		}
	});

	composed.call();
	composed.call();
	composed.call();
	composed.call();

	// since each fiber has run to completion, each should have state TERM
	assert( composed.state == Fiber.State.TERM );

	import std.algorithm;
	import auxil.model;

	D d;
	Main m;

	// The tree of one node containing leaves only
	{
		auto model = makeModel(m.a.b);
		
		MyVisitor!() visitor;
		model.visitForward(m.a.b, visitor);
		writeln("\n---");
		writeln(visitor.log);
		assert(visitor.log.equal([
			[],  // B
			[0], // B.i
			[1], // B.f
		]));
	}
	// The tree of one node containing single node that contains leaves only
	{
		auto model = makeModel(m.a);
		
		MyVisitor!() visitor;
		model.visitForward(m.a, visitor);
		writeln("\n---");
		writeln(visitor.log);
		// as A contains only single member 
		// N.B. in previous edition this member B was substituted
		// instead of A (like A didn't exist)
		assert(visitor.log.equal([
			[],     // a
			[0],    // b
			[0, 0], // b.i
			[0, 1], // b.f
		]));
	}
	// The tree of one node containing several node(s)/list(s)
	{
		auto model = makeModel(m.a2);
		
		MyVisitor!() visitor;
		model.visitForward(m.a2, visitor);
		writeln("\n---");
		writeln(visitor.log);
		assert(visitor.log.equal([
			[],     // a2
			[0],    // a2.d
			[1],    // a2.b
			[1, 0], // a2.b.i
			[1, 1], // a2.b.f
		]));
	}
	// traversal in back direction
	{
		auto model = makeModel(m.a2);
		
		MyVisitor!() visitor;
		model.visitBackward(m.a2, visitor);
		writeln("\n---");
		writeln(visitor.log);
		assert(visitor.log.equal([
			[],     // a2
			[1],    // a2.b
			[1, 1], // a2.b.f
			[1, 0], // a2.b.i
			[0],    // a2.d
		]));
	}
	// traversal to the specific tree path in forward direction
	{
		auto model = makeModel(m.a2);
		
		MyVisitor!() visitor;
		visitor.target.value = [1, 0];
		model.visitForward(m.a2, visitor);
		writeln("\n---");
		writeln(visitor.log);
		assert(visitor.log.equal([
			[],     // a2
			[0],    // a2.d
			[1],    // a2.b
			[1, 0], // a2.b.i
		]));
	}
	// traversal to the specific tree path in backward direction
	{
		auto model = makeModel(m.a2);
		
		MyVisitor!() visitor;
		visitor.target.value = [1, 0];
		model.visitBackward(m.a2, visitor);
		writeln("\n---");
		writeln(visitor.log);
		assert(visitor.log.equal([
			[],     // a2
			[1],    // a2.b
			[1, 1], // a2.b.f
			[1, 0], // a2.b.i
		]));
	}
	// a fiber traverses to the specific tree path in backward direction
	{
		auto model = makeModel(m.a2);
		
		MyVisitor!(true) visitor;
		visitor.target.value = [1, 0];
		
		scope fiberVisitor = new Fiber( ()
		{
			model.visitBackward(m.a2, visitor);
		});

		TreePath[] fiberLog;
		while(fiberVisitor.state != Fiber.State.TERM)
		{
			fiberVisitor.call();
			if (!visitor.complete)
				fiberLog ~= visitor.tree_path;
		}

		assert(visitor.log.equal(fiberLog));

		writeln("\n---");
		writeln(visitor.log);
		assert(visitor.log.equal([
			[],     // a2
			[1],    // a2.b
			[1, 1], // a2.b.f
			[1, 0], // a2.b.i
		]));
	}
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

struct MyVisitor(bool fibered = false)
{
	import auxil.model : TreePath;

	enum treePathNGEnabled = true;
	enum treePathEnabled = false;
	enum sizeEnabled = false;

	TreePath tree_path;
	Positioner p;

	TreePath[] log;

	TreePath target;
	private bool _complete;

	bool complete() @trusted @nogc
	{
		return _complete;
	}

	void enterTree(alias order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		p.put("Enter Tree: ", Data.stringof);
		p.nextLine;
	}

	auto enterNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		log ~= tree_path;
		p.put("Enter Node: ", Data.stringof, " ", tree_path);
		p.indent;
		p.nextLine;
		static if (fibered) Fiber.yield();
		{
			_complete = !target.value.empty && tree_path.value[] == target.value[];
		}

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		p.put("Leave Node: ", Data.stringof);
		p.unindent;
		p.nextLine;
		static if (fibered) Fiber.yield();
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{

		log ~= tree_path;
		p.put("Process Leaf: ", Data.stringof, " ", data, " ", tree_path);
		p.nextLine;
		static if (fibered) Fiber.yield();
		{
			_complete = !target.value.empty && tree_path.value[] == target.value[];
		}
	}
}

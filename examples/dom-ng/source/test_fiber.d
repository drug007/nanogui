module test_fiber;

import core.thread.fiber;
import std.stdio;
import std.algorithm;

import auxil.model;

import test_data;
import common;

struct MyVisitor
{
	import auxil.model : TreePath;

	enum treePathNGEnabled = true;
	enum treePathEnabled = false;
	enum sizeEnabled = false;

	TreePath tree_path;

	TreePath[] log;

	TreePath path;
	private bool _complete;
	enum headerSize = 30.0;
	enum childSize  = 15.0;

	bool complete() @trusted @nogc
	{
		return _complete;
	}

	void enterTree(alias order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
	}

	void indent() {}
	void unindent() {}

	auto enterNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		log ~= tree_path;
		model.size = headerSize;
		Fiber.yield();
		{
			_complete = !path.value.empty && tree_path.value[] == path.value[];
		}

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{

		log ~= tree_path;
		model.size = childSize;
		Fiber.yield();
		{
			_complete = !path.value.empty && tree_path.value[] == path.value[];
		}
	}
}

// set size of the tree nodes
struct SizeSetter
{
	enum treePathNGEnabled = false;
	enum treePathEnabled = false;
	enum sizeEnabled = true;

	enum size = 15;

	bool complete() @trusted @nogc
	{
		return false;
	}

	void enterTree(alias order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
	}

	void indent() {}
	void unindent() {}

	auto enterNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		Fiber.yield();

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		Fiber.yield();
	}
}

// get size of the tree nodes
struct Positioner
{
	enum treePathNGEnabled = false;
	enum treePathEnabled = false;
	enum sizeEnabled = false;

	double size, position;

	@disable this();

	this(double size)
	{
		this.size = size;
	}

	this(double size, double position)
	{
		this.size = size;
		this.position = position;
	}

	bool complete() @trusted @nogc
	{
		return false;
	}

	void enterTree(alias order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		position = 0;
	}

	void indent() {}
	void unindent() {}

	auto enterNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		Fiber.yield();
		position += model.header_size;

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		Fiber.yield();
		position += model.size;
	}
}

// a fiber traverses to the specific tree path in forward direction
void testRunningFiberInLoop()
{
	auto model = makeModel(m.a2);
	model.collapsed = false;
	model.b.collapsed = false;
	
	MyVisitor visitor;
	
	scope fiberVisitor = new Fiber(()
	{
		model.visitForward(m.a2, visitor);
	});

	TreePath[] fiberLog;
	foreach(_; 0..3)
	{
		fiberLog = null;
		visitor.log = null;
		visitor.path.value = [1, 0];
		visitor.tree_path.value.clear;
		visitor._complete = false;
		fiberVisitor.reset;
		while(fiberVisitor.state != Fiber.State.TERM)
		{
			fiberVisitor.call();
			if (!visitor.complete)
			{
				fiberLog ~= visitor.tree_path;
			}
		}

		fiberLog.each!writeln;
		assert(visitor.log.equal(fiberLog));

		writeln("\n---");
		writeln(visitor.log);
		assert(visitor.log.equal([
			[],     // a2
			[1],    // a2.b
					// a2.b.f skipped
			[1, 0], // a2.b.i
		]));
	}
}

// a fiber traverses to the specific tree path in forward direction
void testFiberRange()
{
	auto model = makeModel(m.a2);
	model.collapsed = false;
	model.b.collapsed = false;
	
	MyVisitor visitor;

	auto etalon = [
		MyVisitor(TreePath([]),     [TreePath([])],                                  TreePath([1, 0]), false),
		MyVisitor(TreePath([1]),    [TreePath([]), TreePath([1])],                   TreePath([1, 0]), false),
		MyVisitor(TreePath([1, 0]), [TreePath([]), TreePath([1]), TreePath([1, 0])], TreePath([1, 0]), false),
	];

	TreePath[] fiberLog;
	{
		fiberLog = null;
		visitor.log = null;
		visitor.path.value = [1, 0];
		visitor.tree_path.value.clear;
		visitor._complete = false;
		auto r = visitor.makeRange(()
		{
			model.visitForward(m.a2, visitor);
		});

		import std.range : front, popFront;
		auto e = etalon[];
		for(;!r.empty; r.popFront, e.popFront)
		{
			assert(e.front == r.front);
		}

		// once again
		visitor = MyVisitor();
		visitor.path.value = [1, 0];
		r = visitor.makeRange(()
		{
			model.visitForward(m.a2, visitor);
		});
		
		e = etalon[];
		for(;!r.empty; r.popFront, e.popFront)
		{
			assert(e.front == r.front);
		}
	}
}

// a fiber calculates size of the tree elements
void testFiberCalculateSize()
{
	auto model = makeModel(m.a2);
	model.collapsed = false;
	model.b.collapsed = false;
	
	SizeSetter sizeSetter;

	auto r = sizeSetter.makeRange(()
	{
		model.visitForward(m.a2, sizeSetter);
	});

	// consume the range
	for(; !r.empty; r.popFront) {}

	auto positioner = Positioner(15);

	auto r2 = positioner.makeRange(()
	{
		model.visitForward(m.a2, positioner);
	});
	auto etalon = [
		Positioner(15,  0),
		Positioner(15, 16),
		Positioner(15, 32),
		Positioner(15, 48),
		Positioner(15, 64),
	];
	import std.range : front, popFront;
	for(;!r2.empty;r2.popFront, etalon.popFront)
		assert(r2.front == etalon.front);
}
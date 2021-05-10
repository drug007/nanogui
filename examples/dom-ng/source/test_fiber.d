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
	enum sizeEnabled = false;

	enum headerSize = 30.0;
	enum childSize  = 15.0;

	bool complete() @trusted @nogc
	{
		return false;
	}

	void enterTree(alias order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
	}

	auto enterNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		model.size = headerSize;
		Fiber.yield();

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		model.size = childSize;
		Fiber.yield();
	}
}

// get size of the tree nodes
struct SizeGetter
{
	enum treePathNGEnabled = false;
	enum treePathEnabled = false;
	enum sizeEnabled = false;

	double[] sizeLog;

	bool complete() @trusted @nogc
	{
		return false;
	}

	void enterTree(alias order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
	}

	auto enterNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		sizeLog ~= model.size;
		Fiber.yield();

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		sizeLog ~= model.size;
		Fiber.yield();
	}
}

// a fiber traverses to the specific tree path in forward direction
void testRunningFiberInLoop()
{
	auto model = makeModel(m.a2);
	
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
		assert(r.equal(etalon));

		// once again
		visitor = MyVisitor();
		visitor.path.value = [1, 0];
		r = visitor.makeRange(()
		{
			model.visitForward(m.a2, visitor);
		});
		assert(r.equal(etalon));
	}
}

// a fiber calculates size of the tree elements
void testFiberCalculateSize()
{
	auto model = makeModel(m.a2);
	
	SizeSetter sizeSetter;

	auto r = sizeSetter.makeRange(()
	{
		model.visitForward(m.a2, sizeSetter);
	});

	// consume the range
	foreach(_; r) {}

	SizeGetter sizeGetter;

	auto r2 = sizeGetter.makeRange(()
	{
		model.visitForward(m.a2, sizeGetter);
	});

	assert(r2.equal([
		SizeGetter([30]),
		SizeGetter([30, 15]),
		SizeGetter([30, 15, 30]),
		SizeGetter([30, 15, 30, 15]),
		SizeGetter([30, 15, 30, 15, 15]),
	]));
}
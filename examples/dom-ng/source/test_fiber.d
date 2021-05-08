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
		Fiber.yield();
		{
			_complete = !path.value.empty && tree_path.value[] == path.value[];
		}

		return false;
	}

	void leaveNode(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{
		Fiber.yield();
	}

	void processLeaf(alias order, Data, Model)(ref const(Data) data, ref Model model)
	{

		log ~= tree_path;
		Fiber.yield();
		{
			_complete = !path.value.empty && tree_path.value[] == path.value[];
		}
	}
}

// a fiber traverses to the specific tree path in forward direction
void testFiber1()
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
	{
		fiberLog = null;
		visitor.log = null;
		visitor.path.value = [1, 0];
		visitor.tree_path.value.clear;
		visitor._complete = false;
		fiberVisitor.reset;
		auto r = visitor.makeRange(()
		{
			model.visitForward(m.a2, visitor);
		});
		r.each!((ref a)=>writeln(a));
		writeln("---");
		visitor = MyVisitor();
		visitor.path.value = [1, 0];
		r = visitor.makeRange(()
		{
			model.visitForward(m.a2, visitor);
		});
		r.each!((ref a)=>writeln(a));
	}
}
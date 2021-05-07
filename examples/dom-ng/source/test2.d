module test2;

import std.algorithm : equal;
import std.stdio;

import auxil.model;

import test_data;

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

struct MyVisitor
{
	import auxil.model : TreePath;

	enum treePathNGEnabled = true;
	enum treePathEnabled = false;
	enum sizeEnabled = false;

	enum State { seeking, first, rest, finishing, }
	State state;
	TreePath tree_path;
	Positioner p;

	TreePath[] log;

	TreePath path;
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
		{
			_complete = !path.value.empty && tree_path.value[] == path.value[];
		}

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

		log ~= tree_path;
		p.put("Process Leaf: ", Data.stringof, " ", data, " ", tree_path);
		p.nextLine;
		{
			_complete = !path.value.empty && tree_path.value[] == path.value[];
		}
	}
}

// The tree of one node containing leaves only
void testTree1()
{
	auto model = makeModel(m.a.b);
	
	MyVisitor visitor;
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
void testTree2()
{
	auto model = makeModel(m.a);
	
	MyVisitor visitor;
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
void testTree3()
{
	auto model = makeModel(m.a2);
	
	MyVisitor visitor;
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
void testTree4()
{
	auto model = makeModel(m.a2);
	
	MyVisitor visitor;
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
void testTree5()
{
	auto model = makeModel(m.a2);
	
	MyVisitor visitor;
	visitor.path.value = [1, 0];
	model.visitForward(m.a2, visitor);
	writeln("\n---");
	writeln(visitor.log);
	assert(visitor.log.equal([
		[],     // a2
				// a2.d skipped
		[1],    // a2.b
		[1, 0], // a2.b.i
	]));
}

// traversal to the specific tree path in backward direction
void testTree6()
{
	auto model = makeModel(m.a2);
	
	MyVisitor visitor;
	visitor.path.value = [1, 0];
	model.visitBackward(m.a2, visitor);
	writeln("\n---");
	writeln(visitor.log);
	assert(visitor.log.equal([
		[],     // a2
		[1],    // a2.b
				// a2.b.f skipped
		[1, 0], // a2.b.i
	]));
}
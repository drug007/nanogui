module auxil.test2d;

version(unittest) import unit_threaded : Name, should, be, shouldBeTrue;

import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator : make;
import automem.vector : Vector, vector;

import auxil.model;
import auxil.default_visitor : TreePathVisitorImpl, MeasuringVisitor;
import auxil.location : SizeType, Axis;
import auxil.test.node : node, Node;
import auxil.test.comparator : Comparator, CompareBy;

private enum H = Orientation.Horizontal;
private enum V = Orientation.Vertical;

@safe private
struct Visitor2D
{
	import auxil.test.node : Node;

	alias TreePathVisitor = TreePathVisitorImpl!(typeof(this));
	TreePathVisitor default_visitor;
	alias default_visitor this;

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
		foreach(_; 0..node_stack.length)
			write(prefix);
	}

	void enterTree(Order order, Data, Model)(ref const(Data) data, ref Model model) {}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (Model.Collapsable || order == Order.Sinking)
		{
			() @trusted {
				auto n = new Node(Data.stringof, orientation, loc.x, loc.y);
				if (current !is null)
				{
					current.addChild(n);
					node_stack ~= current;
				}
				current = n;
			} ();
		}
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		() @trusted {
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
		Comparator cmpr;
		auto etalon =
			node("Test[2]", V, 0, 0, 300, 10, [
				node("Test", V, 10, 10, 290, 10, [ 
					node("float", 20, 20, 280, 10), 
					node("int", 20, 30, 280, 10), 
					node("string", 20, 40, 280, 10),
				]),
				node("Test", V, 10, 50, 290, 10, [
					node("float", 20, 60, 280, 10), 
					node("int", 20, 70, 280, 10), 
					node("string", 20, 80, 280, 10),
				]),
			]);

		cmpr.compare(visitor.current, etalon, CompareBy.allFields);
		import std.stdio : writeln;
		writeln(cmpr.sResult);
		writeln(cmpr.path);
		cmpr.bResult.shouldBeTrue;
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
	visitor.current = null;
	model.visitForward(data, visitor);

	() @trusted
	{
		Comparator cmpr;
		auto etalon =
			node("Test[2]", V, 0, 0, 300, 10, [
				node("Test", V, 10, 10, 290, 10, [ 
					node("float", 10, 10, 96, 10,), node("int", 10+96, 10, 97, 10), node("string", 10+96+97, 10, 290-96-97, 10),
				]),
				node("Test", V, 10, 20, 290, 10, [
					node("float", 20, 30, 280, 10), 
					node("int", 20, 40, 280, 10), 
					node("string", 20, 50, 280, 10),
				]), 
			]);

		cmpr.compare(visitor.current, etalon, CompareBy.allFields);
		import std.stdio : writeln;
		writeln(cmpr.sResult);
		writeln(cmpr.path);
		cmpr.bResult.shouldBeTrue;
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
		auto etalon = node("Wrapper", V, 0, 0, 300, 10, [ 
				node("Test", H, 10, 10, 290, 10, [
					node("float", 10, 10, 96, 10), node("int", 10+96, 10, 97, 10), node("string", 10+96+97, 10, 290-96-97, 10),
				]), 
				node("Test", V, 10, 20, 290, 10, [ 
					node("float", 20, 30, 280, 10), 
					node("int", 20, 40, 280, 10), 
					node("string", 20, 50, 280, 10),
				]),
		]);

		cmpr.compare(visitor.current, etalon, CompareBy.allFields);
		import std.stdio : writeln;
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
		Comparator cmpr;

		auto etalon =
			node("Wrapper", V, 0, 0, 300, 590, [
				node("Test1", H, 10, 10, 290, 10, [ 
					node("double", 10, 10, 96, 10), node("short", 106, 10, 97, 10), node("Test", V, 203, 10, 97, 10), 
				]),
				node("Test1", H, 10, 20, 290, 10, [ 
					node("double", 10, 20, 96, 10), node("short", 106, 20, 97, 10), node("Test", V, 203, 20, 97, 10)
				]),
		]);

		cmpr.compare(visitor.current, etalon, CompareBy.allFields);
		import std.stdio : writeln;
		writeln(cmpr.sResult);
		writeln(cmpr.path);
		cmpr.bResult.shouldBeTrue;
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
		Comparator cmpr;

		auto etalon =
			node("Test2", V, 0, 0, 300, 10, [     /* Test2 (Header) */
				node("double", V, 10, 10, 290, 10),  /* Test2.d */
				node("Test1", H, 10, 20, 290, 10, [  /* Test2.t1 (Header) */
					// Test1.d           Test1.t (Header)                      Test1.sh
					node("double", H, 10, 20, 96, 10), node("Test", V, 106, 20, 96, 10, [ 
					                        node("float", 116, 30, 86, 10), /* Test.f */
					                        node("int", 116, 40, 86, 10), /* Test.i */
					                        node("string", 116, 50, 86, 10), /* Test.s */
										]),
					                                                           node("short", 203, 20, 97, 10), 
				]),
				node("string", V, 10, 60, 290, 10),  /* Test2.str */
		]);

		cmpr.compare(visitor.current, etalon, CompareBy.allFields);
		import std.stdio : writeln;
		writeln(cmpr.sResult);
		writeln(cmpr.path);
		cmpr.bResult.shouldBeTrue;
	}();
}
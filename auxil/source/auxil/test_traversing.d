module aux.test_traversing;

version (unittest):

import unit_threaded : should, be, Name;
import std.experimental.allocator.mallocator : Mallocator;
import automem.vector : Vector;

import aux.model : Order, makeModel, visitForward, MeasureVisitor, 
	TreePathVisitor, Orientation, visitBackward;

struct PositionState
{
	import std.range : isOutputRange;

	string label;
	int[] path;
	double[2] pos, dest, last_change;
	TreePathVisitor.State state;

	@disable this();

	this(string l, int[] p, double[2] ps, double[2] d, double[2] lc, TreePathVisitor.State s)
	{
		label = l;
		path = p;
		pos = ps;
		dest = d;
		state = s;
		last_change = lc;
	}

	bool opEquals(ref const(typeof(this)) other) const
	{
		return opCmp(other) == 0;
	}

	int opCmp(ref const(typeof(this)) other) const
	{
		import std.math : approxEqual;

		if (label < other.label)
			return -1;
		if (label > other.label)
			return +1;

		if (path < other.path)
			return -1;
		if (path > other.path)
			return +1;

		if (!pos[0].approxEqual(other.pos[0]))
		{
			if (pos[0] < other.pos[0])
				return -1;
			if (pos[0] > other.pos[0])
				return +1;
		}

		if (!pos[1].approxEqual(other.pos[1]))
		{
			if (pos[1] < other.pos[1])
				return -1;
			if (pos[1] > other.pos[1])
				return +1;
		}

		if (!dest[0].approxEqual(other.dest[0]))
		{
			if (dest[0] < other.dest[0])
				return -1;
			if (dest[0] > other.dest[0])
				return +1;
		}

		if (!dest[1].approxEqual(other.dest[1]))
		{
			if (dest[1] < other.dest[1])
				return -1;
			if (dest[1] > other.dest[1])
				return +1;
		}

		if (!last_change[0].approxEqual(other.last_change[0]))
		{
			if (last_change[0] < other.last_change[0])
				return -1;
			if (last_change[0] > other.last_change[0])
				return +1;
		}

		if (!last_change[1].approxEqual(other.last_change[1]))
		{
			if (last_change[1] < other.last_change[1])
				return -1;
			if (last_change[1] > other.last_change[1])
				return +1;
		}

		if (state < other.state)
			return -1;
		if (state > other.state)
			return +1;

		return 0;
	}

	void toString(W)(ref W writer) const @safe
		if (isOutputRange!(W, string))
	{
		import std.algorithm : copy;
		import std.range : put, repeat;
		import std.format : formattedWrite;
		import std.conv : text;

		copy(typeof(this).stringof, writer);
		writer.put('(');
		auto prefix = '\t'.repeat(path.length);
		formattedWrite(writer, "%s%-19s, path: %6s, pos: %3s, dest: %3s, ch: %3s %s", prefix, label, path.text, pos, dest, last_change, state);
		writer.put(')');
	}
}

struct CheckingVisitor
{
	TreePathVisitor tpvisitor;
	alias tpvisitor this;

	Vector!(PositionState, Mallocator) output_position;

	@disable this();

	this(float width, float height, Orientation orientation)
	{
		tpvisitor = TreePathVisitor(width, height, orientation);
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		// output_orientation.put(OrientationState("enterNode   " ~ Model.stringof ~ " ", model.orientation));

		tpvisitor.enterNode!order(data, model);

		// output_size.put(SizeState("enterNode   " ~ Model.stringof ~ " ", model.size));
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		tpvisitor.leaveNode!order(data, model);

		// output_size.put(SizeState("leaveNode   " ~ Model.stringof ~ " ", model.size));
		// output_orientation.put(OrientationState("leaveNode   " ~ Model.stringof ~ " ", model.orientation));
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		// output_orientation.put(OrientationState("processLeaf " ~ Model.stringof ~ " ", model.orientation));

		tpvisitor.processLeaf!order(data, model);

		// output_size.put(SizeState("processLeaf " ~ Model.stringof ~ " ", model.size));
	}

	void onEnterTree(Data, Model)(ref const(Data) data, ref Model model)
	{
		output_position.put(PositionState("onEnterTree", tree_path.value[].dup, position, destination, last_change, state));
	}

	// void onBeforeStateCheck(Order order, Data, Model)(ref const(Data) data, ref Model model)
	// {
	// 	output_position.put(PositionState("onBeforeStateCheck", tree_path.value[].dup, position, destination, last_change, state));
	// }

	// void onAfterStateCheck(Order order, Data, Model)(ref const(Data) data, ref Model model)
	// {
	// 	output_position.put(PositionState("onAfterStateCheck", tree_path.value[].dup, position, destination, last_change, state));
	// }

	void onBeforeEnterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output_position.put(PositionState("onBeforeEnterNode", tree_path.value[].dup, position, destination, last_change, state));
	}

	void onAfterEnterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output_position.put(PositionState("onAfterEnterNode", tree_path.value[].dup, position, destination, last_change, state));
	}

	void onBeforeLeaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output_position.put(PositionState("onBeforeLeaveNode", tree_path.value[].dup, position, destination, last_change, state));
	}

	void onAfterLeaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output_position.put(PositionState("onAfterLeaveNode", tree_path.value[].dup, position, destination, last_change, state));
	}

	void onBeforeProcessLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output_position.put(PositionState("onBeforeProcessLeaf", tree_path.value[].dup, position, destination, last_change, state));
	}

	void onAfterProcessLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output_position.put(PositionState("onAfterProcessLeaf", tree_path.value[].dup, position, destination, last_change, state));
	}
}

@Name("forward")
unittest
{
	static struct V
	{
		long a;
		char b;
		string c;
	}

	@("orientation.Horizontal")
	static struct H
	{
		long a;
		char b;
		string c;
	}

	static struct VH
	{
		long a;
		H h;
		char b;
	}

	@("orientation.Horizontal")
	static struct HV
	{
		long a;
		V v;
		char b;
	}

	@("orientation.Horizontal")
	static struct HVHV
	{
		long a;
		HV hv;
		char b;
	}

	static struct VHVH
	{
		long a;
		VH vh;
		char b;
	}

	static struct NestedData2
	{
		short sh;
		@("orientation.Horizontal")
		V h;
		string str;
	}

	static struct Data
	{
		int i;
		float f;
		double d;
		string s;
		NestedData2 data2;
	}

	{
		const data = V(1, 'z');
		auto model = makeModel(data);
		model.collapsed = false;
		{
			auto mv = MeasureVisitor(120, 9, Orientation.Vertical);
			model.visitForward(data, mv);
		}
		auto cv = CheckingVisitor(120, 9, Orientation.Vertical);
		cv.position = 0;
		model.visitForward(data, cv);

		{
			import std;
			cv.output_position[].each!writeln;
		}

		// cv.path.clear;
		// cv.position = 0;
		// cv.position[model.orientation] = model.size;
		// cv.output_position.clear;
		// model.visitBackward(data, cv);

		// {
		// 	import std;
		// 	writeln;
		// 	cv.output_position[].each!writeln;
		// }

		// cv.output_orientation[].should.be == [
		// 	OrientationState("enterNode   AggregateModel!(V) ", Orientation.Vertical), 
		// 	OrientationState("processLeaf ScalarModel!(a) ",    Orientation.Horizontal), 
		// 	OrientationState("processLeaf ScalarModel!(b) ",    Orientation.Horizontal), 
		// 	OrientationState("processLeaf ScalarModel!(c) ",    Orientation.Horizontal), 
		// 	OrientationState("leaveNode   AggregateModel!(V) ", Orientation.Vertical)
		// ];

		// cv.output_size[].should.be == [
		// 	SizeState("enterNode   AggregateModel!(V) ", 10), 
		// 	SizeState("processLeaf ScalarModel!(a) ",    10), 
		// 	SizeState("processLeaf ScalarModel!(b) ",    10), 
		// 	SizeState("processLeaf ScalarModel!(c) ",    10), 
		// 	SizeState("leaveNode   AggregateModel!(V) ", 40)
		// ];
	}
}
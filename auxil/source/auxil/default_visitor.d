module auxil.default_visitor;

import std.typecons : Flag;

import auxil.location : Location, SizeType, Order;
import auxil.model : Orientation;

alias SizeEnabled     = Flag!"SizeEnabled";
alias TreePathEnabled = Flag!"TreePathEnabled";

private struct Default
{
	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void beforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void afterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
}

alias MeasuringVisitor = MeasuringVisitorImpl!Default;

/// Visitor to measure size of tree nodes
struct MeasuringVisitorImpl(Derived = Default)
{
	SizeType[2] size;

	this(SizeType[2] s) @safe @nogc nothrow
	{
		size = s;
	}

	enum treePathEnabled = TreePathEnabled.no;

	Orientation orientation = Orientation.Vertical;

	bool complete() @safe @nogc
	{
		return false;
	}

	bool engaged() @safe @nogc nothrow
	{
		return true;
	}

	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
	}

	void doEnterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		model.size = size[orientation] + model.Spacing;
		static if (model.Collapsable)
			model.header_size = model.size;

		version(none) static if (model.Collapsable)
		{
			const old_orientation = visitor.orientation;
			visitor.orientation  = this.orientation;

			scope(exit) visitor.orientation = old_orientation;
		}

		if (engaged)
		{
			() @trusted { (cast(Derived*) &this).enterNode!(order, Data, Model)(data, model); }();
		}
	}

	void doLeaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		if (engaged)
		{
			() @trusted { (cast(Derived*) &this).leaveNode!(order, Data, Model)(data, model); }();
		}
	}

	/// returns true if the current children shouldn't be processed
	/// but traversing should be continued
	bool doBeforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		if (orientation == Orientation.Horizontal)
		{
			size[orientation] -= size[Orientation.Vertical] + model.Spacing;
		}

		() @trusted { (cast(Derived*) &this).beforeChildren!(order, Data, Model)(data, model); }();

		return false;
	}

	void doAfterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		() @trusted { (cast(Derived*) &this).afterChildren!(order, Data, Model)(data, model); }();

		if (orientation == Orientation.Horizontal)
		{
			size[orientation] += size[Orientation.Vertical] + model.Spacing;
		}
	}

	auto startValue(Order order)(size_t len)
	{
		return 0;
	}

	auto setPath(int i)
	{
	}

	auto setChildSize(Model, ChildModel)(ref Model model, ref ChildModel child_model, int len, ref float residual)
	{
		final switch(model.orientation)
		{
			case Orientation.Horizontal:
				double sf = cast(double)(model.size)/len;
				SizeType sz = cast(SizeType)sf;
				residual += sf - sz;
				if (residual >= 1.0)
				{
					residual -= 1;
					sz += 1;
				}
				child_model.size = sz;
			break;
			case Orientation.Vertical:
				model.size += child_model.size;
			break;
		}
	}
}

/// Visitor for traversing tree to do useful job
struct TreePathVisitorImpl(Derived = Default)
{
	SizeType[2] size;

	this(SizeType[2] s) @safe @nogc nothrow
	{
		size = s;
	}

	enum treePathEnabled = TreePathEnabled.yes;

	Location loc;
	Orientation orientation = Orientation.Vertical;

	bool complete() @safe @nogc
	{
		return loc.checkState;
	}

	bool engaged() @safe @nogc nothrow
	{
		return loc.stateFirstOrRest;
	}

	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		loc.y.position = 0;

		final switch (this.orientation)
		{
			case Orientation.Vertical:
				static if (model.Collapsable)
					loc.y.size = model.header_size;
				else
					loc.y.size = model.size;
			break;
			case Orientation.Horizontal:
				loc.y.size = size[this.orientation];
			break;
		}
	}

	void doEnterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		version(none) static if (model.Collapsable)
		{
			const old_orientation = visitor.orientation;
			visitor.orientation  = this.orientation;

			scope(exit) visitor.orientation = old_orientation;
		}

		if (engaged)
		{
			static if (model.Collapsable)
				auto currentSize = model.header_size;
			else
				auto currentSize = model.size;
			loc.enterNode!order(currentSize);
			scope(exit) loc.enterNodeCheck!order;

			() @trusted { (cast(Derived*) &this).enterNode!(order, Data, Model)(data, model); }();
		}
	}

	void doLeaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		if (engaged)
		{
			static if (model.Collapsable)
				auto currentSize = model.header_size;
			else
				auto currentSize = model.size;
			loc.leaveNode!order(currentSize);
			loc.leaveNodeCheck!order;

			() @trusted { (cast(Derived*) &this).leaveNode!(order, Data, Model)(data, model); }();
		}
	}

	/// returns true if the current children shouldn't be processed
	/// but traversing should be continued
	bool doBeforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		() @trusted { (cast(Derived*) &this).beforeChildren!(order, Data, Model)(data, model); }();

		static if (order == Order.Bubbling)
		{
			// Edge case if the start path starts from this collapsable exactly
			// then the childs of the collapsable aren't processed
			if (loc.path.value.length && loc.current_path.value[] == loc.path.value[])
				return true;
		}

		loc.intend;

		return false;
	}

	void doAfterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		loc.unintend;

		() @trusted { (cast(Derived*) &this).afterChildren!(order, Data, Model)(data, model); }();
	}

	auto startValue(Order order)(size_t len)
	{
		return loc.startValue!order(len);
	}

	auto setPath(int i)
	{
		loc.setPath(i);
	}

	auto setChildSize(Model, ChildModel)(ref Model model, ref ChildModel child_model, int len, ref float residual)
	{
	}
}

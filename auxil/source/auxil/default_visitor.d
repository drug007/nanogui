module auxil.default_visitor;

import std.typecons : Flag;

import auxil.location : Location, SizeType, Order;
import auxil.model : Orientation;

alias SizeEnabled     = Flag!"SizeEnabled";
alias TreePathEnabled = Flag!"TreePathEnabled";

alias NullVisitor      = DefaultVisitorImpl!(SizeEnabled.no,  TreePathEnabled.no );
alias MeasuringVisitor = DefaultVisitorImpl!(SizeEnabled.yes, TreePathEnabled.no );
alias TreePathVisitor  = DefaultVisitorImpl!(SizeEnabled.no,  TreePathEnabled.yes);
alias DefaultVisitor   = DefaultVisitorImpl!(SizeEnabled.yes, TreePathEnabled.yes);

struct Void
{
	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void beforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void afterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
}

/// Default implementation of Visitor
struct DefaultVisitorImpl(
	SizeEnabled _size_,
	TreePathEnabled _tree_path_,
	Derived = Void
)
{
	alias sizeEnabled     = _size_;
	alias treePathEnabled = _tree_path_;

	static if (sizeEnabled == SizeEnabled.yes || treePathEnabled == TreePathEnabled.yes)
	{
		SizeType[2] size;

		this(SizeType[2] s) @safe @nogc nothrow
		{
			size = s;
		}
	}

	static if (treePathEnabled == TreePathEnabled.yes)
	{
		Location loc;
	}

	Orientation orientation = Orientation.Vertical;

	bool complete() @safe @nogc
	{
		static if (treePathEnabled == TreePathEnabled.yes)
			return loc.checkState;
		else
			return false;
	}

	bool engaged() @safe @nogc nothrow
	{
		static if (treePathEnabled == TreePathEnabled.yes)
			return loc.stateFirstOrRest;
		else
			return true;
	}

	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		static if (treePathEnabled == TreePathEnabled.yes)
		{
			loc.y.position = 0;

			final switch (this.orientation)
			{
				case Orientation.Vertical:
					loc.y.size = model.header_size;

				break;
				case Orientation.Horizontal:
					loc.y.size = size[this.orientation];
				break;
			}
		}
	}

	void doEnterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (sizeEnabled == SizeEnabled.yes)
		{
			model.size = size[orientation] + model.Spacing;
			static if (model.Collapsable)
				model.header_size = model.size;
		}

		version(none) static if (model.Collapsable)
		{
			const old_orientation = visitor.orientation;
			visitor.orientation  = this.orientation;

			scope(exit) visitor.orientation = old_orientation;
		}

		if (engaged)
		{
			static if (treePathEnabled == TreePathEnabled.yes)
			{
				static if (model.Collapsable)
					auto currentSize = model.header_size;
				else
					auto currentSize = model.size;
				loc.enterNode!order(currentSize);
				scope(exit) loc.enterNodeCheck!order;
			}
			() @trusted { (cast(Derived*) &this).enterNode!(order, Data, Model)(data, model); }();
		}
	}

	void doLeaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		if (engaged)
		{
			static if (treePathEnabled == TreePathEnabled.yes)
			{
				static if (model.Collapsable)
					auto currentSize = model.header_size;
				else
					auto currentSize = model.size;
				loc.leaveNode!order(currentSize);
				loc.leaveNodeCheck!order;
			}
			() @trusted { (cast(Derived*) &this).leaveNode!(order, Data, Model)(data, model); }();
		}
	}

	/// returns true if the current children shouldn't be processed
	/// but traversing should be continued
	bool doBeforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (sizeEnabled == SizeEnabled.yes) if (orientation == Orientation.Horizontal)
		{
			size[orientation] -= size[Orientation.Vertical] + model.Spacing;
		}
		() @trusted { (cast(Derived*) &this).beforeChildren!(order, Data, Model)(data, model); }();

		static if (order == Order.Bubbling && treePathEnabled == TreePathEnabled.yes)
		{
			// Edge case if the start path starts from this collapsable exactly
			// then the childs of the collapsable aren't processed
			if (loc.path.value.length && loc.current_path.value[] == loc.path.value[])
			{
				return true;
			}
		}
		return false;
	}

	void doAfterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		() @trusted { (cast(Derived*) &this).afterChildren!(order, Data, Model)(data, model); }();
		static if ((sizeEnabled == SizeEnabled.yes)) if (orientation == Orientation.Horizontal)
		{
			size[orientation] += size[Orientation.Vertical] + model.Spacing;
		}
	}
}

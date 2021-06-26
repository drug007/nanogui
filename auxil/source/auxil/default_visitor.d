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

	void beforeChildren() {}
	void afterChildren() {}
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
}

module auxil.default_visitor;

import std.typecons : Flag;

version(unittest) import unit_threaded : Name;

import auxil.common : Order;

alias SizeEnabled     = Flag!"SizeEnabled";
alias TreePathEnabled = Flag!"TreePathEnabled";

alias NullVisitor      = DefaultVisitorImpl!(SizeEnabled.no,  TreePathEnabled.no );
alias MeasuringVisitor = DefaultVisitorImpl!(SizeEnabled.yes, TreePathEnabled.no );
alias TreePathVisitor  = DefaultVisitorImpl!(SizeEnabled.no,  TreePathEnabled.yes);
alias DefaultVisitor   = DefaultVisitorImpl!(SizeEnabled.yes, TreePathEnabled.yes);

/// Default implementation of Visitor
struct DefaultVisitorImpl(
	SizeEnabled _size_,
	TreePathEnabled _tree_path_,
)
{
	alias sizeEnabled     = _size_;
	alias treePathEnabled = _tree_path_;

	alias SizeType = double;
	static if (sizeEnabled == SizeEnabled.yes)
	{
		SizeType sizeY;

		this(SizeType s) @safe @nogc nothrow
		{
			sizeY = s;
		}
	}

	static if (treePathEnabled == TreePathEnabled.yes)
	{
		import auxil.tree_path : TreePath;

		enum State { seeking, first, rest, finishing, }
		State state;
		TreePath tree_path, path;
		SizeType position, deferred_change, destination;
	}

	package void updatePositionSinking(Order order, Change)(Change change)
	{
		static if (order == Order.Sinking)
		{
			position += deferred_change;
			deferred_change = change;
		}
	}

	package void updatePositionBubbling(Order order, Change)(Change change)
	{
		static if (order == Order.Bubbling)
		{
			position += deferred_change;
			deferred_change = change;
		}
	}

	package void checkTraversalCompletionSinking(Order order)()
	{
		static if (order == Order.Sinking)
		{
			if (position+deferred_change > destination)
			{
				state = State.finishing;
				path = tree_path;
			}
		}
	}

	package void checkTraversalCompletionBubbling(Order order)()
	{
		static if (order == Order.Bubbling)
		{
			if (position <= destination)
			{
				state = State.finishing;
				path = tree_path;
			}
		}
	}

	void indent() {}
	void unindent() {}
	bool complete() @safe @nogc { return false; }
	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model) {}
	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model) {}

	// DerivedVisitor is "ansector" of this struct. Because the method is template one and can not be a virtual
	// so no polyphormism at all the actual type of "ansector" is passed directly
	// IOW when SomeVisitor calls doEnterNode inside this method typeof of this is always DefaultVisitorImpl so
	// the type of SomeVisitor should b passed directly to call the proper version of the EnterNode method
	bool doEnterNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled == TreePathEnabled.yes)
	{
		import std.algorithm : among;

		if (derivedVisitor.complete)
		{
			return true;
		}

		static if (sizeEnabled == SizeEnabled.yes) model.sizeYM = model.headerSizeY = sizeY + model.Spacing;

		final switch(state)
		{
			case State.seeking:
				if (tree_path.value == path.value)
					state = State.first;
			break;
			case State.first:
				state = State.rest;
			break;
			case State.rest:
				// do nothing
			break;
			case State.finishing:
			{
				return true;
			}
		}

		if (state.among(State.first, State.rest))
		{
			updatePositionSinking!order(model.headerSizeY);
			derivedVisitor.enterNode!(order, Data)(data, model);
			checkTraversalCompletionSinking!order();
		}

		return false;
	}

	bool doEnterNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled == TreePathEnabled.no)
	{
		if (derivedVisitor.complete)
		{
			return true;
		}

		static if (sizeEnabled == SizeEnabled.yes) model.sizeYM = model.headerSizeY = sizeY + model.Spacing;

		derivedVisitor.enterNode!(order, Data)(data, model);

		return false;
	}

	void doLeaveNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled == TreePathEnabled.yes)
	{
		import std.algorithm : among;

		if (state.among(State.first, State.rest))
		{
			updatePositionBubbling!order(-model.headerSizeY);
			checkTraversalCompletionBubbling!order();

			derivedVisitor.leaveNode!order(data, model);
		}
	}

	void doLeaveNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled == TreePathEnabled.no)
	{
		derivedVisitor.leaveNode!order(data, model);
	}
}

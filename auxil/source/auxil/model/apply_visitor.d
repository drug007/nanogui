module auxil.model.apply_visitor;

import auxil.model : Order, traversalForward;
import auxil.model.default_visitor : TreePathVisitor;

void applyByTreePath(T, Data, Model)(auto ref Data data, ref Model model, const(int)[] path, void delegate(ref const(T) value) dg)
{
	auto pv = ApplyVisitor!T();
	pv.path.value = path;
	pv.dg = dg;
	model.traversalForward(data, pv);
}

private struct ApplyVisitor(T)
{
	import std.typecons : Nullable;

	TreePathVisitor default_visitor;
	alias default_visitor this;

	void delegate(ref const(T) value) dg;
	bool completed;

	bool complete()
	{
		return completed;
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (is(Data == T))
		{
			completed = tree_path.value[] == path.value[];
			if (completed)
			{
				dg(data);
				return;
			}
		}

		processLeaf!order(data, model);
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (is(Data == T))
		{
			assert(!completed);
			completed = tree_path.value[] == path.value[];
			if (completed)
				dg(data);
		}
	}
}

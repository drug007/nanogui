module auxil.model.property_visitor;

import auxil.model : TreePathVisitor, Order, traversalForward;

private enum PropertyKind { setter, getter }

auto setPropertyByTreePath(string propertyName, Value, Data, Model)(auto ref Data data, ref Model model, int[] path, Value value)
{
	auto pv = PropertyVisitor!(propertyName, Value)();
	pv.path.value = path;
	pv.value = value;
	pv.propertyKind = PropertyKind.setter;
	model.traversalForward(data, pv);
}

auto getPropertyByTreePath(string propertyName, Value, Data, Model)(auto ref Data data, ref Model model, int[] path)
{
	auto pv = PropertyVisitor!(propertyName, Value)();
	pv.path.value = path;
	pv.propertyKind = PropertyKind.getter;
	model.traversalForward(data, pv);
	return pv.value;
}

private struct PropertyVisitor(string propertyName, Value)
{
	import std.typecons : Nullable;

	TreePathVisitor default_visitor;
	alias default_visitor this;

	PropertyKind propertyKind;
	Nullable!Value value;
	bool completed;

	this(Value value)
	{
		this.value = value;
	}

	bool complete()
	{
		return completed;
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (is(typeof(mixin("model." ~ propertyName))))
		{
			if (propertyKind == PropertyKind.getter)
				value = mixin("model." ~ propertyName);
			else if (propertyKind == PropertyKind.setter)
				mixin("model." ~ propertyName) = value.get;
		}
		else
			value.nullify;

		processLeaf!order(data, model);
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		assert(!completed);
		completed = tree_path.value[] == path.value[];
	}
}

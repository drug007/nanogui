module tests.test_description;

import dyaml;

enum Order { forward, reverse, runtime }

int main()
{
	testOrder;
	testNestedStruct;
	return 0;
}

auto getOrder(const(Node) node, Order default_) @safe
{
	try
	{
		import std.conv : to;
		return node["order"].as!string.to!Order;
	}
	catch(YAMLException e)
	{
		return default_;
	}
}

auto testOrder()
{
	const desc = [
		"order: forward",
		"order: reverse",
		"order: runtime",
	];

	auto root = Loader.fromString(desc[0]).load();
	assert(root.getOrder(Order.runtime) == Order.forward);

	root = Loader.fromString(desc[1]).load();
	assert(root.getOrder(Order.runtime) == Order.reverse);

	root = Loader.fromString(desc[2]).load();
	assert(root.getOrder(Order.forward) == Order.runtime);
}

auto testNestedStruct()
{
	const desc = "
foo:
    order: reverse
    ps:
        bar:
            order: runtime
";

	auto root = Loader.fromString(desc).load();

	auto current = root["foo"].getOrder(Order.forward);
	assert(current == Order.reverse);

	current = root["foo"]["ps"].getOrder(current);
	assert(current == Order.reverse);

	current = root["foo"]["ps"]["bar"].getOrder(current);
	assert(current == Order.runtime);
}
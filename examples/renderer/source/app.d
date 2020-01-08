module app;

import std.typecons : Flag, Yes, No;
import renderer : render;

void itemInColumn(Flag!"runTest" runTest = Yes.runTest)
{
	import std.stdio;
	import std.array : front;
	import common : makeDom, DomNode, printDom;

	static struct Data
	{
		string item0 = "item0", item1 = "item1", item2 = "item2", item3 = "item3";
	}

	Data data;

	auto root = new DomNode(false, null);
	{
		import common : Direction;

		root.name = "root";
		root.attributes.direction = Direction.column;
		auto root_item0 = new DomNode(false, null);
		{
			root.child ~= root_item0; 
			root_item0.name = "root.item0";
		}
		auto root_item1 = new DomNode(false, null);
		{
			root.child ~= root_item1; 
			root_item1.name = "root.item1";
		}
		auto root_item2 = new DomNode(false, null);
		{
			root.child ~= root_item2; 
			root_item2.name = "root.item2";
		}
		auto root_item3 = new DomNode(false, null);
		{
			root.child ~= root_item3; 
			root_item3.name = "root.item3";
		}
	}

	writeln;

	import walker : Walker;
	import common : Direction, Alignment, Justification;
	Walker walker;
	with (walker)
	{
		with(area)
		{
			x = y = 0;
			w = 640;
			h = 480;
			margin = 10;
			padding = 10;
		}
		direction = Direction.column;
		alignment = Alignment.stretch;
		justification = Justification.around;
		wrapping = false;
	}
	walker.render(data, root);
	writeln;

	walker.renderlog.render("itemInColumn");

	if (!runTest)
		return;

	import std.array : popFront;
	import common;

	auto log = walker.renderlog;

	assert(log.front.name == "root");
	assert(log.front.area == WorkArea(0, 0, 640, 480, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item0");
	assert(log.front.area == WorkArea(10, 10, 620, 115, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item1");
	assert(log.front.area == WorkArea(10, 125, 620, 115, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item2");
	assert(log.front.area == WorkArea(10, 240, 620, 115, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item3");
	assert(log.front.area == WorkArea(10, 355, 620, 115, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;
}

void itemInRow(Flag!"runTest" runTest = Yes.runTest)
{
	import std.stdio;
	import std.array : front;
	import common : makeDom, DomNode, printDom;

	static struct Data
	{
		string item0 = "item0", item1 = "item1", item2 = "item2", item3 = "item3";
	}

	Data data;

	auto root = new DomNode(false, null);
	{
		import common : Direction;

		root.name = "root";
		root.attributes.direction = Direction.row;
		root.attributes.margin = 20;
		root.attributes.padding = 30;
		auto root_item0 = new DomNode(false, null);
		{
			root.child ~= root_item0; 
			root_item0.name = "root.item0";
		}
		auto root_item1 = new DomNode(false, null);
		{
			root.child ~= root_item1; 
			root_item1.name = "root.item1";
		}
		auto root_item2 = new DomNode(false, null);
		{
			root.child ~= root_item2; 
			root_item2.name = "root.item2";
		}
		auto root_item3 = new DomNode(false, null);
		{
			root.child ~= root_item3; 
			root_item3.name = "root.item3";
		}
	}

	writeln;

	import walker : Walker;
	import common : Direction, Alignment, Justification;
	Walker walker;
	with (walker)
	{
		with(area)
		{
			x = y = 0;
			w = 640;
			h = 480;
			margin = 10;
		}
		direction = Direction.row;
		alignment = Alignment.stretch;
		justification = Justification.around;
		wrapping = false;
	}
	walker.render(data, root);
	writeln;

	walker.renderlog.render("itemInRow");

	if (!runTest)
		return;

	import std.array : popFront;
	import common;

	auto log = walker.renderlog;

	assert(log.front.name == "root");
	assert(log.front.area == WorkArea(0, 0, 640, 480, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item0");
	assert(log.front.area == WorkArea(10, 10, 155, 460, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item1");
	assert(log.front.area == WorkArea(165, 10, 155, 460, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item2");
	assert(log.front.area == WorkArea(320, 10, 155, 460, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.item3");
	assert(log.front.area == WorkArea(475, 10, 155, 460, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;
}

void complexCase(Flag!"runTest" runTest = Yes.runTest)
{
	import std.stdio;
	import std.array : front;
	import common : makeDom, DomNode, printDom;

	static struct Data
	{
		struct Child0
		{

		}

		Child0 child0;

		struct Child1
		{
			struct Panel0
			{
				struct Image
				{

				}

				Image image;

				struct Text
				{

				}

				Text text;
			}

			Panel0 panel0;

			struct Panel1
			{
				struct Text
				{

				}

				Text text;

				struct Panel
				{
					struct Ok
					{

					}

					Ok ok;

					struct Cancel
					{

					}

					Cancel cancel;
				}

				Panel panel;
			}

			Panel1 panel1;
		}

		Child1 child1;
	}

	Data data2;

	auto root = new DomNode(false, null);
	{
		import common : Direction;

		root.name = "root";
		root.attributes.direction = Direction.column;
		root.attributes.margin = 10;
		root.attributes.padding = 10;
		auto root_child0 = new DomNode(false, null);
		{
			root.child ~= root_child0; 
			root_child0.name = "root.child0";
		}
		auto root_child1 = new DomNode(false, null);
		{
			root.child ~= root_child1;
			root_child1.name = "root.child1";
			root_child1.attributes.direction = Direction.row;

			auto root_child1_panel0 = new DomNode(false, null);
			{
				root_child1.child ~= root_child1_panel0;
				root_child1_panel0.name = "root.child1.panel0";
				root_child1_panel0.attributes.direction = Direction.column;
				root_child1_panel0.attributes.margin = 20;

				auto image = new DomNode(false, null);
				{
					root_child1_panel0.child ~= image;
					image.name = "root.child1.panel0.image";
				}
				auto text = new DomNode(false, null);
				{
					root_child1_panel0.child ~= text;
					text.name = "root.child1.panel0.text";
				}
			}
			auto root_child1_panel1 = new DomNode(false, null);
			{
				root_child1.child ~= root_child1_panel1;
				root_child1_panel1.name = "root.child1.panel1";
				root_child1_panel1.attributes.direction = Direction.column;

				auto text = new DomNode(false, null);
				{
					root_child1_panel1.child ~= text;
					text.name = "root.child1.panel1.text";
				}

				auto panel = new DomNode(false, null);
				{
					root_child1_panel1.child ~= panel;
					panel.name = "root.child1.panel1.panel";
					panel.attributes.direction = Direction.row;

					auto ok = new DomNode(false, null);
					{
						panel.child ~= ok;
						ok.name = "root.child1.panel1.panel.ok";
					}

					auto cancel = new DomNode(false, null);
					{
						panel.child ~= cancel;
						cancel.name = "root.child1.panel1.panel.cancel";
					}
				}
			}
		}
	}

	writeln;

	import walker : Walker;
	import common : Direction, Alignment, Justification;
	Walker walker;
	with (walker)
	{
		with(area)
		{
			x = y = 0;
			w = 640;
			h = 480;
		}
		direction = Direction.column;
		alignment = Alignment.stretch;
		justification = Justification.around;
		wrapping = false;
	}
	walker.render(data2, root);
	writeln;

	walker.renderlog.render("complexCase");

	if (!runTest)
		return;

	import std.array : popFront;
	import common;

	auto log = walker.renderlog;
	assert(log.front.name == "root");
	assert(log.front.area == WorkArea(0, 0, 640, 480, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child0");
	assert(log.front.area == WorkArea(10, 10, 620, 230, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1");
	assert(log.front.area == WorkArea(10, 240, 620, 230, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel0");
	assert(log.front.area == WorkArea(20, 250, 300, 210, 20));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel0.image");
	assert(log.front.area == WorkArea(40, 270, 260, 85, 20));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel0.text");
	assert(log.front.area == WorkArea(40, 355, 260, 85, 20));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel1");
	assert(log.front.area == WorkArea(320, 250, 300, 210, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel1.text");
	assert(log.front.area == WorkArea(330, 260, 280, 95, 10));
	assert(log.front.direction == Direction.column);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel1.panel");
	assert(log.front.area == WorkArea(330, 355, 280, 95, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel1.panel.ok");
	assert(log.front.area == WorkArea(340, 365, 130, 75, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;

	assert(log.front.name == "root.child1.panel1.panel.cancel");
	assert(log.front.area == WorkArea(470, 365, 130, 75, 10));
	assert(log.front.direction == Direction.row);
	log.popFront;
	log.popFront;
}

void main()
{
	itemInRow(No.runTest);
	itemInColumn(No.runTest);
	complexCase(No.runTest);
}
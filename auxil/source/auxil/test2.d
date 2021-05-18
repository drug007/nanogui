module auxil.test2;

version(unittest)
import unit_threaded : should, be, Name;
import taggedalgebraic : TaggedAlgebraic;

import auxil.model;
import auxil.test;

struct Test
{
	ushort us;
	long l;
}

struct Test2
{
	size_t st;
	string s;
	Test t;
	float[] fa;
}

union Payload
{
	int i;
	float f;
	double d;
	string str;
	Test t;
	Test2 t2;
}

alias Data = TaggedAlgebraic!Payload;

Data[] data;
RelativeMeasurer v;
typeof(makeModel(data)) model;

void setup()
{
	data = [
		Data(1),
		Data(2.0),
		Data(3.0f),
		Data(Test(100, -1001)),
		Data(Test2(1_000_000, "test2", Test(200, -11), [11, 12, 123])),
		Data("text"),
	];

	v = RelativeMeasurer();
	model = makeModel(data);
	model.collapsed = false;
	setPropertyByTreePath!"collapsed"(data, model, [3], false);
	setPropertyByTreePath!"collapsed"(data, model, [4], false);
	setPropertyByTreePath!"collapsed"(data, model, [4, 2], false);
	setPropertyByTreePath!"collapsed"(data, model, [4, 3], false);

	// measure size
	{
		auto mv = MeasuringVisitor(9);
		model.visitForward(data, mv);
	}
}

version(unittest)
@Name("Test1")
unittest
{
	setup;

	v.position = 0;
	model.visitForward(data, v);
	model.size.should.be == 180;
	v.output.should.be == [
		TreePosition([ ],         0),
		TreePosition([0],        10),
		TreePosition([1],        20),
		TreePosition([2],        30),
		TreePosition([3],        40),
		TreePosition([3, 0],     50),
		TreePosition([3, 1],     60),
		TreePosition([4],        70),
		TreePosition([4, 0],     80),
		TreePosition([4, 1],     90),
		TreePosition([4, 2],    100),
		TreePosition([4, 2, 0], 110),
		TreePosition([4, 2, 1], 120),
		TreePosition([4, 3],    130),
		TreePosition([4, 3, 0], 140),
		TreePosition([4, 3, 1], 150),
		TreePosition([4, 3, 2], 160),
		TreePosition([5],       170),
	];
	v.position.should.be == 170;

	v.position = 0;
	v.path.value = [4,2,1];
	model.visitForward(data, v);
	v.output.should.be == [
		TreePosition([4, 2, 1],  0),
		TreePosition([4, 3],    10),
		TreePosition([4, 3, 0], 20),
		TreePosition([4, 3, 1], 30),
		TreePosition([4, 3, 2], 40),
		TreePosition([5],       50)
	];
}

version(unittest)
@Name("Test2")
unittest
{
	setup;

	// default
	{
		v.path.clear;
		v.position = 0;
		v.destination = v.destination.nan;
		model.visitForward(data, v);

		v.position.should.be == 170;
		v.path.value[].should.be == (int[]).init;
	}

	// next position is between two elements
	{
		v.path.clear;
		v.position = 0;
		v.destination = 15;
		model.visitForward(data, v);

		v.position.should.be == 10;
		v.destination.should.be == 15;
		v.path.value[].should.be == [0];
	}

	// next position is equal to start of an element
	{
		v.path.clear;
		v.position = 0;
		v.destination = 30;
		model.visitForward(data, v);

		v.position.should.be == 30;
		v.destination.should.be == 30;
		v.path.value[].should.be == [2];
	}

	// start path is not null
	{
		v.path.value = [3, 0];
		v.position = 0;
		v.destination = 55;
		model.visitForward(data, v);

		v.position.should.be == 50;
		v.destination.should.be == 55;
		v.path.value[].should.be == [4, 2];
	}

	// reverse order, start path is not null
	{
		v.path.value = [4, 1];
		v.position = 90;
		v.destination = 41;

		model.visitBackward(data, v);

		v.position.should.be == 40;
		v.destination.should.be == 41;
		v.path.value[].should.be == [3];

		// bubble to the next element
		v.destination = 19;

		model.visitBackward(data, v);

		v.path.value[].should.be == [0];
		v.position.should.be == 10;
		v.destination.should.be == 19;
		v.output.should.be == [
			TreePosition([3], 40),
			TreePosition([2], 30),
			TreePosition([1], 20),
			TreePosition([0], 10),
		];
	}
}

version(unittest)
@Name("ScrollingTest")
unittest
{
	setup;

	v.path.clear;
	v.position = 0;

	// the element height is 10 px

	// scroll 7 px forward
	visit(model, data, v, 7);
	// current element is the root one
	v.path.value[].should.be == (int[]).init;
	// position of the current element is 0 px
	v.position.should.be == 0;
	// the window starts from 7th px
	v.destination.should.be == 7;

	// scroll the next 7th px forward
	visit(model, data, v, 14);
	// the current element is the first child element
	v.path.value[].should.be == [0];
	// position of the current element is 10 px
	v.position.should.be == 10;
	// the window starts from 14th px
	v.destination.should.be == 14;

	// scroll the next 7th px forward
	visit(model, data, v, 21);
	// the current element is the second child element
	v.path.value[].should.be == [1];
	// position of the current element is 20 px
	v.position.should.be == 20;
	// the window starts from 21th px
	v.destination.should.be == 21;

	// scroll the next 7th px forward
	visit(model, data, v, 28);
	// the current element is the second child element
	v.path.value[].should.be == [1];
	// position of the current element is 20 px
	v.position.should.be == 20;
	// the window starts from 28th px
	v.destination.should.be == 28;

	// scroll the next 7th px forward
	visit(model, data, v, 35);
	// the current element is the third child element
	v.path.value[].should.be == [2];
	// position of the current element is 30 px
	v.position.should.be == 30;
	// the window starts from 35th px
	v.destination.should.be == 35;

	// scroll 7th px backward
	visit(model, data, v, 27);
	// the current element is the second child element
	v.path.value[].should.be == [1];
	// position of the current element is 20 px
	v.position.should.be == 20;
	// the window starts from 27th px
	v.destination.should.be == 27;

	// scroll the next 9th px backward
	visit(model, data, v, 18);
	// the current element is the first child element
	v.path.value[].should.be == [0];
	// position of the current element is 10 px
	v.position.should.be == 10;
	// the window starts from 18th px
	v.destination.should.be == 18;

	// scroll the next 6th px backward
	visit(model, data, v, 12);
	// the current element is the first child element
	v.path.value[].should.be == [0];
	// position of the current element is 10 px
	v.position.should.be == 10;
	// the window starts from 12th px
	v.destination.should.be == 12;

	// scroll the next 5th px backward
	visit(model, data, v, 7);
	// the current element is the root element
	v.path.value[].should.be == (int[]).init;
	// position of the current element is 0 px
	v.position.should.be == 0;
	// the window starts from 7th px
	v.destination.should.be == 7;

	// scroll 76 px forward
	visit(model, data, v, 83);
	// // the current element is the second child element
	// v.path.value[].should.be == [4, 0];
	// // position of the current element is 20 px
	// v.position.should.be == 80;
	// the window starts from 27th px
	v.destination.should.be == 83;

	visit(model, data, v, 81);
	v.path.value[].should.be == [4, 0];
	v.position.should.be == 80;
	v.destination.should.be == 81;

	visit(model, data, v, 80);
	v.path.value[].should.be == [4, 0];
	v.position.should.be == 80;
	v.destination.should.be == 80;

	visit(model, data, v, 79.1);
	v.path.value[].should.be == [4];
	v.position.should.be == 70;
	v.destination.should.be ~ 79.1;

	visit(model, data, v, 133.4);
	v.path.value[].should.be == [4, 3];
	v.position.should.be == 130;
	v.destination.should.be ~ 133.4;

	visit(model, data, v, 0);
	v.path.value[].should.be == (int[]).init;
	v.position.should.be == 0;
	v.destination.should.be ~ 0.0;
}
module aux.test;

version(unittest) import unit_threaded : Name;

import aux.model;

@safe private
struct PrettyPrintingVisitor
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem.vector : Vector;

	Vector!(char, Mallocator) output;
	private Vector!(char, Mallocator) _indentation;
	TreePathVisitor tree_path_visitor;
	alias tree_path_visitor this;

	MeasureVisitor measure_visitor;

	this(float width, float height) @nogc
	{
		measure_visitor = MeasureVisitor(width, height, Orientation.Vertical);
		measure_visitor.orientation = Orientation.Vertical;
		tree_path_visitor.size = [width, height];
	}

	auto processItem(T...)(T msg)
	{
		() @trusted {
			output ~= _indentation[];
			import nogc.conv : text;
			output ~= text(msg, "\n")[];
		} ();
	}

	void indent() @nogc @trusted
	{
		_indentation ~= '\t';
	}

	void unindent() @nogc @trusted
	{
		if (_indentation.length)
			_indentation.popBack;
	}

	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		position[] = 0;
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		measure_visitor.enterNode!order(data, model);

		import std.conv : to;
		import aux.traits : hasRenderHeader;

		static if (hasRenderHeader!data)
		{
			import aux.model : FixedAppender;
			FixedAppender!512 app;
			data.renderHeader(app);
			() @trusted { processItem(app[]); } ();
		}
		else
			processItem("Caption: ", Data.stringof);
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		measure_visitor.leaveNode!order(data, model);
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		measure_visitor.processLeaf!order(data, model);

		processItem(data);
	}

	auto currentSize()
	{
		return measure_visitor.size[measure_visitor.orientation];
	}
}

version(unittest) @Name("aggregates_trivial")
@safe
unittest
{
	static struct Test
	{
		float f = 7.7;
		int i = 8;
		string s = "some text";
	}

	static struct StructWithStruct
	{
		double d = 8.8;
		long l = 999;
		Test t;
	}

	static class TestClass
	{

	}

	static struct StructWithPointerAndClass
	{
		double* d;
		TestClass tc;
	}

	static struct StructWithNestedClass
	{
		TestClass tc;
	}

	auto visitor = PrettyPrintingVisitor(120, 9);
	auto d = StructWithStruct();
	auto m = makeModel(d);
	m.visitForward(d, visitor);
	assert(m.size == 10);
	d.d = 0;
	d.l = 1;
	d.t.f = 2;
	d.t.i = 3;
	d.t.s = "s";
	m.visitForward(d, visitor);
	m.collapsed = false;
	m.visitForward(d, visitor);
	m.t.collapsed = false;
	m.visitForward(d, visitor);
}

version(unittest) @Name("static_array")
//@nogc
unittest
{
	version(Windows) {}
	else {
		import core.stdc.locale;
		setlocale(LC_NUMERIC, "C");
	}
	float[3] d = [1.1f, 2.2f, 3.3f];
	auto m = Model!d();

	auto visitor = PrettyPrintingVisitor(120, 9);
	visitor.position = 0;
	visitor.processItem;
	m.collapsed = false;
	m.visitForward(d, visitor);

	visitor.output ~= '\0';
	version(none)
	{
		import core.stdc.stdio : printf;
		printf("%s\nlength: %ld\n", visitor.output[].ptr, visitor.output.length);
	}

	import std.algorithm : equal;
	assert(visitor.output[].equal("
Caption: float[3]
	1.100000
	2.200000
	3.300000
\0"
	));
}

version(unittest) @Name("dynamic_array")
unittest
{
	float[] d = [1.1f, 2.2f, 3.3f];
	auto m = Model!d();

	auto visitor = PrettyPrintingVisitor(120, 9);
	visitor.processItem;
	m.collapsed = false;
	m.model.length = d.length;
	m.visitForward(d, visitor);

	d ~= [4.4f, 5.5f];
	m.model.length = d.length;
	m.visitForward(d, visitor);

	d = d[2..3];
	m.model.length = d.length;
	m.visitForward(d, visitor);

	visitor.output ~= '\0';
	version(none)
	{
		import core.stdc.stdio : printf;
		printf("%s\nlength: %ld\n", visitor.output[].ptr, visitor.output.length);
	}

	import std.algorithm : equal;
	assert(visitor.output[].equal("
Caption: float[]
	1.100000
	2.200000
	3.300000
Caption: float[]
	1.100000
	2.200000
	3.300000
	4.400000
	5.500000
Caption: float[]
	3.300000
\0"
	));
}

version(unittest) @Name("aggregate_with_only_member")
// @nogc
unittest
{
	static struct OneMember
	{
		string one = "one";
	}

	auto d = OneMember();
	auto m = Model!d();
	import std.traits : FieldNameTuple;
	import std.meta : AliasSeq;
	static assert(FieldNameTuple!(typeof(m)) == AliasSeq!("single_member_model"));

	auto visitor = PrettyPrintingVisitor(120, 9);
	visitor.processItem;
	m.visitForward(d, visitor);

	visitor.output ~= '\0';

	version(none)
	{
		import core.stdc.stdio : printf;
		printf("---\n%s\n---\nlength: %ld\n",
			visitor.output[].ptr, visitor.output.length);
	}

	import std.algorithm : equal;
	assert(visitor.output[].equal("
one
\0"
	));
}

version(unittest) @Name("aggregate_with_render_header")
unittest
{
	static struct Aggregate
	{
		float f;
		long l;

		void renderHeader(W)(ref W writer) @trusted const
		{
			import core.stdc.stdio : snprintf;

			char[128] buffer;
			const l = snprintf(&buffer[0], buffer.length, "Custom header %f, %ld", f, l);
			writer.put(buffer[0..l]);
		}
	}

	import aux.traits : hasRenderHeader;
	static assert(hasRenderHeader!Aggregate);

	auto d = Aggregate();

	static assert(hasRenderHeader!d);
	auto m = Model!d();
	m.collapsed = false;

	auto visitor = PrettyPrintingVisitor(120, 9);
	visitor.processItem;
	m.visitForward(d, visitor);

	visitor.output ~= '\0';

	version(none)
	{
		import core.stdc.stdio : printf;
		printf("---\n%s\n---\nlength: %ld\n",
			visitor.output[].ptr, visitor.output.length);
	}

	import std.algorithm : equal;
	assert(visitor.output[].equal("
Custom header nan, 0
	nan
	0
\0"
	));
}

version(unittest)
{
	import aux.traits : renderedAs, renderedAsMember;

	private struct Proxy
	{
		float f;

		this(ref const(Test3) t3)
		{
			f = t3.f;
		}
	}

	@renderedAs!Proxy
	private struct Test3
	{
		int i;
		float f;
	}

	@renderedAs!int
	private struct Test4
	{
		int i;
		float f;

		int opCast(T : int)() const
		{
			return i;
		}
	}

	@renderedAsMember!"t4.i"
	private struct Test5
	{
		Test4 t4;
		float f;
	}
}

version(unittest) @Name("aggregate_proxy")
unittest
{
	import aux.traits :hasRenderedAs;
	{
		auto test3 = Test3(123, 123.0f);

		auto d = Proxy(test3);
		auto m = makeModel(d);

		static assert( hasRenderedAs!Test3);
		static assert(!hasRenderedAs!test3);
		import std.traits : FieldNameTuple;
		import std.meta : AliasSeq;
		static assert(FieldNameTuple!(typeof(m)) == AliasSeq!("single_member_model"));

		auto visitor = PrettyPrintingVisitor(120, 9);
		visitor.processItem;
		m.visitForward(d, visitor);

		visitor.output ~= '\0';

		version(none)
		{
			import core.stdc.stdio : printf;
			printf("---\n%s\n---\nlength: %ld\n",
				visitor.output[].ptr, visitor.output.length);
		}

		import std.algorithm : equal;
		assert(visitor.output[].equal("
123.000000
\0"
		));
	}

	{
		auto d = Test3();
		auto m = makeModel(d);
		static assert(!m.Collapsable);

		auto visitor = PrettyPrintingVisitor(120, 9);
		visitor.processItem;
		m.visitForward(d, visitor);

		visitor.output ~= '\0';

		version(none)
		{
			import core.stdc.stdio : printf;
			printf("---\n%s\n---\nlength: %ld\n",
				visitor.output[].ptr, visitor.output.length);
		}

		import std.algorithm : equal;
		assert(visitor.output[].equal("
nan
\0"
		));
	}

	{
		Test4 test4;
		test4.i = 112;
		auto m = makeModel(test4);

		static assert(is(m.Proxy));
		static assert(is(typeof(m.proxy) == int));
		assert(m.proxy == 112);
	}

	{
		auto d = Test5(Test4(11, 22.2));
		auto m = makeModel(d);
		static assert(!m.Collapsable);

		auto visitor = PrettyPrintingVisitor(120, 9);
		visitor.processItem;
		m.visitForward(d, visitor);

		visitor.output ~= '\0';

		version(none)
		{
			import core.stdc.stdio : printf;
			printf("---\n%s\n---\nlength: %ld\n",
				visitor.output[].ptr, visitor.output.length);
		}

		import std.algorithm : equal;
		assert(visitor.output[].equal("
11
\0"
		));
	}

	{
		@("wrongAttribute")
		@("renderedAsMember.f", "123")
		@("123")
		static struct Test
		{
			int i;
			float f;
		}
		auto d = Test(11, 1.0);
		auto m = makeModel(d);
		static assert(!m.Collapsable);

		auto visitor = PrettyPrintingVisitor(120, 9);
		visitor.processItem;
		m.visitForward(d, visitor);

		visitor.output ~= '\0';

		version(none)
		{
			import core.stdc.stdio : printf;
			printf("---\n%s\n---\nlength: %ld\n",
				visitor.output[].ptr, visitor.output.length);
		}

		import std.algorithm : equal;
		assert(visitor.output[].equal("
1.000000
\0"
		));
	}
}

version(unittest) @Name("TaggedAlgebraic")
unittest
{
	import taggedalgebraic : TaggedAlgebraic, Void, get;
	import unit_threaded : should, be;

	static struct Struct
	{
		double d;
		char c;
	}

	struct Payload
	{
		Void v;
		float f;
		int i;
		string sg;
		Struct st;
		string[] sa;
		double[] da;
	}

	alias Data = TaggedAlgebraic!Payload;

	Data[] data = [
		Data(1.2f),
		Data(4),
		Data("string"),
		Data(Struct(100, 'd')),
		Data(["str0", "str1", "str2"]),
		Data([0.1, 0.2, 0.3]),
	];

	auto model = makeModel(data);
	assert(model.length == data.length);
	assert(model[4].get!(Model!(string[])).length == data[4].length);

	// default value
	model.collapsed.should.be == true;

	// change it directly
	model.collapsed = false;
	model.collapsed.should.be == false;

	// change the value of the root by tree path
	setPropertyByTreePath!"collapsed"(data, model, [], true);
	model.collapsed.should.be == true;
	{
		const r = getPropertyByTreePath!("collapsed", bool)(data, model, []);
		r.isNull.should.be == false;
		r.get.should.be == true;
	}

	// change the root once again
	setPropertyByTreePath!"collapsed"(data, model, [], false);
	model.collapsed.should.be == false;

	// the value of the child by tree path
	setPropertyByTreePath!"collapsed"(data, model, [3], false);
	model.model[3].collapsed.should.be == false;

	foreach(ref e; model.model)
		e.collapsed = false;

	auto visitor = PrettyPrintingVisitor(120, 9);
	visitor.processItem;
	model.visitForward(data, visitor);

	data[4] ~= "recently added 4th element";
	model[4].update(data[4]);
	model.visitForward(data, visitor);

	data[4] = data[4].get!(string[])[3..$];
	data[4].get!(string[])[0] = "former 4th element, now the only one";
	model[4].update(data[4]);
	model.visitForward(data, visitor);

	visitor.output ~= '\0';
	version(none)
	{
		import core.stdc.stdio : printf;
		printf("%s\nlength: %ld\n", visitor.output[].ptr, visitor.output.length);
	}

	import std.algorithm : equal;
	assert(visitor.output[].should.be == "
Caption: TaggedAlgebraic!(Payload)[]
	1.200000
	4
	string
	Caption: Struct
		100.000000
		d
	Caption: string[]
		str0
		str1
		str2
	Caption: double[]
		0.100000
		0.200000
		0.300000
Caption: TaggedAlgebraic!(Payload)[]
	1.200000
	4
	string
	Caption: Struct
		100.000000
		d
	Caption: string[]
		str0
		str1
		str2
		recently added 4th element
	Caption: double[]
		0.100000
		0.200000
		0.300000
Caption: TaggedAlgebraic!(Payload)[]
	1.200000
	4
	string
	Caption: Struct
		100.000000
		d
	Caption: string[]
		former 4th element, now the only one
	Caption: double[]
		0.100000
		0.200000
		0.300000
\0"
	);
}

version(unittest) @Name("nogc_dynamic_array")
//@nogc
unittest
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem.vector : Vector;
	Vector!(float, Mallocator) data;
	data ~= 0.1f;
	data ~= 0.2f;
	data ~= 0.3f;

	auto model = makeModel(data[]);

	auto visitor = PrettyPrintingVisitor(120, 14);
	visitor.processItem;
	model.visitForward(data[], visitor);
	assert(model.size == visitor.currentSize + model.Spacing);

	model.collapsed = false;
	model.visitForward(data[], visitor);

	assert(model.size == 4*(visitor.currentSize + model.Spacing));
	foreach(e; model.model)
		assert(e.size == (visitor.currentSize + model.Spacing));

	visitor.output ~= '\0';
	version(none)
	{
		import core.stdc.stdio : printf;
		printf("%s\nlength: %ld\n", visitor.output[].ptr, visitor.output.length);
	}

	import std.algorithm : equal;
	assert(visitor.output[].equal("
Caption: float[]
Caption: float[]
	0.100000
	0.200000
	0.300000
\0"
	));
}

version(unittest) @Name("size_measuring")
unittest
{
	import taggedalgebraic : TaggedAlgebraic, Void, get;
	import unit_threaded : should, be;

	static struct Struct
	{
		double d;
		char c;
	}

	struct Payload
	{
		Void v;
		float f;
		int i;
		string sg;
		Struct st;
		string[] sa;
		double[] da;
	}

	alias Data = TaggedAlgebraic!Payload;

	Data[] data = [
		Data(1.2f),
		Data(4),
		Data("string"),
		Data(Struct(100, 'd')),
		Data(["str0", "str1", "str2"]),
		Data([0.1, 0.2, 0.3]),
	];

	auto model = makeModel(data);
	assert(model.length == data.length);
	assert(model[4].get!(Model!(string[])).length == data[4].length);

	model.size.should.be == 0;
	auto visitor = PrettyPrintingVisitor(120, 17);
	visitor.orientation = Orientation.Vertical;
	model.visitForward(data, visitor);

	model.collapsed.should.be == true;
	model.size.should.be ~ (visitor.currentSize + model.Spacing);
	model.size.should.be ~ 18.0;
	visitor.pos.should.be ~ 0.0;

	setPropertyByTreePath!"collapsed"(data, model, [], false);
	model.visitForward(data, visitor);
	model.visitForward(data, visitor);
	model.size.should.be ~ (visitor.currentSize + model.Spacing)*7;
	model.size.should.be ~ 18.0*7;
	visitor.pos.should.be ~ 6*18.0;

	setPropertyByTreePath!"collapsed"(data, model, [3], false);
	model.visitForward(data, visitor);
	model.visitForward(data, visitor);
	model.size.should.be ~ (visitor.currentSize + model.Spacing)*9;
	model.size.should.be ~ 18.0*9;
	visitor.pos.should.be ~ (6+2)*18.0;

	setPropertyByTreePath!"collapsed"(data, model, [4], false);
	model.visitForward(data, visitor);
	model.visitForward(data, visitor);
	model.size.should.be ~ (visitor.currentSize + model.Spacing)*12;
	model.size.should.be ~ 18.0*12;
	visitor.pos.should.be ~ (6+2+3)*18.0;

	setPropertyByTreePath!"collapsed"(data, model, [5], false);
	model.visitForward(data, visitor);
	model.visitForward(data, visitor);
	model.size.should.be ~ (visitor.currentSize + model.Spacing)*15;
	model.size.should.be ~ 18.0*15;
	visitor.pos.should.be ~ (6+2+3+3)*18.0;

	visitor.destination[] = visitor.destination[0].nan;
	model.visitForward(data, visitor);
	model.size.should.be == 270;
	visitor.pos.should.be == 252;

	visitor.position = 0;
	visitor.destination = 100;
	model.visitForward(data, visitor);
	model.size.should.be == 270;
	visitor.pos.should.be == 90;

	// check for recalculating the model size after node collapsing
	setPropertyByTreePath!"collapsed"(data, model, [5], true);
	// clear visitor to calculate the size of the whole model
	visitor.clear;
	model.visitForward(data, visitor);
	model.visitForward(data, visitor);
	model.size.should.be ~ (visitor.currentSize + model.Spacing)*12;
	model.size.should.be ~ 18.0*12;
	visitor.pos.should.be ~ (6+2+3)*18.0;
}

private
struct RendererVisitor
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem.vector : Vector;

	Vector!(char, Mallocator) output;
	Vector!(TreePosition, Mallocator)  output_position;
	private Vector!(char, Mallocator) _indentation;
	TreePathVisitor tree_path_visitor;
	alias tree_path_visitor this;

	float[2] size;
	Orientation orientation, old_orientation;

	this(float width, float height) @nogc
	{
		size[0] = width;
		size[1] = height;
		orientation = Orientation.Vertical;
	}

	auto processItem(T...)(T msg)
	{
		() @trusted {
			output ~= _indentation[];
			char delimiter;
			final switch(orientation)
			{
				case Orientation.Vertical:   delimiter = '\n'; break;
				case Orientation.Horizontal: delimiter = '>'; break;
			}
			import nogc.conv : text;
			output ~= text(msg, delimiter)[];
		} ();
	}

	void indent() @nogc @trusted
	{
		final switch(orientation)
		{
			case Orientation.Vertical:
				_indentation ~= '\t';
			break;
			case Orientation.Horizontal:
				_indentation ~= '<';
			break;
		}
	}

	void unindent() @nogc @trusted
	{
		if (_indentation.length)
			_indentation.popBack;
	}

	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		position = 0;

		final switch(orientation)
		{
			case Orientation.Vertical:
			break;
			case Orientation.Horizontal:
				_indentation ~= '<';
			break;
		}
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		import std.conv : to;
		import aux.traits : hasRenderHeader;

		static if (is(typeof(model.orientation)))
		{
			old_orientation = orientation;
			orientation = model.orientation;
		}

		static if (hasRenderHeader!data)
		{
			import aux.model : FixedAppender;
			FixedAppender!512 app;
			data.renderHeader(app);
			() @trusted { processItem(app[]); } ();
		}
		else
			processItem("Caption: ", Data.stringof);
		output_position ~= TreePosition(tree_path.value, position);
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (is(typeof(model.orientation)))
		{
			orientation = old_orientation;
			if (model.orientation == Orientation.Horizontal)
				position[Orientation.Horizontal] = 0;
		}
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		processItem(data);
		output_position ~= TreePosition(tree_path.value, position);
	}
}

version(unittest) @Name("size_measuring2")
unittest
{
	@("orientation.Horizontal")
	static struct Foo
	{
		long l = -1;
		string s = "Foo";
	}

	static struct Bar
	{
		long l = 9;
		string s = "Bar";
	}

	static struct Data
	{
		float f;
		int i;
		string s = "str";
		Foo foo1;
		@("orientation.Vertical")
		Foo foo2;
		Bar bar1;
		@("orientation.Horizontal")
		Bar bar2;
	}

	Data data;

	auto model = makeModel(data);

	model.size.should.be == 0;
	setPropertyByTreePath!"collapsed"(data, model, [], false);
	setPropertyByTreePath!"collapsed"(data, model, [3], false);
	setPropertyByTreePath!"collapsed"(data, model, [4], false);
	setPropertyByTreePath!"collapsed"(data, model, [5], false);
	setPropertyByTreePath!"collapsed"(data, model, [6], false);

	auto visitor = MeasureVisitor(120, 17, Orientation.Vertical);
	model.visitForward(data, visitor);
	visitor.size[0].should.be == 120;
	visitor.size[1].should.be == 17;
	model.size.should.be == 216;
	model.f.size.should.be == 18;
	model.i.size.should.be == 18;
	model.s.size.should.be == 18;

	auto rv = RendererVisitor(120, 17);
	model.visitForward(data, rv);
	rv.size[0].should.be == 120;
	rv.size[1].should.be == 17;
	model.size.should.be == 216;
	model.f.size.should.be == 18;
	model.i.size.should.be == 18;
	model.s.size.should.be == 18;

	rv.output_position[].should.be == [
		TreePosition([],     [  0.0,   0]),
		TreePosition([0],    [  0.0,  18]),
		TreePosition([1],    [  0.0,  36]),
		TreePosition([2],    [  0.0,  54]),
		TreePosition([3],    [  0.0,  72]), // foo1 has Horizontal orientation on account of its type attribute
		TreePosition([3, 0], [  0.0,  72]),
		TreePosition([3, 1], [ 60.5,  72]),
		TreePosition([4],    [  0.0,  90]), // foo2 has Vertical orientation due to its own (symbol) attribute
		TreePosition([4, 0], [  0.0, 108]),
		TreePosition([4, 1], [  0.0, 126]),
		TreePosition([5],    [  0.0, 144]), // bar1 has Vertical orientation by default (defined by a visitor)
		TreePosition([5, 0], [  0.0, 162]),
		TreePosition([5, 1], [  0.0, 180]),
		TreePosition([6],    [  0.0, 198]), // bar2 has Horizontal orientation because its own attribute
		TreePosition([6, 0], [  0.0, 198]),
		TreePosition([6, 1], [ 60.5, 198]),
	];
}

struct RelativeMeasurer
{
	DefaultVisitorImpl!(TreePathEnabled.yes) default_visitor;
	alias default_visitor this;

	TreePosition[] output;

	void enterTree(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output = null;
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (order == Order.Sinking)
			output ~= TreePosition(tree_path.value, position);
	}

	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (order == Order.Bubbling)
			if (state != state.finishing)
				output ~= TreePosition(tree_path.value, position);
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		output ~= TreePosition(tree_path.value, position);
	}
}

struct TreePosition
{
	import std.experimental.allocator.mallocator : Mallocator;
	import automem : Vector;
	Vector!(int, Mallocator) path;
	double[2] size;

	@disable this();

	this(P, S)(P p, S s)
		if (!is(P == void[]))
	{
		path = p;
		size[0] = s[0];
		size[1] = s[1];
	}

	this(S)(void[] p, S s)
	{
		size[0] = s[0];
		size[1] = s[1];
	}

	import std.range : isOutputRange;
	import std.format : FormatSpec;

	void toString(Writer) (ref Writer w, scope const ref FormatSpec!char fmt) const
		if (isOutputRange!(Writer, char))
	{
		import std.algorithm : copy;
		import std.conv : text;

		copy(typeof(this).stringof, w);
		w.put('(');
		copy(text(path[], ", ", size), w);
		w.put(')');
	}
}

version(unittest)
{
	import unit_threaded;

	class Fixture : TestCase
	{
		import unit_threaded : should, be;
		import taggedalgebraic : TaggedAlgebraic;

		override void setup()
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
			v.size = [120, 9];
			v.orientation = Orientation.Vertical;
			model = makeModel(data);
			model.collapsed = false;
			setPropertyByTreePath!"collapsed"(data, model, [3], false);
			setPropertyByTreePath!"collapsed"(data, model, [4], false);
			setPropertyByTreePath!"collapsed"(data, model, [4, 2], false);
			setPropertyByTreePath!"collapsed"(data, model, [4, 3], false);

			// measure size
			{
				auto mv = MeasureVisitor(120, 9, Orientation.Vertical);
				model.visitForward(data, mv);
			}
		}

	package:

		static struct Test
		{
			ushort us;
			long l;
		}

		static struct Test2
		{
			size_t st;
			string s;
			Test t;
			float[] fa;
		}

		static union Payload
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
	}

	class Test1 : Fixture
	{
		override void test()
		{
			v.position = 0;
			model.visitForward(data, v);
			model.size.should.be == 180;
			v.output.should.be == [
				TreePosition([ ],       [0,   0]),
				TreePosition([0],       [0,  10]),
				TreePosition([1],       [0,  20]),
				TreePosition([2],       [0,  30]),
				TreePosition([3],       [0,  40]),
				TreePosition([3, 0],    [0,  50]),
				TreePosition([3, 1],    [0,  60]),
				TreePosition([4],       [0,  70]),
				TreePosition([4, 0],    [0,  80]),
				TreePosition([4, 1],    [0,  90]),
				TreePosition([4, 2],    [0, 100]),
				TreePosition([4, 2, 0], [0, 110]),
				TreePosition([4, 2, 1], [0, 120]),
				TreePosition([4, 3],    [0, 130]),
				TreePosition([4, 3, 0], [0, 140]),
				TreePosition([4, 3, 1], [0, 150]),
				TreePosition([4, 3, 2], [0, 160]),
				TreePosition([5],       [0, 170]),
			];
			v.pos.should.be == 170;

			v.position = 0;
			v.path.value = [4,2,1];
			model.visitForward(data, v);
			v.output.should.be == [
				TreePosition([4, 2, 1], [0,  0]),
				TreePosition([4, 3],    [0, 10]),
				TreePosition([4, 3, 0], [0, 20]),
				TreePosition([4, 3, 1], [0, 30]),
				TreePosition([4, 3, 2], [0, 40]),
				TreePosition([5],       [0, 50])
			];
		}
	}

	class Test2 : Fixture
	{
		override void test()
		{
			// default
			{
				v.path.clear;
				v.position = 0;
				v.destination[] = v.destination[0].nan;
				model.visitForward(data, v);

				v.pos.should.be == 170;
				v.path.value[].should.be == [];
			}

			// next position is between two elements
			{
				v.path.clear;
				v.position = 0;
				v.destination = 15;
				model.visitForward(data, v);

				v.pos.should.be == 10;
				v.dest.should.be == 15;
				v.path.value[].should.be == [0];
			}

			// next position is equal to start of an element
			{
				v.path.clear;
				v.position = 0;
				v.destination = 30;
				model.visitForward(data, v);

				v.pos.should.be == 30;
				v.dest.should.be == 30;
				v.path.value[].should.be == [2];
			}

			// start path is not null
			{
				v.path.value = [3, 0];
				v.path_position = 0;
				v.destination = 55;
				model.visitForward(data, v);

				v.pos.should.be == 50;
				v.dest.should.be == 55;
				v.path.value[].should.be == [4, 2];
			}

			// reverse order, start path is not null
			{
				v.path.value = [4, 1];
				v.path_position = 90;
				v.destination = 41;

				model.visitBackward(data, v);

				v.pos.should.be == 40;
				v.dest.should.be == 41;
				v.path.value[].should.be == [3];

				// bubble to the previous element
				v.destination = 19;

				model.visitBackward(data, v);

				v.path.value[].should.be == [0];
				v.pos.should.be == 10;
				v.dest.should.be == 19;
				v.output.should.be == [
					TreePosition([3], [0, 40]),
					TreePosition([2], [0, 30]),
					TreePosition([1], [0, 20]),
					TreePosition([0], [0, 10]),
				];
			}
		}
	}

	class ScrollingTest : Fixture
	{
		override void test()
		{
			v.path.clear;
			v.position = 0;

			// the element height is 10 px

			// scroll 7 px forward
			visit(model, data, v, 7);
			// current element is the root one
			v.path.value[].should.be == [];
			// position of the current element is 0 px
			v.pos.should.be == 0;
			// the window starts from 7th px
			v.dest.should.be == 7;

			// scroll the next 7th px forward
			visit(model, data, v, 14);
			// the current element is the first child element
			v.path.value[].should.be == [0];
			// position of the current element is 10 px
			v.pos.should.be == 10;
			// the window starts from 14th px
			v.dest.should.be == 14;

			// scroll the next 7th px forward
			visit(model, data, v, 21);
			// the current element is the second child element
			v.path.value[].should.be == [1];
			// position of the current element is 20 px
			v.pos.should.be == 20;
			// the window starts from 21th px
			v.dest.should.be == 21;

			// scroll the next 7th px forward
			visit(model, data, v, 28);
			// the current element is the second child element
			v.path.value[].should.be == [1];
			// position of the current element is 20 px
			v.pos.should.be == 20;
			// the window starts from 28th px
			v.dest.should.be == 28;

			// scroll the next 7th px forward
			visit(model, data, v, 35);
			// the current element is the third child element
			v.path.value[].should.be == [2];
			// position of the current element is 30 px
			v.pos.should.be == 30;
			// the window starts from 35th px
			v.dest.should.be == 35;

			// scroll 7th px backward
			visit(model, data, v, 27);
			// the current element is the second child element
			v.path.value[].should.be == [1];
			// position of the current element is 20 px
			v.pos.should.be == 20;
			// the window starts from 27th px
			v.dest.should.be == 27;

			// scroll the next 9th px backward
			visit(model, data, v, 18);
			// the current element is the first child element
			v.path.value[].should.be == [0];
			// position of the current element is 10 px
			v.pos.should.be == 10;
			// the window starts from 18th px
			v.dest.should.be == 18;

			// scroll the next 6th px backward
			visit(model, data, v, 12);
			// the current element is the first child element
			v.path.value[].should.be == [0];
			// position of the current element is 10 px
			v.pos.should.be == 10;
			// the window starts from 12th px
			v.dest.should.be == 12;

			// scroll the next 5th px backward
			visit(model, data, v, 7);
			// the current element is the root element
			v.path.value[].should.be == [];
			// position of the current element is 0 px
			v.pos.should.be == 0;
			// the window starts from 7th px
			v.dest.should.be == 7;

			// scroll 76 px forward
			visit(model, data, v, 83);
			// // the current element is the second child element
			// v.path.value[].should.be == [4, 0];
			// // position of the current element is 20 px
			// v.pos.should.be == 80;
			// the window starts from 27th px
			v.dest.should.be == 83;

			visit(model, data, v, 81);
			v.path.value[].should.be == [4, 0];
			v.pos.should.be == 80;
			v.dest.should.be == 81;

			visit(model, data, v, 80);
			v.path.value[].should.be == [4, 0];
			v.pos.should.be == 80;
			v.dest.should.be == 80;

			visit(model, data, v, 79.1);
			v.path.value[].should.be == [4];
			v.pos.should.be == 70;
			v.dest.should.be ~ 79.1;

			visit(model, data, v, 133.4);
			v.path.value[].should.be == [4, 3];
			v.pos.should.be == 130;
			v.dest.should.be ~ 133.4;

			visit(model, data, v, 0);
			v.path.value[].should.be == [];
			v.pos.should.be == 0;
			v.dest.should.be ~ 0.0;
		}
	}
}

version(unittest) @Name("reverse_dynamic_array")
unittest
{
	import unit_threaded : should, be;

	auto data = [0, 1, 2, 3];
	auto model = makeModel(data);
	auto visitor = RelativeMeasurer();
	visitor.size = [120, 9];
	visitor.orientation = Orientation.Vertical;

	model.collapsed = false;
	{
		auto mv = MeasureVisitor(120, 9, Orientation.Vertical);
		model.visitForward(data, mv);
	}
	visitor.position = 0;
	model.visitForward(data, visitor);
	visitor.output.should.be == [
		TreePosition([ ], [0,  0]),
		TreePosition([0], [0, 10]),
		TreePosition([1], [0, 20]),
		TreePosition([2], [0, 30]),
		TreePosition([3], [0, 40]),
	];

	visitor.pos.should.be == 40;

	model.visitBackward(data, visitor);
	visitor.output.should.be == [
		TreePosition([3], [0, 40]),
		TreePosition([2], [0, 30]),
		TreePosition([1], [0, 20]),
		TreePosition([0], [0, 10]),
		TreePosition([ ], [0,  0]),
	];

	visitor.path.value = [1,];
	visitor.position[visitor.orientation] = 20;
	model.visitForward(data, visitor);
	visitor.output.should.be == [
		TreePosition([1], [0, 20]),
		TreePosition([2], [0, 30]),
		TreePosition([3], [0, 40]),
	];

	visitor.path.value = [1,];
	visitor.position[visitor.orientation] = 20;
	model.visitBackward(data, visitor);
	visitor.output.should.be == [
		TreePosition([1], [0, 20]),
		TreePosition([0], [0, 10]),
		TreePosition([ ], [0,  0]),
	];
}

version(unittest) @Name("aggregate")
unittest
{
	import unit_threaded : should, be;

	static struct NestedData1
	{
		long l;
		char ch;
	}

	static struct NestedData2
	{
		short sh;
		NestedData1 data1;
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

	const data = Data(0, 1, 2, "3", NestedData2(ushort(2), NestedData1(1_000_000_000, 'z'), "text"));
	auto model = makeModel(data);
	auto visitor = RelativeMeasurer();
	visitor.size = [120, 9];
	visitor.orientation = Orientation.Vertical;

	model.collapsed = false;
	{
		auto mv = MeasureVisitor(120, 9, Orientation.Vertical);
		model.visitForward(data, mv);
	}
	visitor.position = 0;
	model.visitForward(data, visitor);
	visitor.output.should.be == [
		TreePosition([ ], [0,  0]),
		TreePosition([0], [0, 10]),
		TreePosition([1], [0, 20]),
		TreePosition([2], [0, 30]),
		TreePosition([3], [0, 40]),
		TreePosition([4], [0, 50]),
	];
	version(none) visitor.path.value[].should.be == [4];
	visitor.pos.should.be == 50;

	{
		visitor.path.clear;
		visitor.position[visitor.orientation] = 0;
		visitor.dest = 30;
		model.visitForward(data, visitor);
		visitor.output.should.be == [
			TreePosition([ ], [0,  0]),
			TreePosition([0], [0, 10]),
			TreePosition([1], [0, 20]),
			TreePosition([2], [0, 30]),
		];
		visitor.path.value[].should.be == [2];
		visitor.pos.should.be == 30;
	}

	{
		visitor.path.clear;
		visitor.position[visitor.orientation] = 30;
		visitor.dest = visitor.pos + 30;
		model.visitForward(data, visitor);
		visitor.output.should.be == [
			TreePosition([ ], [0, 30]),
			TreePosition([0], [0, 40]),
			TreePosition([1], [0, 50]),
			TreePosition([2], [0, 60]),
		];
		visitor.path.value[].should.be == [2];
		visitor.pos.should.be == 60;
	}

	{
		visitor.path.value = [0];
		visitor.position[visitor.orientation] = 130;
		visitor.destination[visitor.orientation] = visitor.position[visitor.orientation] + 20;
		model.visitForward(data, visitor);
		visitor.output.should.be == [
			TreePosition([0], [0, 130]),
			TreePosition([1], [0, 140]),
			TreePosition([2], [0, 150]),
		];
		visitor.path.value[].should.be == [2];
		visitor.pos.should.be == 150;
	}

	visitor.path.value = [2];
	visitor.position[visitor.orientation] = 30;
	visitor.destination[visitor.orientation] = visitor.dest.nan;
	model.visitForward(data, visitor);

	visitor.output.should.be == [
		TreePosition([2], [0, 30]),
		TreePosition([3], [0, 40]),
		TreePosition([4], [0, 50]),
	];
	version(none) visitor.path.value[].should.be == [4];
	visitor.pos.should.be == 50;

	visitor.path.clear;
	visitor.dest = visitor.dest.nan;
	model.visitBackward(data, visitor);
	visitor.output.should.be == [
		TreePosition([4], [0, 50]),
		TreePosition([3], [0, 40]),
		TreePosition([2], [0, 30]),
		TreePosition([1], [0, 20]),
		TreePosition([0], [0, 10]),
		TreePosition([],  [0,  0]),
	];
	visitor.path.value[].should.be == [];
	visitor.pos.should.be == 0;
}

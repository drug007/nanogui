module auxil.model;

import std.traits : isInstanceOf;
import taggedalgebraic : TaggedAlgebraic, taget = get;
import auxil.traits;
import auxil.model.state : State;
import auxil.model.accept_impl : acceptImpl;

version(unittest) import unit_threaded : Name;

private import std.range : isRandomAccessRange;
private import std.traits : isSomeString, isStaticArray, isAssociativeArray;
private enum dataHasStaticArrayModel(T) = isStaticArray!T;
private enum dataHasAssociativeArrayModel(T) = isAssociativeArray!T;
private enum dataHasRandomAccessRangeModel(T) = isRandomAccessRange!T && !isSomeString!T && !dataHasTaggedAlgebraicModel!T;
private enum dataHasAggregateModel(T) = (is(T == struct) || is(T == union)) && !dataHasRandomAccessRangeModel!T && !dataHasTaggedAlgebraicModel!T;
private enum dataHasTaggedAlgebraicModel(T) = is(T == struct) && isInstanceOf!(TaggedAlgebraic, T);
private enum isCollapsable(T) = is(typeof(T.Collapsable)) && T.Collapsable;

private template NoInout(T)
{
	static if (is(T U == inout U))
		alias NoInout = U;
	else
		alias NoInout = T;
}

template Model(alias A)
{
	import std.typecons : Nullable;
	import std.datetime : Duration;

	static if (dataHasStaticArrayModel!(TypeOf!A))
		alias Model = StaticArrayModel!A;
	else static if (dataHasRandomAccessRangeModel!(TypeOf!A))
		alias Model = RaRModel!A;
	else static if (dataHasAssociativeArrayModel!(TypeOf!A))
		alias Model = AssocArrayModel!A;
	else static if (dataHasTaggedAlgebraicModel!(TypeOf!A))
		alias Model = TaggedAlgebraicModel!A;
	else static if (dataHasAggregateModel!(TypeOf!A) && hasRenderedAs!A)
		alias Model = RenderedAsAggregateModel!A;
	else static if (dataHasAggregateModel!(TypeOf!A) && hasRenderedAsMember!(TypeOf!A))
		alias Model = RenderedAsMemberAggregateModel!A;
	else static if (dataHasAggregateModel!(TypeOf!A) && getRenderedAsMemberString!A.length == 1)
		alias Model = RenderedAsMemberStringAggregateModel!A;
	else static if (dataHasAggregateModel!(TypeOf!A) && getRenderedAsPointeeString!A.length == 1)
		alias Model = RenderedAsPointeeStringModel!A;
	else static if (is(TypeOf!A : Duration))
		alias Model = DurationModel!A;
	else static if (isNullable!(TypeOf!A))
		alias Model = NullableModel!A;
	else static if (isTimemarked!(TypeOf!A))
		alias Model = TimemarkedModel!A;
	else static if (dataHasAggregateModel!(TypeOf!A))
		alias Model = AggregateModel!A;
	else
		alias Model = ScalarModel!A;
}

struct StaticArrayModel(alias A)// if (dataHasStaticArrayModel!(TypeOf!A))
{
	enum Collapsable = true;

	mixin State;

	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	alias ElementType = typeof(Data.init[0]);
	Model!ElementType[Data.length] model;
	alias model this;

	this()(const(Data) data) if (Data.sizeof <= (void*).sizeof)
	{
		foreach(i; 0..data.length)
			model[i] = Model!ElementType(data[i]);
	}

	this()(ref const(Data) data) if (Data.sizeof > (void*).sizeof)
	{
		foreach(i; 0..data.length)
			model[i] = Model!ElementType(data[i]);
	}

	mixin acceptImpl;
}

struct RaRModel(alias A)// if (dataHasRandomAccessRangeModel!(TypeOf!A))
{
	import automem : Vector;
	import std.experimental.allocator.mallocator : Mallocator;

	enum Collapsable = true;

	mixin State;

	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	alias ElementType = typeof(Data.init[0]);
	Vector!(Model!ElementType, Mallocator) model;
	alias model this;

	this()(const(Data) data) if (Data.sizeof <= (void*).sizeof)
	{
		update(data);
	}

	this()(ref const(Data) data) if (Data.sizeof > (void*).sizeof)
	{
		update(data);
	}

	void update(ref const(Data) data)
	{
		model.length = data.length;
		foreach(i, ref e; model)
			e = Model!ElementType(data[i]);
	}

	void update(T)(ref TaggedAlgebraic!T v)
	{
		update(taget!Data(v));
	}

	mixin acceptImpl;
}

struct AssocArrayModel(alias A)// if (dataHasAssociativeArrayModel!(TypeOf!A))
{
	import automem : Vector;
	import std.experimental.allocator.mallocator : Mallocator;

	enum Collapsable = true;

	static assert(dataHasAssociativeArrayModel!(TypeOf!A));

	mixin State;

	alias Data = TypeOf!A;
	alias Key = typeof(Data.init.byKey.front);
	static assert(isProcessible!Data);

	alias ElementType = typeof(Data.init[0]);
	Vector!(Model!ElementType, Mallocator) model;
	Vector!(Key, Mallocator) keys;
	alias model this;

	this()(const(Data) data) if (Data.sizeof <= (void*).sizeof)
	{
		update(data);
	}

	this()(ref const(Data) data) if (Data.sizeof > (void*).sizeof)
	{
		update(data);
	}

	void update(ref const(Data) data)
	{
		model.length = data.length;
		keys.reserve(data.length);
		foreach(k; data.byKey)
			keys ~= k;
		foreach(i, ref e; model)
			e = Model!ElementType(data[keys[i]]);
	}

	void update(T)(ref TaggedAlgebraic!T v)
	{
		update(taget!Data(v));
	}

	mixin acceptImpl;
}

struct TaggedAlgebraicModel(alias A)// if (dataHasTaggedAlgebraicModel!(TypeOf!A))
{
	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	import std.traits : Fields;
	import std.meta : anySatisfy;
	enum Collapsable = anySatisfy!(isCollapsable, Fields!Payload);

	private static struct Payload
	{
		static foreach(i, fname; Data.UnionType.fieldNames)
		{
			mixin("Model!(Data.UnionType.FieldTypes[__traits(getMember, Data.Kind, fname)]) " ~ fname ~ ";");
		}
	}

	static struct TAModel
	{
		TaggedAlgebraic!Payload value;
		alias value this;

		@property void collapsed(bool v)
		{
			final switch(value.kind)
			{
				foreach (i, FT; value.UnionType.FieldTypes)
				{
					case __traits(getMember, value.Kind, value.UnionType.fieldNames[i]):
						static if (is(typeof(taget!FT(value).collapsed) == bool))
							taget!FT(value).collapsed = v;
					return;
				}
			}
			assert(0); // never reached
		}

		@property bool collapsed() const
		{
			final switch(value.kind)
			{
				foreach (i, FT; value.UnionType.FieldTypes)
				{
					case __traits(getMember, value.Kind, value.UnionType.fieldNames[i]):
						static if (is(typeof(taget!FT(value).collapsed) == bool))
							return taget!FT(value).collapsed;
						else
							assert(0);
				}
			}
			assert(0); // never reached
		}

		@property size() const
		{
			final switch(value.kind)
			{
				foreach (i, FT; value.UnionType.FieldTypes)
				{
					case __traits(getMember, value.Kind, value.UnionType.fieldNames[i]):
						return taget!FT(value).size;
				}
			}
			assert(0);
		}

		this(T)(T v)
		{
			value = v;
		}
	}
	TAModel tamodel;
	alias tamodel this;

	/// returns a model corresponding to given data value
	static TAModel makeModel(ref const(Data) data)
	{
		final switch(data.kind)
		{
			foreach (i, FT; data.UnionType.FieldTypes)
			{
				case __traits(getMember, data.Kind, data.UnionType.fieldNames[i]):
					return TAModel(Model!FT(data.taget!FT));
			}
		}
	}

	this()(auto ref const(Data) data)
	{
		tamodel = makeModel(data);
	}

	bool accept(Order order, Visitor)(ref const(Data) data, ref Visitor visitor)
	{
		final switch (data.kind) {
			foreach (i, fname; Data.UnionType.fieldNames)
			{
				case __traits(getMember, data.Kind, fname):
					if (taget!(this.UnionType.FieldTypes[i])(tamodel).accept!order(
							taget!(Data.UnionType.FieldTypes[i])(data),
							visitor,
						))
					{
						return true;
					}
				break;
			}
		}
		return false;
	}
}

template AggregateModel(alias A) // if (dataHasAggregateModel!(TypeOf!A) && !is(TypeOf!A : Duration) && !hasRenderedAs!A)
{
	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	static if (DrawableMembers!Data.length == 1)
	{
		struct SingleMemberAggregateModel(T)
		{
			enum member = DrawableMembers!T[0];
			alias Member = TypeOf!(mixin("T." ~ member));
			Model!Member single_member_model;
			alias single_member_model this;

			enum Collapsable = single_member_model.Collapsable;

			this()(auto ref const(T) data)
			{
				import std.format : format;

				static if (isNullable!(typeof(mixin("data." ~ member))) ||
						isTimemarked!(typeof(mixin("data." ~ member))))
				{
					if (!mixin("data." ~ member).isNull)
						mixin("single_member_model = Model!Member(data.%1$s);".format(member));
				}
				else
					mixin("single_member_model = Model!Member(data.%1$s);".format(member));
			}

			bool accept(Order order, Visitor)(auto ref const(T) data, ref Visitor visitor)
			{
				return single_member_model.accept!order(mixin("data." ~ member), visitor);
			}
		}
		alias AggregateModel = SingleMemberAggregateModel!Data;
	}
	else
	{
		struct AggregateModel
		{
			enum Collapsable = true;

			import std.format : format;

			mixin State;

			import auxil.traits : DrawableMembers;
			static foreach(member; DrawableMembers!Data)
				mixin("Model!(Data.%1$s) %1$s;".format(member));

			this()(auto ref const(Data) data)
			{
				foreach(member; DrawableMembers!Data)
				{
					static if (isNullable!(typeof(mixin("data." ~ member))) ||
							isTimemarked!(typeof(mixin("data." ~ member))))
					{
						if (mixin("data." ~ member).isNull)
							continue;
					}
					else
						mixin("this.%1$s = Model!(Data.%1$s)(data.%1$s);".format(member));
				}
			}

			mixin acceptImpl;
		}
	}
}

struct RenderedAsAggregateModel(alias A)// if (dataHasAggregateModel!(TypeOf!A) && hasRenderedAs!A)
{
	import auxil.traits : getRenderedAs;

	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	alias Proxy = getRenderedAs!A;
	static assert(isProcessible!Proxy);
	Proxy proxy;
	Model!proxy proxy_model;

	enum Collapsable = proxy_model.Collapsable;

	alias proxy_model this;

	this()(auto ref const(Data) data)
	{
		import std.conv : to;
		proxy = data.to!Proxy;
		proxy_model = Model!proxy(proxy);
	}

	bool accept(Order order, Visitor)(auto ref const(Data) ignored_data, ref Visitor visitor)
	{
		return proxy_model.accept!order(proxy, visitor);
	}
}

struct RenderedAsMemberAggregateModel(alias A)// if (dataHasAggregateModel!Data && hasRenderedAsMember!Data)
{
	import auxil.traits : getRenderedAs;

	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	enum member_name = getRenderedAsMember!Data;
	Model!(mixin("Data." ~ member_name)) model;

	enum Collapsable = model.Collapsable;

	alias model this;

	this()(auto ref const(Data) data)
	{
		model = typeof(model)(mixin("data." ~ member_name));
	}

	bool accept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		return model.accept!order(mixin("data." ~ member_name), visitor);
	}
}

struct RenderedAsMemberStringAggregateModel(alias A)// if (dataHasAggregateModel!Data && getRenderedAsMemberString!Data.length == 1)
{
	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	enum member_name = getRenderedAsMemberString!A[0];
	Model!(mixin("Data." ~ member_name)) model;

	enum Collapsable = model.Collapsable;

	alias model this;

	this()(auto ref const(Data) data)
	{
		model = typeof(model)(mixin("data." ~ member_name));
	}

	bool accept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		return model.accept!order(mixin("data." ~ member_name), visitor);
	}
}

struct RenderedAsPointeeStringModel(alias A)
{
	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	enum member_name = getRenderedAsPointeeString!A[0];
	Model!(typeof(mixin("*Data.init." ~ member_name))) model;

	enum Collapsable = model.Collapsable;

	alias model this;

	this()(auto ref const(Data) data)
	{
		model = typeof(model)(*mixin("data." ~ member_name));
	}

	bool accept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		return model.accept!order(*mixin("data." ~ member_name), visitor);
	}
}

struct DurationModel(alias A)
{
	import std.datetime : Duration;

	alias Data = TypeOf!A;
	static assert(isProcessible!Data);
	static assert(is(TypeOf!A : Duration));

	enum Collapsable = false;

	alias Proxy = string;
	static assert(isProcessible!Proxy);
	Proxy proxy;
	Model!proxy proxy_model;

	alias proxy_model this;

	this()(auto ref const(Data) data)
	{
		import std.conv : to;
		proxy = data.to!Proxy;
		proxy_model = Model!proxy(proxy);
	}

	bool accept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		return proxy_model.accept!order(proxy, visitor);
	}
}

struct NullableModel(alias A)
{
	import std.typecons : Nullable;

	alias Data = TypeOf!A;
	static assert(isProcessible!Data);
	static assert(isInstanceOf!(Nullable, Data));
	alias Payload = typeof(Data.get);

	enum Collapsable = true;

	enum NulledPayload = __traits(identifier, A) ~ ": null";
	Model!string  nulled_model = makeModel(NulledPayload);
	Model!Payload nullable_model;
	private bool isNull;

	alias nullable_model this;

	@property auto size()
	{
		return (isNull) ? nulled_model.size : nullable_model.size;
	}

	@property auto size(double v)
	{
		if (isNull)
			nulled_model.size = v;
		else
			nullable_model.size = v;
	}

	this()(auto ref const(Data) data)
	{
		isNull = data.isNull;
		if (isNull)
			nullable_model = Model!Payload();
		else
			nullable_model = Model!Payload(data.get);
	}

	bool accept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		isNull = data.isNull;
		if (isNull)
			return nulled_model.accept!order(NulledPayload, visitor);
		else
			return nullable_model.accept!order(data.get, visitor);
	}
}

version(HAVE_TIMEMARKED)
struct TimemarkedModel(alias A)
{
	import rdp.timemarked : Timemarked;

	alias Data = TypeOf!A;
	static assert(isInstanceOf!(Timemarked, Data));

	@("renderedAsPointee.payload")
	struct TimemarkedPayload
	{
		alias Payload = NoInout!(typeof(Data.value));
		const(Payload)* payload;
		static string prefix = __traits(identifier, A);

		this(ref const(Payload) payload)
		{
			this.payload = &payload;
		}
	}

	enum Collapsable = true;

	enum NulledPayload = __traits(identifier, A) ~ ": null";
	Model!string nulled_model = Model!string(NulledPayload);
	Model!TimemarkedPayload timemarked_model;
	version(none) Model!(Data.value) value_model;
	version(none) Model!(Data.timestamp) timestamp_model;
	private bool isNull;

	alias timemarked_model this;

	@property auto size()
	{
		return (isNull) ? nulled_model.size : timemarked_model.size;
	}

	@property auto size(double v)
	{
		if (isNull)
			nulled_model.size = v;
		else
			timemarked_model.size = v;
	}

	this()(auto ref const(Data) data)
	{
		isNull = data.isNull;
		if (isNull)
			timemarked_model = Model!TimemarkedPayload();
		else
			timemarked_model = Model!TimemarkedPayload(data.value);
	}

	bool accept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		isNull = data.isNull;
		if (isNull)
			return nulled_model.accept!order(NulledPayload, visitor);

		if (timemarked_model.accept!order(TimemarkedPayload(data.value), visitor))
			return true;

		version(none)
		{
			visitor.indent;
			scope(exit) visitor.unindent;

			if (timestamp_model.accept!order(data.timestamp, visitor))
				return true;
		}

		return false;
	}
}

struct ScalarModel(alias A)
	if (!dataHasAggregateModel!(TypeOf!A) && 
	    !dataHasStaticArrayModel!(TypeOf!A) &&
	    !dataHasRandomAccessRangeModel!(TypeOf!A) &&
	    !dataHasTaggedAlgebraicModel!(TypeOf!A) &&
	    !dataHasAssociativeArrayModel!(TypeOf!A))
{
	enum Spacing = 1;
	float size = 0;

	enum Collapsable = false;

	alias Data = TypeOf!A;
	static assert(isProcessible!Data);

	this()(auto ref const(Data) data)
	{
	}

	private bool accept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		import std.algorithm : among;

		enum Sinking     = order == Order.Sinking;
		enum Bubbling    = !Sinking; 
		enum hasTreePath = Visitor.treePathEnabled;
		enum hasSize     = Visitor.sizeEnabled;

		static if (hasTreePath)
		{
			with(visitor) final switch(state)
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
		}
		if (visitor.complete)
		{
			return true;
		}

		static if (hasSize) this.size = visitor.size + this.Spacing;
		static if (hasTreePath) with(visitor) 
		{
			position += deferred_change;
			deferred_change = (Sinking) ? this.size : -this.size;

			if (state.among(State.first, State.rest))
			{
				static if (Sinking) visitor.processLeaf!order(data, this);
				if ((Sinking  && position+deferred_change > destination) ||
					(Bubbling && position                 < destination))
				{
					state = State.finishing;
					path = tree_path;
				}
				static if (Bubbling) visitor.processLeaf!order(data, this);
			}
		}
		else
			visitor.processLeaf!order(data, this);

		return false;
	}
}

auto makeModel(T)(auto ref const(T) data)
{
	return Model!T(data);
}

private auto getIndex(Data, M)(ref M model, size_t i)
{
	static if (dataHasStaticArrayModel!Data || 
	           dataHasRandomAccessRangeModel!Data ||
	           dataHasAggregateModel!Data)
		return i;
	else static if (dataHasAssociativeArrayModel!Data)
		return model.keys[i];
	else
		static assert(0);
}

private auto getLength(Data, alias data)()
{
	static if (dataHasStaticArrayModel!Data || 
	           dataHasRandomAccessRangeModel!Data ||
	           dataHasAssociativeArrayModel!Data)
		return data.length;
	else static if (dataHasAggregateModel!Data)
		return DrawableMembers!Data.length;
	else
		static assert(0);
}

enum Order { Sinking, Bubbling, }

void traversal(Model, Data, Visitor)(ref Model model, auto ref Data data, ref Visitor visitor, double destination)
{
	visitor.destination = destination;
	if (destination == visitor.position)
		return;
	else if (destination < visitor.position)
		model.traversalBackward(data, visitor);
	else
		model.traversalForward(data, visitor);
}

void traversalForward(Model, Data, Visitor)(ref Model model, auto ref const(Data) data, ref Visitor visitor)
{
	enum order = Order.Sinking;
	static if (Visitor.treePathEnabled)
	{
		visitor.state = (visitor.path.value.length) ? visitor.State.seeking : visitor.State.rest;
		visitor.deferred_change = 0;
	}
	visitor.enterTree!order(data, model);
	model.accept!order(data, visitor);
}

void traversalBackward(Model, Data, Visitor)(ref Model model, auto ref Data data, ref Visitor visitor)
{
	enum order = Order.Bubbling;
	static if (Visitor.treePathEnabled)
	{
		visitor.state = (visitor.path.value.length) ? visitor.State.seeking : visitor.State.rest;
		visitor.deferred_change = 0;
	}
	visitor.enterTree!order(data, model);
	model.accept!order(data, visitor);
}

version(unittest) @Name("null_visitor")
unittest
{
	int[] data = [1, 2];
	NullVisitor visitor;
	auto model = makeModel(data);
	model.traversalForward(data, visitor);
}

import std.typecons : Flag;

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
		SizeType size;

		this(SizeType s) @safe @nogc nothrow
		{
			size = s;
		}
	}

	static if (treePathEnabled == TreePathEnabled.yes)
	{
		import auxil.model.tree_path : TreePath;

		enum State { seeking, first, rest, finishing, }
		State state;
		TreePath tree_path, path;
		SizeType position, deferred_change, destination;
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

		static if (sizeEnabled == SizeEnabled.yes) model.size = model.header_size = size + model.Spacing;

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
			enum Sinking = order == Order.Sinking;

			static if (Sinking)
			{
				position += deferred_change;
				deferred_change = model.header_size;
			}
			derivedVisitor.enterNode!(order, Data)(data, model);
			static if (Sinking)
			{
				if (position+deferred_change > destination)
				{
					state = State.finishing;
					path = tree_path;
				}
			}
		}

		return false;
	}

	bool doEnterNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled == TreePathEnabled.no)
	{
		static if (sizeEnabled == SizeEnabled.yes) model.size = model.header_size = size + model.Spacing;

		derivedVisitor.enterNode!(order, Data)(data, model);

		return false;
	}

	void doLeaveNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled == TreePathEnabled.yes)
	{
		import std.algorithm : among;

		if (state.among(State.first, State.rest))
		{
			static if (order == Order.Bubbling)
			{
				position += deferred_change;
				deferred_change = -model.header_size;
				if (position <= destination)
				{
					state = State.finishing;
					path = tree_path;
				}
			}
			derivedVisitor.leaveNode!order(data, model);
		}
	}

	void doLeaveNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled == TreePathEnabled.no)
	{
		derivedVisitor.leaveNode!order(data, model);
	}
}

version(unittest) @Name("MeasuringVisitor")
unittest
{
	import std.algorithm : map;
	import unit_threaded : should, be;

	auto data = [0, 1, 2, 3];
	auto model = makeModel(data);
	auto visitor = MeasuringVisitor(9);

	model.collapsed = false;
	model.traversalForward(data, visitor);

	model.size.should.be == 50;
	model[].map!"a.size".should.be == [10, 10, 10, 10];
}

version(unittest) @Name("union")
unittest
{
	union U
	{
		int i;
		double d;
	}

	U u;
	auto m = makeModel(u);
}

version(unittest) @Name("DurationTest")
unittest
{
	import std.datetime : Duration;
	import std.meta : AliasSeq;

	@renderedAs!string
	static struct DurationProxy
	{
		@ignored
		Duration ptr;

		this(Duration d)
		{
			ptr = d;
		}
 
		string opCast(T : string)()
		{
			return ptr.toISOExtString;
		}
	}

	static struct Test
	{
		@renderedAs!DurationProxy
		Duration d;
	}

	Test test;
	auto m = makeModel(test);

	import std.traits : FieldNameTuple;
	import std.meta : AliasSeq;

	static assert(FieldNameTuple!(typeof(m))                                 == AliasSeq!("single_member_model"));
	static assert(FieldNameTuple!(typeof(m.single_member_model))             == AliasSeq!("proxy", "proxy_model"));
	static assert(FieldNameTuple!(typeof(m.single_member_model.proxy))       == AliasSeq!(""));
	static assert(FieldNameTuple!(typeof(m.single_member_model.proxy_model)) == AliasSeq!("size"));

	@renderedAs!string
	Duration d;

	static assert(dataHasAggregateModel!(TypeOf!d));
	static assert(hasRenderedAs!d);

	auto m2 = makeModel(d);
	static assert(is(m2.Proxy == string));
}

version(unittest) @Name("modelHasCollapsed")
@safe
unittest
{
	import unit_threaded : should, be;

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

	// check if Model!T has collapsed member
	enum modelHasCollapsed(T) = is(typeof(Model!T.collapsed) == bool);

	// Model of plain old data has no collapsed member
	assert(!modelHasCollapsed!float);
	// Model of structures has collapsed member
	assert( modelHasCollapsed!Test );
	assert( modelHasCollapsed!StructWithStruct);
	// Model of unprocessible structures and classes do not
	// exist so they have nothing
	assert(!modelHasCollapsed!TestClass);
	assert(!modelHasCollapsed!StructWithPointerAndClass);
	assert(!modelHasCollapsed!StructWithNestedClass);

	import std.traits : FieldNameTuple;
	FieldNameTuple!(Model!StructWithStruct).length.should.be == 6;
}

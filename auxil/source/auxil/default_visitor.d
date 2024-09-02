module auxil.default_visitor;

import std.typecons : Flag;

version(unittest) import unit_threaded : Name;

import auxil.common : Order, SizeType, Orientation;

/// Stores the data needed afterwards
struct StackRecord
{
	SizeType position;
	Orientation orientation;
}

struct FeaturesNull {}

struct FeaturesSize
{
	bool SizeCalculationEnabled;
}

struct FeaturesTreePath
{
	bool TreePathEnabled;
}

struct FeaturesSizeTreePath
{
	bool SizeCalculationEnabled, TreePathEnabled;
}

// Предусмотрено использование размера по обоим осям для отрисовки
// (на чтение, без расчета размера), а также пути для навигации
struct FeaturesRenderer
{
	bool SizeEnabled, TreePathEnabled;
}

alias NullVisitor      = DefaultVisitorImpl!FeaturesNull;
alias MeasuringVisitor = DefaultVisitorImpl!FeaturesSize;
alias TreePathVisitor  = DefaultVisitorImpl!FeaturesTreePath;
alias DefaultVisitor   = DefaultVisitorImpl!FeaturesSizeTreePath;
alias DefaultRenderingVisitor  = DefaultVisitorImpl!FeaturesRenderer;

/// Default implementation of Visitor
struct DefaultVisitorImpl(Features)
{
	enum sizeCalculationEnabled = is(typeof(Features.SizeCalculationEnabled));
	enum sizeEnabled = is(typeof(Features.SizeEnabled)) || sizeCalculationEnabled;
	enum treePathEnabled = is(typeof(Features.TreePathEnabled));

	private Orientation _orientation = Orientation.Vertical;

	Orientation orientation() const { return _orientation; }

	static if (sizeEnabled)
	{
		private SizeType[2] _size;

		@disable this();

		this(SizeType sx, SizeType sy) @safe @nogc nothrow
		{
			_size[Orientation.Horizontal] = sx;
			_size[Orientation.Vertical] = sy;
		}

		auto sizeX()
		{
			return _size[Orientation.Horizontal];
		}

		auto sizeY()
		{
			return _size[Orientation.Vertical];
		}

		auto size()
		{
			return _size;
		}
	}

	/// After child visiting update parent size
	void afterChildVisiting(ParentModel, ChildModel)(ref ParentModel parent, ref ChildModel child)
	{
		static if (sizeCalculationEnabled)
		{
			static if (is(typeof(child.orientation)))
			{
				Orientation childOrientation = void;
				// TaggedAlgebraic payload has orientation if any its member has it. So
				// is(typeof(child.hasOrientation) may be true but the current TaggedAlgebraic
				// payload may does not have this property so additional check availablity of this
				// property in runtime
				static if (is(typeof(child.hasOrientation) == bool))
				{
					// in runtime check if the current value type has orientation
					childOrientation = child.hasOrientation ? child.orientation : parent.orientation;
				}
				else
					childOrientation = child.orientation;

				if (parent.orientation != childOrientation)
				{
					// if orientations mismatch use parent orientation
					parent.sizeYM += size[parent.orientation] + parent.Spacing;
					return;
				}
			}

			parent.sizeYM += child.sizeYM;
		}
	}

	/// Update current tree path
	void setTreePath(int i)
	{
		static if (treePathEnabled)
			tree_path.back = i;
	}

	bool doBeforeChildren(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
	{
		static if (order == Order.Bubbling && treePathEnabled)
		{
			// Edge case if the start path starts from this collapsable exactly
			// then the childs of the collapsable aren't processed
			if (derivedVisitor.path.value.length && derivedVisitor.tree_path.value[] == derivedVisitor.path.value[])
			{
				return false;
			}
		}

		if (!model.length)
			return false;

		static if (treePathEnabled) derivedVisitor.tree_path.put(0);

		return true;
	}

	void doAfterChildren(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
	{
		static if (treePathEnabled) derivedVisitor.tree_path.popBack;
	}

	size_t getStartValue(Order order, Model)(ref Model model)
	{
		assert(model.length);

		static if (order == Order.Bubbling)
		{
			size_t startValue = model.length;
			startValue--; // to avoid warning about decrement unsigned type value
		}
		else
			size_t startValue = 0;

		static if (treePathEnabled)
		{
			import std.algorithm : among;

			if (this.state.among(this.State.seeking, this.State.first))
			{
				auto idx = this.tree_path.value.length;
				if (idx && this.path.value.length >= idx)
				{
					startValue = this.path.value[idx-1];
					// position should change only if we've got the initial path
					// and don't get the end
					if (this.state == this.State.seeking) this.clear;
				}
			}
		}

		return startValue;
	}

	static if (sizeEnabled && treePathEnabled)
	{
		void indent(SizeType size)
		{
			if (_orientation == Orientation.Vertical)
			{
				_pos[Orientation.Horizontal] += size;
					_size[_orientation] -= size;
			}
			else
				assert(0, "No indent in horizontal orientation");
		}
	}

	static if (treePathEnabled)
	{
		import std.experimental.allocator.mallocator : Mallocator;
		import automem : Vector;
		import auxil.tree_path : TreePath;

		enum State { seeking, first, rest, finishing, }
		State state;
		TreePath tree_path, path;
		private SizeType[2] _pos, _deferred_change, _destination;
		private Vector!(StackRecord, Mallocator) _stack;

		SizeType posX() const { return _pos[Orientation.Horizontal]; }
		SizeType posX(SizeType value) { _pos[Orientation.Horizontal] = value; return value; }
		SizeType posY() const { return _pos[Orientation.Vertical]; }
		SizeType posY(SizeType value) { _pos[Orientation.Vertical] = value; return value; }

		SizeType destX() const { return _destination[Orientation.Horizontal]; }
		SizeType destX(SizeType value) { _destination[Orientation.Horizontal] = value; return value; }

		SizeType destY() const { return _destination[Orientation.Vertical]; }
		SizeType destY(SizeType value) { _destination[Orientation.Vertical] = value; return value; }

		package void pushRecord(SizeType pos, Orientation o) @trusted
		{
			_stack.put(StackRecord(pos, o));
		}

		package void popRecord()
		{
			_stack.popBack;
		}

		package ref auto getRecord() const
		{
			import std.array : back;

			return _stack[$-1];
		}

		void clear()
		{
			_deferred_change = 0;
		}
	}

	package void updatePosition(Change)(Change change)
	{
		_pos[_orientation] += _deferred_change[_orientation];
		_deferred_change[_orientation] = change;
	}

	/// Update current position and keep deferred change
	/// useful when orientation is changed to return to the previous
	/// orientation later
	package void changeOrientation()
	{
		static if (treePathEnabled)
			_pos[_orientation] += _deferred_change[_orientation];
	}

	package void checkTraversalCompletion(Order order)()
	{
		static if (order == Order.Sinking)
		{
			bool finished = (_pos[_orientation]+_deferred_change[_orientation] > _destination[_orientation]);
		}
		else
		{
			static assert(order == Order.Bubbling);

			bool finished = (_pos[_orientation] <= _destination[_orientation]);
		}

		if (finished)
		{
			state = State.finishing;
			path = tree_path;
		}
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		import std.conv : to;

		sink(typeof(this).stringof);
		sink("(");

		static foreach(i; 0..typeof(this).tupleof.length)
		{
			sink(this.tupleof[i].stringof[5..$]);
			sink(": ");
			sink(this.tupleof[i].to!string);
			sink(", ");
		}
		sink(")");
	}

	void indent() {}
	void unindent() {}
	bool complete() @safe @nogc { return false; }
	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model) {}

	void enterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		static if (is(typeof(model.orientation))) _orientation = model.orientation;
	}

	// DerivedVisitor is "ansector" of this struct. Because the method is a template one and can not be virtual
	// (so no polyphormism at all) the actual type of "ansector" is passed directly
	// IOW when SomeVisitor calls doEnterNode inside this method the type of `this` is always DefaultVisitorImpl so
	// the type of SomeVisitor should be passed directly to call the proper version of the enterNode method
	bool doEnterNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled)
	{
		import std.algorithm : among;

		if (derivedVisitor.complete)
			return true;

		static if (sizeCalculationEnabled) model.sizeYM = model.headerSizeY = size[model.orientation] + model.Spacing;

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

		if (!state.among(State.first, State.rest))
			return false;


		if (model.orientation != derivedVisitor.orientation)
		{
			if (derivedVisitor.orientation == Orientation.Vertical)
			{
				changeOrientation();
			}
		}

		derivedVisitor._orientation = model.orientation;

		static if (order == Order.Sinking) updatePosition(model.headerSizeY);
		checkTraversalCompletion!order();

		derivedVisitor.enterNode!(order, Data)(data, model);

		return false;
	}

	bool doEnterNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (!treePathEnabled)
	{
		if (derivedVisitor.complete)
			return true;

		static if (sizeCalculationEnabled) model.sizeYM = model.headerSizeY = size[model.orientation] + model.Spacing;

		derivedVisitor._orientation = model.orientation;

		derivedVisitor.enterNode!(order, Data)(data, model);

		return false;
	}

	void doLeaveNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled)
	{
		import std.algorithm : among;

		if (!state.among(State.first, State.rest))
			return;

			if (derivedVisitor.orientation == Orientation.Horizontal)
			{
				popRecord;
			}

		static if (order == Order.Bubbling) updatePosition(-model.headerSizeY);
		checkTraversalCompletion!order();

		derivedVisitor.leaveNode!order(data, model);
	}

	void doLeaveNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (!treePathEnabled)
	{
		derivedVisitor.leaveNode!order(data, model);
	}
}

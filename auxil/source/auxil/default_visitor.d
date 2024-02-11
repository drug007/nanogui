module auxil.default_visitor;

import std.typecons : Flag;

version(unittest) import unit_threaded : Name;

import auxil.common : Order, SizeType, Orientation;

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

	static if (sizeEnabled && treePathEnabled)
	{
		// Выравнивание в зависимости от ориентации
		void indent(SizeType size)
		{
			import auxil.common : nextAxisIndex;

			_pos[_orientation.nextAxisIndex] += size;
			if (_orientation == Orientation.Vertical)
				_size[_orientation] -= size;
		}
	}

	static if (treePathEnabled)
	{
		import auxil.tree_path : TreePath;

		enum State { seeking, first, rest, finishing, }
		State state;
		TreePath tree_path, path;
		private SizeType[2] _pos, _deferred_change, _destination;

		SizeType posX() const { return _pos[Orientation.Horizontal]; }
		SizeType posX(SizeType value) { _pos[Orientation.Horizontal] = value; return value; }
		SizeType posY() const { return _pos[Orientation.Vertical]; }
		SizeType posY(SizeType value) { _pos[Orientation.Vertical] = value; return value; }

		SizeType destY() const { return _destination[Orientation.Vertical]; }
		SizeType destY(SizeType value) { _destination[Orientation.Vertical] = value; return value; }

		void clear()
		{
			_deferred_change = 0;
		}
	}

	package void updatePositionSinking(Order order, Change)(Change change)
	{
		static if (order == Order.Sinking)
		{
			_pos[_orientation] += _deferred_change[_orientation];
			_deferred_change[_orientation] = change;
		}
	}

	package void updatePositionBubbling(Order order, Change)(Change change)
	{
		static if (order == Order.Bubbling)
		{
			_pos[_orientation] += _deferred_change[_orientation];
			_deferred_change[_orientation] = change;
		}
	}

	package void checkTraversalCompletionSinking(Order order)()
	{
		static if (order == Order.Sinking)
		{
			if (_pos[_orientation]+_deferred_change[_orientation] > _destination[_orientation])
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
			if (_pos[_orientation] <= _destination[_orientation])
			{
				state = State.finishing;
				path = tree_path;
			}
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
		{
			return true;
		}

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

		derivedVisitor._orientation = model.orientation;

		if (state.among(State.first, State.rest))
		{
			updatePositionSinking!order(model.headerSizeY);
			derivedVisitor.enterNode!(order, Data)(data, model);
			checkTraversalCompletionSinking!order();
		}

		return false;
	}

	bool doEnterNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (!treePathEnabled)
	{
		if (derivedVisitor.complete)
		{
			return true;
		}

		static if (sizeCalculationEnabled) model.sizeYM = model.headerSizeY = size[model.orientation] + model.Spacing;

		derivedVisitor.enterNode!(order, Data)(data, model);

		return false;
	}

	void doLeaveNode(Order order, Data, Model, DerivedVisitor)(ref const(Data) data, ref Model model, ref DerivedVisitor derivedVisitor)
		if (treePathEnabled)
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
		if (!treePathEnabled)
	{
		derivedVisitor.leaveNode!order(data, model);
	}
}

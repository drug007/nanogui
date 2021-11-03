module auxil.default_visitor;

import std.typecons : Flag;

import auxil.location : Axis, Location, SizeType, Order;
import auxil.model : Orientation;

alias SizeEnabled     = Flag!"SizeEnabled";
alias TreePathEnabled = Flag!"TreePathEnabled";

private struct Default
{
	void enterTree(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void leaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void beforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
	void afterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model) {}
}

alias MeasuringVisitor = MeasuringVisitorImpl!Default;

/// Visitor to measure size of tree nodes
struct MeasuringVisitorImpl(Derived = Default)
{
	SizeType[2] size;

	this(SizeType[2] s) @safe @nogc nothrow
	{
		size = s;
	}

	enum treePathEnabled = TreePathEnabled.no;

	Orientation orientation = Orientation.Vertical;
	Orientation old_orientation;

	bool complete() @safe @nogc
	{
		return false;
	}

	bool engaged() @safe @nogc nothrow
	{
		return true;
	}

	void doEnterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		() @trusted { (cast(Derived*) &this).enterTree!(order, Data, Model)(data, model); }();
	}

	void doEnterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (Model.Collapsable)
		{
			model.size = size[model.orientation] + model.Spacing;
			final switch (model.orientation)
			{
				case Orientation.Vertical:
					model.header_size = model.size;
				break;
				case Orientation.Horizontal:
					model.header_size = size[Orientation.Vertical] + model.Spacing;
				break;
			}
			old_orientation = orientation;
			orientation  = model.orientation;
		}
		else
			model.size = size[orientation] + model.Spacing;

		final switch (orientation)
		{
			// shrink size of the window
			case Orientation.Vertical:
				size[Orientation.Horizontal] -= size[Orientation.Vertical] + model.Spacing;
			break;
			case Orientation.Horizontal:
				// do nothing
			break;
		}

		if (engaged)
		{
			() @trusted { (cast(Derived*) &this).enterNode!(order, Data, Model)(data, model); }();
		}
	}

	void doLeaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		if (engaged)
		{
			() @trusted { (cast(Derived*) &this).leaveNode!(order, Data, Model)(data, model); }();
		}

		final switch (this.orientation)
		{
			// restore shrinked size of the window
			case Orientation.Vertical:
				size[Orientation.Horizontal] += size[Orientation.Vertical] + model.Spacing;
			break;
			case Orientation.Horizontal:
				// do nothing again
			break;
		}

		static if (Model.Collapsable)
			orientation = old_orientation;
	}

	/// returns true if the current children shouldn't be processed
	/// but traversing should be continued
	bool doBeforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		if (orientation == Orientation.Horizontal)
		{
			size[orientation] -= size[Orientation.Vertical] + model.Spacing;
		}

		() @trusted { (cast(Derived*) &this).beforeChildren!(order, Data, Model)(data, model); }();

		return false;
	}

	void doAfterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		() @trusted { (cast(Derived*) &this).afterChildren!(order, Data, Model)(data, model); }();

		if (orientation == Orientation.Horizontal)
		{
			size[orientation] += size[Orientation.Vertical] + model.Spacing;
		}
	}

	auto startValue(Order order)(size_t len)
	{
		return 0;
	}

	auto setPath(int i)
	{
	}

	auto setChildSize(Model, ChildModel)(ref Model model, ref ChildModel child_model, int len, ref float residual)
	{
		final switch(model.orientation)
		{
			case Orientation.Horizontal:
				double sf = cast(double)(model.size)/len;
				SizeType sz = cast(SizeType)sf;
				residual += sf - sz;
				if (residual >= 1.0)
				{
					residual -= 1;
					sz += 1;
				}
				child_model.size = sz;
			break;
			case Orientation.Vertical:
				model.size += modelSize(child_model, orientation);
			break;
		}
	}

	private auto modelSize(Model)(ref const(Model) model, Orientation orientation)
	{
		static if (Model.Collapsable)
		{
			// if modelSizeIsValid is true the model size is defined by the model
			// in other case it is defined by the visitor
			static if (Model.DynamicCollapsable)
				bool modelSizeIsValid = model.rtCollapsable;
			else
				bool modelSizeIsValid = true;

			if (modelSizeIsValid && orientation == model.orientation)
				return model.size;
		}
		return size[orientation] + model.Spacing;
	}
}

struct State
{
	Axis x, y;
	Orientation orientation;
}

struct StateStack
{
	import automem : Vector;
	import std.experimental.allocator.mallocator : Mallocator;

	Vector!(State, Mallocator) stack;

	auto put(State s) @trusted @nogc
	{
		import std.algorithm : move;
		stack.put(move(s));
	}

	ref back() @nogc return
	{
		return stack[$-1];
	}

	void popBack() @nogc @trusted
	{
		assert(!stack.empty);
		stack.popBack;
	}
}

/// Visitor for traversing tree to do useful job
struct TreePathVisitorImpl(Derived = Default)
{
	SizeType[2] size;

	@disable this(this);

	this(SizeType[2] s) @safe @nogc nothrow
	{
		size = s;
	}

	enum treePathEnabled = TreePathEnabled.yes;

	Location loc;
	Orientation orientation = Orientation.Vertical;
	StateStack stateStack;

	bool complete() @safe @nogc
	{
		return loc.checkState;
	}

	bool engaged() @safe @nogc nothrow
	{
		return loc.stateFirstOrRest;
	}

	void doEnterTree(Order order, Data, Model)(auto ref const(Data) data, ref Model model)
	{
		final switch (this.orientation)
		{
			case Orientation.Vertical:
				loc.x.size = size[Orientation.Horizontal] + model.Spacing;
				static if (Model.Collapsable)
					loc.y.size = model.header_size;
				else
					loc.y.size = model.size;
			break;
			case Orientation.Horizontal:
				assert(0, "Not implemented");
		}

		() @trusted { (cast(Derived*) &this).enterTree!(order, Data, Model)(data, model); }();
	}

	void doEnterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		if (!engaged) 
		{
			static if (Model.Collapsable) 
				stateStack.put(State(loc.x, loc.y, orientation));
			return;
		}

		static if (order == Order.Sinking) with(loc)
		{
			final switch(orientation)
			{
				case Orientation.Vertical:
					y.position = y.position + y.change;
					static if (Model.Collapsable)
						y.change = model.header_size;
					else
						y.change = model.size;
				break;
				case Orientation.Horizontal:
					x.position = x.position + x.change;
					static if (Model.Collapsable)
						x.change = model.header_size;
					else
						x.change = model.size;
				break;
			}

			scope(exit)
			{
				final switch(orientation)
				{
					case Orientation.Vertical:
						if (y.position + y.change > y.destination)
						{
							path = current_path;
							_state = State.finishing;
						}
					break;
					case Orientation.Horizontal:
						version(none) if (x.position + x.change > x.destination)
						{
							path = current_path;
							_state = State.finishing;
						}
					break;
				}
			}
		}

		static if (Model.Collapsable)
		{
			stateStack.put(State(loc.x, loc.y, orientation));

			orientation  = model.orientation;
		}
		else // static if (!Model.Collapsable)
		{
			final switch (orientation)
			{
				case Orientation.Vertical:
				break;
				case Orientation.Horizontal:
					loc.x.size = model.size;
				break;
			}
			scope(exit)
			{
				final switch (this.orientation)
				{
					case Orientation.Vertical:
					break;
					case Orientation.Horizontal:
						loc.x.position += model.size;
					break;
				}
			}
		}

		() @trusted { (cast(Derived*) &this).enterNode!(order, Data, Model)(data, model); }();
	}

	void doLeaveNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		static if (Model.Collapsable)
		{
			orientation = stateStack.back.orientation;

			if (orientation == Orientation.Vertical)
				loc.x = stateStack.back.x;
			if (orientation == Orientation.Horizontal)
				loc.y = stateStack.back.y;
			stateStack.popBack;
		}

		if (engaged)
		{
			static if (order == Order.Bubbling) with(loc)
			{
				final switch(orientation)
				{
					case Orientation.Vertical:
						y.position = y.position + y.change;
						static if (Model.Collapsable)
							y.change = -model.header_size;
						else
							y.change = -model.size;

						if (y.position <= y.destination)
						{
							_state = State.finishing;
							path = current_path;
						}
					break;
					case Orientation.Horizontal:
						x.position = x.position + x.change;
						static if (Model.Collapsable)
							x.change = -model.header_size;
						else
							x.change = -model.size;

						version(none) if (x.position <= x.destination)
						{
							_state = State.finishing;
							path = current_path;
						}
					break;
				}
			}

			static if (!Model.Collapsable)
			{
				final switch (orientation)
				{
					case Orientation.Vertical:
					break;
					case Orientation.Horizontal:
						loc.x.size = model.size;
					break;
				}
			}

			() @trusted { (cast(Derived*) &this).leaveNode!(order, Data, Model)(data, model); }();
		}
	}

	/// returns true if the current children shouldn't be processed
	/// but traversing should be continued
	bool doBeforeChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
		if (Model.Collapsable)
	{
		// set proper current size for children
		if (model.orientation == Orientation.Vertical)
		{
			loc.y.size = loc.y.change;
		}
		else
		{
			loc.x.size = loc.y.change;
		}

		() @trusted { (cast(Derived*) &this).beforeChildren!(order, Data, Model)(data, model); }();

		static if (order == Order.Bubbling)
		{
			// Edge case if the start path starts from this collapsable exactly
			// then the childs of the collapsable aren't processed
			if (loc.path.value.length && loc.current_path.value[] == loc.path.value[])
				return true;
		}

		loc.indent;

		with(loc) final switch (model.orientation)
		{
			case Orientation.Vertical:
				x.position = x.position + model.header_size;
				x.size = x.size - model.header_size;
			break;
			case Orientation.Horizontal:
			break;
		}

		return false;
	}

	void doAfterChildren(Order order, Data, Model)(ref const(Data) data, ref Model model)
		if (Model.Collapsable)
	{
		loc.unindent;

		with(loc) final switch (model.orientation)
		{
			case Orientation.Vertical:
				x.position = x.position - model.header_size;
				x.size = x.size + model.header_size;
			break;
			case Orientation.Horizontal:
			break;
		}

		() @trusted { (cast(Derived*) &this).afterChildren!(order, Data, Model)(data, model); }();
	}

	auto startValue(Order order)(size_t len)
	{
		return loc.startValue!order(len);
	}

	auto setPath(int i)
	{
		loc.setPath(i);
	}

	auto setChildSize(Model, ChildModel)(ref Model model, ref ChildModel child_model, int len, ref float residual)
	{
	}
}

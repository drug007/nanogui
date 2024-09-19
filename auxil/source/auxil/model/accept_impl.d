module auxil.model.accept_impl;

mixin template acceptImpl()
{
	bool accept(Order order, Visitor)(ref const(Data) data, ref Visitor visitor)
		if (Data.sizeof > 24)
	{
		return baseAccept!order(data, visitor);
	}

	bool accept(Order order, Visitor)(const(Data) data, ref Visitor visitor)
		if (Data.sizeof <= 24)
	{
		return baseAccept!order(data, visitor);
	}

	bool baseAccept(Order order, Visitor)(auto ref const(Data) data, ref Visitor visitor)
	{
		static if (Data.sizeof > 24 && !__traits(isRef, data))
			pragma(msg, "Warning: ", Data, " is a value type and has size larger than 24 bytes");

		// static assert(Data.sizeof <= 24 || __traits(isRef, data));

		enum Sinking = order == Order.Sinking;

		static if (Collapsable)
		{
			// If the range is empty then it is not processed
			// TODO: should be a tunable parameter per a node(!)
			if (0 == length)
				return false;
		}

		static if (is(typeof(data.skipThis)))
		{
			if (data.skipThis)
				return false;
		}

		if (visitor.doEnterNode!(order, Data)(data, this, visitor))
			return true;

		scope(exit)
		{
			visitor.doLeaveNode!(order, Data)(data, this, visitor);
		}

		static if (Collapsable) if (!this.collapsed)
		{
			visitor.indent;
			scope(exit) visitor.unindent;

			// data length should be equal to model length
			assert(getLength!(Data, data) == length);

			if (!visitor.doBeforeChildren!(order, Data)(data, this, visitor))
				return false;
			scope(exit) visitor.doAfterChildren!(order, Data)(data, this, visitor);

			// Number of first child to visit
			// set by visitor
			// depends on order, children count and current tree path value
			size_t start_value = visitor.getStartValue!order(this);

			static if (dataHasStaticArrayModel!Data || 
			           dataHasRandomAccessRangeModel!Data ||
			           dataHasAssociativeArrayModel!Data)
			{
                import auxil.two_faced_range : TwoFacedRange;

				foreach(i; TwoFacedRange!order(start_value, data.length))
				{
					static if (is(typeof(visitor.pushRecord)))
						visitor.pushRecord;
					visitor.setTreePath(cast(int) i);
					scope(exit)
					{
						visitor.doAfterChildVisiting(this, model[i], visitor);
						static if (is(typeof(visitor.popRecord)))
							visitor.popRecord;
					}
					auto idx = getIndex!(Data)(this, i);
					if (model[i].accept!order(data[idx], visitor))
					{
						return true;
					}
				}
			}
			else static if (dataHasAggregateModel!Data)
			{
				// work around ldc2 issue
				// expression `const len = getLength!(Data, data);` is not a constant
				const len2 = DrawableMembers!Data.length;
				switch(start_value)
				{
					static foreach(i; 0..len2)
					{
						// reverse fields order if Order.Bubbling
						case (Sinking) ? i : len2 - i - 1:
						{
							static if (is(typeof(visitor.pushRecord)))
								visitor.pushRecord;
							enum FieldNo = (Sinking) ? i : len2 - i - 1;
							enum member = DrawableMembers!Data[FieldNo];
							visitor.setTreePath(cast(int) FieldNo);
							scope(exit)
							{
								visitor.doAfterChildVisiting(this, mixin("this." ~ member), visitor);
								static if (is(typeof(visitor.popRecord)))
									visitor.popRecord;
							}
							if (mixin("this." ~ member).accept!order(mixin("data." ~ member), visitor))
							{
								return true;
							}
						}
						goto case;
					}
					// the dummy case needed because every `goto case` should be followed by a case clause
					case len2:
						// flow cannot get here directly
						if (start_value == len2)
							assert(0);
					break;
					default:
						assert(0);
				}
			}
		}

		return false;
	}
}

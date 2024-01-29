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
		import std.algorithm : among;

		enum Sinking     = order == Order.Sinking;
		enum Bubbling    = !Sinking; 
		enum hasTreePath = Visitor.treePathEnabled;
		enum hasSize     = Visitor.sizeEnabled;

		if (visitor.doEnterNode!(order, Data)(data, this, visitor))
			return true;

		scope(exit)
		{
			visitor.doLeaveNode!(order, Data)(data, this, visitor);
		}

		if (!this.collapsed)
		{
			visitor.indent;
			scope(exit) visitor.unindent;

			static if (Bubbling && hasTreePath)
			{
				// Edge case if the start path starts from this collapsable exactly
				// then the childs of the collapsable aren't processed
				if (visitor.path.value.length && visitor.tree_path.value[] == visitor.path.value[])
				{
					return false;
				}
			}

			auto len = getLength!(Data, data);
			static if (is(typeof(model.length)))
				assert(len == model.length);
			if (!len)
				return false;

			static if (hasTreePath) visitor.tree_path.put(0);
			static if (hasTreePath) scope(exit) visitor.tree_path.popBack;

			size_t start_value;
			static if (Bubbling)
			{
				start_value = len;
				start_value--;
			}
			static if (hasTreePath)
			{
				if (visitor.state.among(visitor.State.seeking, visitor.State.first))
				{
					auto idx = visitor.tree_path.value.length;
					if (idx && visitor.path.value.length >= idx)
					{
						start_value = visitor.path.value[idx-1];
						// position should change only if we've got the initial path
						// and don't get the end
						if (visitor.state == visitor.State.seeking) visitor.deferred_change = 0;
					}
				}
			}
			static if (dataHasStaticArrayModel!Data || 
			           dataHasRandomAccessRangeModel!Data ||
			           dataHasAssociativeArrayModel!Data)
			{
                import auxil.two_faced_range : TwoFacedRange;

				foreach(i; TwoFacedRange!order(start_value, data.length))
				{
					static if (hasTreePath) visitor.tree_path.back = i;
					static if (hasSize) scope(exit) this.size += model[i].size;
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
							enum FieldNo = (Sinking) ? i : len2 - i - 1;
							enum member = DrawableMembers!Data[FieldNo];
							static if (hasTreePath) visitor.tree_path.back = cast(int) FieldNo;
							static if (hasSize) scope(exit) this.size += mixin("this." ~ member).size;
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
		else
		{
		}

		return false;
	}
}

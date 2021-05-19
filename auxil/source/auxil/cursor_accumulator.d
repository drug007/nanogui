module auxil.cursor_accumulator;

import auxil.cursor;

struct CursorAccumulator
{
	alias Type = Cursor.Type;
	Cursor csr;

	auto start(Type v = 0)
	{
		csr.reset;
		// by default scrolling is done for the max possible value
		csr.scroll = Type.max;
		csr.init_value = v;
	}

	auto commit(Cursor.Order order)()
	{
		csr.fixUp;
		csr.init_value = position!order;
		csr.fixedPosition = 0;
	}

	auto begin(Type v)
	{
		return csr.begin(v);
	}

	auto end(Type v)
	{
		return csr.next(v);
	}

	auto position(Cursor.Order order)()
	{
		return csr.calcPosition!order;
	}
}
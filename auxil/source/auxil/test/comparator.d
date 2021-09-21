module auxil.test.comparator;

import auxil.test.node : Node;

/// Defines what predicates are used to check the equality
struct CompareBy
{
	import std.bitmanip : bitfields;

	union
	{
		ubyte allBits = ubyte.max;
		mixin(bitfields!(
			bool, "name",        1,
			bool, "Xpos",        1,
			bool, "Xsize",       1,
			bool, "Ypos",        1,
			bool, "Ysize",       1,
			bool, "children",    1,
			bool, "orientation", 1,
			uint, "", 1,
		));
	}

	void setAll()
	{
		allBits = ubyte.max;
	}

	void clearAll()
	{
		allBits = 0;
	}

	bool none() const
	{
		return allBits == 0;
	}

	auto except(string FieldName)()
	{
		mixin(FieldName, " = false;");
		return this;
	}

	static auto allFields()
	{
		CompareBy compareBy;
		compareBy.setAll;
		return compareBy;
	}
}

struct Record
{
	size_t idx, total;
	Node test, etalon;
}

struct StateStack
{
	import std.exception : enforce;
	import auxil.treepath : TreePath;

	@safe:

	Record[] stack;
	TreePath path;

	this(size_t total, Node test, Node etalon)
	{
		push(total, test, etalon);
	}

	void push(size_t total, Node test, Node etalon)
	{
		stack ~= Record(0, total, test, etalon);
		path.put(cast(int) idx);
	}

	void pop()
	{
		enforce(!empty);
		stack = stack[0..$-1];
		path.popBack;
	}

	auto test()
	{
		enforce(!empty);
		return stack[$-1].test.children[idx];
	}

	auto etalon()
	{
		enforce(!empty);
		return stack[$-1].etalon.children[idx];
	}

	auto idx() const
	{
		enforce(!empty);
		return stack[$-1].idx;
	}

	auto total() const
	{
		enforce(!empty);
		return stack[$-1].total;
	}

	bool empty() const
	{
		return stack.length == 0;
	}

	bool inProgress() const
	{
		enforce(!empty);
		return stack[$-1].idx < stack[$-1].total;
	}

	void nextNode()
	{
		enforce(inProgress);
		stack[$-1].idx++;
		path.back = cast(int) idx;
	}
}

struct Comparator
{
	import auxil.treepath : TreePath;

	TreePath path;
	bool bResult;
	string sResult;

	bool compare(Node lhs, Node rhs, CompareBy compareBy = CompareBy.allFields)
	{
		import std.algorithm : all;
		import std.range : repeat, zip;
		import std.format : format;
		import std.typecons : scoped;
		import std.experimental.logger : logf, LogLevel;

		if (!compareField(lhs, rhs, compareBy))
			return false;

		if (lhs.children.length != rhs.children.length)
		{
			bResult = false;
			sResult = format("Different children count: test (%s, %s) vs etalon (%s, %s)", 
				lhs.name, lhs.children.length, rhs.name, rhs.children.length);
			path.put(0);
			return bResult;
		}

		auto testRoot   = scoped!Node("testRoot",   0, 0, 0, 0);
		auto etalonRoot = scoped!Node("etalonRoot", 0, 0, 0, 0);
		testRoot.children ~= lhs;
		etalonRoot.children ~= rhs;
		auto s = StateStack(1, testRoot, etalonRoot);
		while(s.inProgress)
		{
			logf(LogLevel.trace, true, "%s %s%s", s.path, ' '.repeat(s.stack.length), s.test.name);

			lhs = s.test;
			rhs = s.etalon;

			if (!compareField(lhs, rhs, compareBy))
			{
				import std.algorithm : move;
				path = move(s.path);
				return false;
			}

			if (lhs.children.length)
			{
				s.push(lhs.children.length, lhs, rhs);
				continue;
			}

			s.nextNode;
			while(!s.inProgress && s.stack.length > 1)
			{
				s.pop;
				assert(!s.empty);
				assert(s.inProgress);
				s.nextNode;
			}
		}

		bResult = true;
		return bResult;
	}

	bool compareField(Node lhs, Node rhs, CompareBy compareBy = CompareBy.allFields)
	{
		import std.algorithm : all;
		import std.range : zip;
		import std.format : format;

		if (lhs is null || rhs is null)
		{
			bResult = false;
			sResult = "At least one of instances is null";
			return bResult;
		}

		if (compareBy.none)
		{
			bResult = true;
			sResult = "None of fields is enabled for comparing";
			return bResult;
		}

		if (compareBy.name  && lhs.name != rhs.name)
		{
			bResult = false;
			sResult = format("test   has name: %s\netalon has name: %s", lhs.name, rhs.name);
			return bResult;
		}

		if (compareBy.Xpos  && lhs.x.position != rhs.x.position)
		{
			bResult = false;
			sResult = format("test   has x.position: %s\netalon has x.position: %s", lhs.x.position, rhs.x.position);
			return bResult;
		}

		if (compareBy.Xsize && lhs.x.size != rhs.x.size)
		{
			bResult = false;
			sResult = format("test   has x.size: %s\netalon has x.size: %s", lhs.x.size, rhs.x.size);
			return bResult;
		}

		if (compareBy.Ypos  && lhs.y.position != rhs.y.position)
		{
			bResult = false;
			sResult = format("test   has y.position: %s\netalon has y.position: %s", lhs.y.position, rhs.y.position);
			return bResult;
		}

		if (compareBy.Ysize && lhs.y.size != rhs.y.size)
		{
			bResult = false;
			sResult = format("test   has y.size: %s\netalon has y.size: %s", lhs.y.size, rhs.y.size);
			return bResult;
		}

		if (compareBy.orientation && lhs.orientation != rhs.orientation)
		{
			bResult = false;
			sResult = format("test   has orientation: %s\netalon has orientation: %s", lhs.orientation, rhs.orientation);
			return bResult;
		}

		return true;
	}
}

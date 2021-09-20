module auxil.test.comparator;

import auxil.test.node : Node;

enum CompareBy {
	none        = 0,
	name        = 1,
	Xpos        = 2, 
	Xsize       = 4, 
	Ypos        = 8, 
	Ysize       = 16, 
	children    = 32,
	orientation = 64,
	allFields   = none | name | Xpos | Xsize | Ypos | Ysize | children | orientation,
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

	bool compare(Node lhs, Node rhs, ubyte flags = CompareBy.allFields)
	{
		import std.algorithm : all;
		import std.range : repeat, zip;
		import std.format : format;
		import std.typecons : scoped;
		import std.experimental.logger : logf, LogLevel;

		if (!compareField(lhs, rhs, flags))
			return false;

		if (lhs.children.length != rhs.children.length)
		{
			bResult = false;
			sResult = "Different children count";
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

			if (!compareField(lhs, rhs, flags))
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

		return true;
	}

	bool compareField(Node lhs, Node rhs, ubyte flags = CompareBy.allFields)
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

		if (flags == CompareBy.none)
		{
			bResult = true;
			sResult = "None of fields enabled for comparing";
			return bResult;
		}

		if ((flags & CompareBy.name)  && lhs.name != rhs.name)
		{
			bResult = false;
			sResult = format("test   has name: %s\netalon has name: %s", lhs.name, rhs.name);
			return bResult;
		}

		if ((flags & CompareBy.Xpos)  && lhs.x.position != rhs.x.position)
		{
			bResult = false;
			sResult = format("test   has x.position: %s\netalon has x.position: %s", lhs.x.position, rhs.x.position);
			return bResult;
		}

		if ((flags & CompareBy.Xsize) && lhs.x.size != rhs.x.size)
		{
			bResult = false;
			sResult = format("test   has x.size: %s\netalon has x.size: %s", lhs.x.size, rhs.x.size);
			return bResult;
		}

		if ((flags & CompareBy.Ypos)  && lhs.y.position != rhs.y.position)
		{
			bResult = false;
			sResult = format("test   has y.position: %s\netalon has y.position: %s", lhs.y.position, rhs.y.position);
			return bResult;
		}

		if ((flags & CompareBy.Ysize) && lhs.y.size != rhs.y.size)
		{
			bResult = false;
			sResult = format("test   has y.size: %s\netalon has y.size: %s", lhs.y.size, rhs.y.size);
			return bResult;
		}

		if ((flags & CompareBy.orientation) && lhs.orientation != rhs.orientation)
		{
			bResult = false;
			sResult = format("test   has orientation: %s\netalon has orientation: %s", lhs.orientation, rhs.orientation);
			return bResult;
		}

		return true;
	}
}

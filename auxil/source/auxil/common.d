module auxil.common;

enum Order { Sinking, Bubbling, }

/// Type used to represent the size of items in every dimension
alias SizeType = double;

enum Orientation { Horizontal, Vertical }

auto axisIndex(Orientation o)
{
	return (o == Orientation.Vertical) ? 1 : 0;
}

auto nextAxisIndex(Orientation o)
{
	return (o == Orientation.Vertical) ? 0 : 1;
}

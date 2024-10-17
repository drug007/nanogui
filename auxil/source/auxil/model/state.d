module auxil.model.state;

mixin template State()
{
    import auxil.common : SizeType, Orientation;

	SizeType sizeYM = 0, headerSizeY = 0;
	int _placeholder = 1 << Field.Collapsed | 
	                   1 << Field.Enabled;

	private enum Field { Collapsed, Enabled, Orientation}

    @property typeof(sizeYM) size() const { return sizeYM; }
    @property typeof(headerSizeY) header_size() const { return headerSizeY; }

	@property void collapsed(bool v)
	{
		if (collapsed != v)
		{
			if (v)
				_placeholder |=   1 << Field.Collapsed;
			else
				_placeholder &= ~(1 << Field.Collapsed);
		}
	}
	@property bool collapsed() const { return (_placeholder & (1 << Field.Collapsed)) != 0; }

	@property void enabled(bool v)
	{
		if (enabled != v)
		{
			if (v)
				_placeholder |=   1 << Field.Enabled;
			else
				_placeholder &= ~(1 << Field.Enabled);
		}
	}
	@property bool enabled() const { return (_placeholder & (1 << Field.Enabled)) != 0; }

	@property void orientation(Orientation v)
	{
		if (orientation != v)
		{
			if (v == Orientation.Horizontal)
				_placeholder |=   1 << Field.Orientation;
			else
				_placeholder &= ~(1 << Field.Orientation);
		}
	}
	@property Orientation orientation() const
    {
        return (_placeholder & (1 << Field.Orientation)) ? Orientation.Horizontal : Orientation.Vertical;
    }
}

mixin template StateScalar()
{
    import auxil.common : SizeType, Orientation;

	SizeType sizeYM = 0;
	alias headerSizeY = sizeYM;

	int _placeholder = 0 << Field.Orientation;

	private enum Field { Collapsed, Enabled, Orientation}

    @property typeof(sizeYM) size() const { return sizeYM; }
    @property typeof(headerSizeY) header_size() const { return headerSizeY; }

	@property void collapsed(bool v)
	{
		// do nothing
	}

	@property bool collapsed() const
	{
		return true;
	}

	@property void enabled(bool v)
	{
		// do nothing
	}

	@property bool enabled() const
	{
		return true;
	}

	@property void orientation(Orientation v)
	{
		if (orientation != v)
		{
			if (v == Orientation.Horizontal)
				_placeholder |=   1 << Field.Orientation;
			else
				_placeholder &= ~(1 << Field.Orientation);
		}
	}
	@property Orientation orientation() const
    {
        return (_placeholder & (1 << Field.Orientation)) ? Orientation.Horizontal : Orientation.Vertical;
    }
}

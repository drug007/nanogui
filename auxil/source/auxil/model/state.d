module auxil.model.state;

mixin template State()
{
	enum Spacing = 1;
	double size = 0, headerSizeY = 0;
	int _placeholder = 1 << Field.Collapsed | 
	                   1 << Field.Enabled;

	private enum Field { Collapsed, Enabled, }

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
}

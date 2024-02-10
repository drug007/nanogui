module nanogui.experimental.details.list_visitors;

// This visitor renders the current visible elements
struct RenderingVisitor
{
	import nanogui.experimental.utils : drawItem, indent, unindent, TreePath, DefaultVisitorImpl;
    import nanogui.common : Color, NanoContext, boxGradient, fillColor;
    import nanogui.layout : Orientation;
	import auxil.model;
	import auxil.common : Order, SizeType;
	import auxil.default_visitor : DefaultRenderingVisitor;

    import arsd.nanovega;

	private NanoContext* _ctxPtr;
	DefaultRenderingVisitor default_visitor;
	alias default_visitor this;
	// Координата начала текущего окна вывода виджета плюс (отрицательная )
	// поправка на невидимую часть первого видимого элемента
	private SizeType _adjustmentY;

	private TreePath _selected_item;

    this(ref NanoContext ctx, Orientation o, ref TreePath path, SizeType py, SizeType adjustment, SizeType sizeX)
    {
        _ctxPtr = &ctx;
        ctx.orientation = o;
		// Так как ориентация вертикальная, то размер по У должен быть уже рассчитан при вызове
		// MeasuringVisitor и хранится в model. Поэтому размер по У не используется и задается
		// только размер по Х
		default_visitor = DefaultRenderingVisitor(sizeX, 0);
        default_visitor.path = path;
		default_visitor.posX = 0;
        default_visitor.posY = py;
		_adjustmentY = adjustment - py;

		assert(adjustment <= 0);
    }

    auto selectedItem()
    {
        return _selected_item;
    }

    private ref ctx()
    {
        return *_ctxPtr;
    }

	void indent()
	{
		default_visitor.indent(20);
	}

	void unindent()
	{
		default_visitor.indent(-20);
	}

	void enterNode(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		ctx.save;
		scope(exit) ctx.restore;

		ctx.position.x = posX;
		ctx.position.y = posY + _adjustmentY;
		ctx.size.x = sizeX;
		ctx.size.y = model.header_size;
		import std.math : isFinite;
		assert(isFinite(ctx.size.x));
		assert(isFinite(ctx.size.y));

		version(none)
		{
			ctx.strokeWidth(1.0f);
			ctx.beginPath;
			ctx.rect(ctx.position.x + 1.0f, ctx.position.y + 1.0f, ctx.size.x - 2, model.size-2);
			ctx.strokeColor(Color(255, 0, 0, 255));
			ctx.stroke;
		}

		{
			// background for icon
			NVGPaint bg = ctx.boxGradient(
				ctx.position.x + 1.5f, ctx.position.y + 1.5f,
				ctx.size[ctx.orientation] - 2.0f, ctx.size[ctx.orientation] - 2.0f, 3, 3,
				true/*pushed*/ ? Color(0, 0, 0, 100) : Color(0, 0, 0, 32),
				Color(0, 0, 0, 180)
			);

			ctx.beginPath;
			ctx.roundedRect(ctx.position.x + 1.0f, ctx.position.y + 1.0f,
				ctx.size[ctx.orientation] - 2.0f, ctx.size[ctx.orientation] - 2.0f, 3);
			ctx.fillPaint(bg);
			ctx.fill;
		}

		{
			// icon
			ctx.fontSize(ctx.size.y);
			ctx.fontFace("icons");
			ctx.fillColor(model.enabled ? ctx.theme.mIconColor
			                            : ctx.theme.mDisabledTextColor);
			NVGTextAlign algn;
			algn.center = true;
			algn.middle = true;
			ctx.textAlign(algn);

			import nanogui.entypo : Entypo;
			dchar[1] symb;
			symb[0] = model.collapsed ? Entypo.ICON_CHEVRON_RIGHT :
			                            Entypo.ICON_CHEVRON_DOWN;
			if (drawItem(ctx, ctx.size[ctx.orientation], symb[]))
				_selected_item = tree_path;
		}

		{
			// Caption
			const shift = 1.6f * ctx.size.y;
			ctx.position.x += shift;
			ctx.size.x -= shift;
			scope(exit)
			{
				ctx.position.x -= shift;
				ctx.size.x += shift;
			}
			ctx.fontSize(ctx.size.y);
			ctx.fontFace("sans");
			ctx.fillColor(model.enabled ? ctx.theme.mTextColor : ctx.theme.mDisabledTextColor);

			import nanogui.experimental.utils : hasRenderHeader;
			static if (hasRenderHeader!data)
			{
				import auxil.model : FixedAppender;
				FixedAppender!512 app;
				data.renderHeader(app);
				auto header = app[];
			}
			else
				auto header = Data.stringof;

			if (drawItem(ctx, model.header_size, header))
				_selected_item = tree_path;
		}
	}

	void processLeaf(Order order, Data, Model)(ref const(Data) data, ref Model model)
	{
		ctx.save;
		scope(exit) ctx.restore;

		ctx.position.x = posX;
		ctx.position.y = posY + _adjustmentY;
		ctx.size.x = sizeX;
		ctx.size.y = model.size;
		import std.math : isFinite;
		assert(isFinite(ctx.size.x));
		assert(isFinite(ctx.size.y));

		version(none)
		{
			ctx.strokeWidth(1.0f);
			ctx.beginPath;
			ctx.rect(ctx.position.x + 1.0f, ctx.position.y + 1.0f, ctx.size.x - 2, model.size - 2);
			ctx.strokeColor(Color(255, 0, 0, 255));
			ctx.stroke;
		}

		ctx.fontSize(ctx.size.y);
		ctx.fontFace("sans");
		ctx.fillColor(ctx.theme.mTextColor);
		if (drawItem(ctx, model.size, data))
			_selected_item = tree_path;
	}
}

// This visitor updates the current path to the first visible element
struct RelativeMeasurer
{
	import nanogui.experimental.utils : drawItem, indent, unindent, TreePath, DefaultVisitorImpl;
	import auxil.model;
	import auxil.default_visitor : TreePathVisitor;

	TreePathVisitor default_visitor;
	alias default_visitor this;
}

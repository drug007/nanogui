///
module nanogui.layout;

import std.container.array : Array;
import std.algorithm : max;

import nanogui.window : Window;
import nanogui.common;
import nanogui.widget;

/*
	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/
/**
 * A collection of useful layout managers.  The \ref nanogui.GridLayout
 *        was contributed by Christian Schueller.
 */

/// The different kinds of alignments a layout can perform.
enum Alignment : ubyte
{
	Minimum = 0, /// Take only as much space as is required.
	Middle,      /// Center align.
	Maximum,     /// Take as much space as is allowed.
	Fill         /// Fill according to preferred sizes.
}

/// The direction of data flow for a layout.
enum Orientation
{
	Horizontal = 0, /// Layout expands on horizontal axis.
	Vertical        /// Layout expands on vertical axis.
}

/**
 * interface Layout
 *
 * Basic interface of a layout engine.
 */
interface Layout
{
public:
	/**
	 * Performs any and all resizing applicable.
	 *
	 * Params:
	 *     nvg    = The `NanoVG` context being used for drawing.
	 *     widget = The Widget this layout is controlling sizing for.
	 */
	void performLayout(NVGContext nvg, Widget widget) const;

	/**
	 * The preferred size for this layout.
	 *
	 * Params:
	 *     nvg    = The `NanoVG` context being used for drawing.
	 *     widget = The Widget this layout's preferred size is considering.
	 *
	 * Returns:
	 *     The preferred size, accounting for things such as spacing, padding
	 *     for icons, etc.
	 */
	Vector2i preferredSize(NVGContext nvg, const Widget widget, const Widget skipped = null) const;
}

/**
 * Simple horizontal/vertical box layout
 *
 * This widget stacks up a bunch of widgets horizontally or vertically. It adds
 * margins around the entire container and a custom spacing between adjacent
 * widgets.
 */
class BoxLayout : Layout
{
public:
	/**
	 * Construct a box layout which packs widgets in the given `Orientation`
	 *
	 * Params:
	 *     orientation = The Orientation this BoxLayout expands along
	 *     alignment   = Widget alignment perpendicular to the chosen orientation
	 *     margin      = Margin around the layout container
	 *     spacing     = Extra spacing placed between widgets
	 */
	this(Orientation orientation, Alignment alignment = Alignment.Middle,
			  int margin = 0, int spacing = 0)
	{
		mOrientation = orientation;
		mAlignment   = alignment;
		mMargin      = margin;
		mSpacing     = spacing;
	}

	/// The Orientation this BoxLayout is using.
	final Orientation orientation() const { return mOrientation; }

	/// Sets the Orientation of this BoxLayout.
	final void setOrientation(Orientation orientation) { mOrientation = orientation; }

	/// The Alignment of this BoxLayout.
	final Alignment alignment() const { return mAlignment; }

	/// Sets the Alignment of this BoxLayout.
	final void setAlignment(Alignment alignment) { mAlignment = alignment; }

	/// The margin of this BoxLayout.
	final int margin() const { return mMargin; }

	/// Sets the margin of this BoxLayout.
	final void setMargin(int margin) { mMargin = margin; }

	/// The spacing this BoxLayout is using to pad in between widgets.
	final int spacing() const { return mSpacing; }

	/// Sets the spacing of this BoxLayout.
	final void setSpacing(int spacing) { mSpacing = spacing; }

	/// Implementation of the layout interface
	/// See `Layout.preferredSize`.
	override Vector2i preferredSize(NVGContext nvg, const Widget widget, const Widget skipped = null) const
	{
		Vector2i size = Vector2i(2*mMargin, 2*mMargin);

		int yOffset = 0;
		auto window = cast(Window) widget;
		if (window && window.title().length) {
			if (mOrientation == Orientation.Vertical)
				size[1] += widget.theme.mWindowHeaderHeight - mMargin/2;
			else
				yOffset = widget.theme.mWindowHeaderHeight;
		}

		bool first = true;
		int axis1 = cast(int) mOrientation;
		int axis2 = (cast(int) mOrientation + 1)%2;
		foreach (w; widget.children)
		{
			if (!w.visible || w is skipped)
				continue;
			if (first)
				first = false;
			else
				size[axis1] += mSpacing;

			Vector2i ps = w.preferredSize(nvg);
			Vector2i fs = w.fixedSize();
			auto targetSize = Vector2i(
				fs[0] ? fs[0] : ps[0],
				fs[1] ? fs[1] : ps[1]
			);

			size[axis1] += targetSize[axis1];
			size[axis2] = max(size[axis2], targetSize[axis2] + 2*mMargin);
			first = false;
		}
		return size + Vector2i(0, yOffset);
	}

	/// See `Layout.performLayout`.
	override void performLayout(NVGContext nvg, Widget widget) const
	{
		Vector2i fs_w = widget.fixedSize();
		auto containerSize = Vector2i(
			fs_w[0] ? fs_w[0] : widget.width,
			fs_w[1] ? fs_w[1] : widget.height
		);

		int axis1 = cast(int) mOrientation;
		int axis2 = (cast(int) mOrientation + 1)%2;
		int position = mMargin;
		int yOffset = 0;

		import nanogui.window : Window;
		auto window = cast(const Window)(widget);
		if (window && window.title.length)
		{
			if (mOrientation == Orientation.Vertical)
			{
				position += widget.theme.mWindowHeaderHeight - mMargin/2;
			}
			else
			{
				yOffset = widget.theme.mWindowHeaderHeight;
				containerSize[1] -= yOffset;
			}
		}

		bool first = true;
		foreach(w; widget.children) {
			if (!w.visible)
				continue;
			if (first)
				first = false;
			else
				position += mSpacing;

			Vector2i ps = w.preferredSize(nvg), fs = w.fixedSize();
			auto targetSize = Vector2i(
				fs[0] ? fs[0] : ps[0],
				fs[1] ? fs[1] : ps[1]
			);
			auto pos = Vector2i(0, yOffset);

			pos[axis1] = position;

			final switch (mAlignment)
			{
				case Alignment.Minimum:
					pos[axis2] += mMargin;
					break;
				case Alignment.Middle:
					pos[axis2] += (containerSize[axis2] - targetSize[axis2]) / 2;
					break;
				case Alignment.Maximum:
					pos[axis2] += containerSize[axis2] - targetSize[axis2] - mMargin * 2;
					break;
				case Alignment.Fill:
					pos[axis2] += mMargin;
					targetSize[axis2] = fs[axis2] ? fs[axis2] : (containerSize[axis2] - mMargin * 2);
					break;
			}

			w.position(pos);
			w.size(targetSize);
			w.performLayout(nvg);
			position += targetSize[axis1];
		}
	}

protected:
	/// The Orientation of this BoxLayout.
	Orientation mOrientation;

	/// The Alignment of this BoxLayout.
	Alignment mAlignment;

	/// The margin of this BoxLayout.
	int mMargin;

	/// The spacing between widgets of this BoxLayout.
	int mSpacing;
}

/**
 * Special layout for widgets grouped by labels.
 *
 * This widget resembles a box layout in that it arranges a set of widgets
 * vertically. All widgets are indented on the horizontal axis except for
 * `Label` widgets, which are not indented.
 *
 * This creates a pleasing layout where a number of widgets are grouped
 * under some high-level heading.
 */
class GroupLayout : Layout
{
public:
	/**
	 * Creates a GroupLayout.
	 *
	 * Params:
	 *     margin       = The margin around the widgets added.
	 *     spacing      = The spacing between widgets added.
	 *     groupSpacing = The spacing between groups (groups are defined by each Label added).
	 *     groupIndent  = The amount to indent widgets in a group (underneath a Label).
	 */
	this(int margin = 15, int spacing = 6, int groupSpacing = 14,
				int groupIndent = 20)
	{
		mMargin       = margin;
		mSpacing      = spacing;
		mGroupSpacing = groupSpacing;
		mGroupIndent  = groupIndent;
	}

	/// The margin of this GroupLayout.
	final int margin() const { return mMargin; }

	/// Sets the margin of this GroupLayout.
	final void margin(int margin) { mMargin = margin; }

	/// The spacing between widgets of this GroupLayout.
	final int spacing() const { return mSpacing; }

	/// Sets the spacing between widgets of this GroupLayout.
	final void spacing(int spacing) { mSpacing = spacing; }

	/// The indent of widgets in a group (underneath a Label) of this GroupLayout.
	final int groupIndent() const { return mGroupIndent; }

	/// Sets the indent of widgets in a group (underneath a Label) of this GroupLayout.
	final void groupIndent(int groupIndent) { mGroupIndent = groupIndent; }

	/// The spacing between groups of this GroupLayout.
	final int groupSpacing() const { return mGroupSpacing; }

	/// Sets the spacing between groups of this GroupLayout.
	final void groupSpacing(int groupSpacing) { mGroupSpacing = groupSpacing; }

	/// Implementation of the layout interface
	/// See `Layout.preferredSize`.
	override Vector2i preferredSize(NVGContext nvg, const Widget widget, const Widget skipped = null) const
	{
		int height = mMargin, width = 2*mMargin;

		import nanogui.window : Window;
		auto window = cast(const Window) widget;
		if (window && window.title.length)
			height += widget.theme.mWindowHeaderHeight - mMargin/2;

		bool first = true, indent = false;
		foreach (c; widget.children) {
			if (!c.visible || c is skipped)
				continue;
			import nanogui.label : Label;
			auto label = cast(const Label) c;
			if (!first)
				height += (label is null) ? mSpacing : mGroupSpacing;
			first = false;

			Vector2i ps = c.preferredSize(nvg), fs = c.fixedSize();
			auto targetSize = Vector2i(
				fs[0] ? fs[0] : ps[0],
				fs[1] ? fs[1] : ps[1]
			);

			bool indentCur = indent && label is null;
			height += targetSize.y;

			width = max(width, targetSize.x + 2*mMargin + (indentCur ? mGroupIndent : 0));

			if (label)
				indent = label.caption().length != 0;
		}
		height += mMargin;
		return Vector2i(width, height);
	}

	/// See `Layout.performLayout`.
	override void performLayout(NVGContext nvg, Widget widget) const
	{
		int height = mMargin, availableWidth =
			(widget.fixedWidth() ? widget.fixedWidth() : widget.width()) - 2*mMargin;

		const Window window = cast(const Window) widget;
		if (window && window.title.length)
			height += widget.theme.mWindowHeaderHeight - mMargin/2;

		bool first = true, indent = false;
		foreach (c; widget.children) {
			if (!c.visible)
				continue;
			import nanogui.label : Label;
			const Label label = cast(const Label) c;
			if (!first)
				height += (label is null) ? mSpacing : mGroupSpacing;
			first = false;

			bool indentCur = indent && label is null;
			Vector2i ps = Vector2i(availableWidth - (indentCur ? mGroupIndent : 0),
								   c.preferredSize(nvg).y);
			Vector2i fs = c.fixedSize();

			auto targetSize = Vector2i(
				fs[0] ? fs[0] : ps[0],
				fs[1] ? fs[1] : ps[1]
			);

			c.position = Vector2i(mMargin + (indentCur ? mGroupIndent : 0), height);
			c.size = targetSize;
			c.performLayout(nvg);

			height += targetSize.y;

			if (label)
				indent = label.caption != "";
		}
	}

protected:
	/// The margin of this GroupLayout.
	int mMargin;

	/// The spacing between widgets of this GroupLayout.
	int mSpacing;

	/// The spacing between groups of this GroupLayout.
	int mGroupSpacing;

	/// The indent amount of a group under its defining Label of this GroupLayout.
	int mGroupIndent;
}

/**
 * Grid layout.
 *
 * Widgets are arranged in a grid that has a fixed grid resolution `resolution`
 * along one of the axes. The layout orientation indicates the fixed dimension;
 * widgets are also appended on this axis. The spacing between items can be
 * specified per axis. The horizontal/vertical alignment can be specified per
 * row and column.
 */
class GridLayout : Layout
{
public:
	/**
	 * Create a 2-column grid layout by default.
	 *
	 * Params:
	 *     orientation = The fixed dimension of this GridLayout.
	 *     resolution  = The number of rows or columns in the grid (depending on the Orientation).
	 *     alignment   = How widgets should be aligned within each grid cell.
	 *     margin      = The amount of spacing to add around the border of the grid.
	 *     spacing     = The amount of spacing between widgets added to the grid.
	 */
	this(Orientation orientation = Orientation.Horizontal, int resolution = 2,
			   Alignment alignment = Alignment.Middle,
			   int margin = 0, int spacing = 0)
	{
		mOrientation = orientation;
		mResolution  = resolution;
		mMargin      = margin;
		mSpacing     = Vector2i(spacing);

		mDefaultAlignment[0] = mDefaultAlignment[1] = alignment;
	}

	/// The Orientation of this GridLayout.
	final Orientation orientation() const { return mOrientation; }

	/// Sets the Orientation of this GridLayout.
	final void orientation(Orientation orientation) {
		mOrientation = orientation;
	}

	/// The number of rows or columns (depending on the Orientation) of this GridLayout.
	final int resolution() const { return mResolution; }

	/// Sets the number of rows or columns (depending on the Orientation) of this GridLayout.
	final void resolution(int resolution) { mResolution = resolution; }

	/// The spacing at the specified axis (row or column number, depending on the Orientation).
	final int spacing(int axis) const { return mSpacing[axis]; }

	/// Sets the spacing for a specific axis.
	final void spacing(int axis, int spacing) { mSpacing[axis] = spacing; }

	/// Sets the spacing for all axes.
	final void spacing(int spacing) { mSpacing[0] = mSpacing[1] = spacing; }

	/// The margin around this GridLayout.
	final int margin() const { return mMargin; }

	/// Sets the margin of this GridLayout.
	final void margin(int margin) { mMargin = margin; }

	/**
	 * The Alignment of the specified axis (row or column number, depending on
	 * the Orientation) at the specified index of that row or column.
	 */
	final Alignment alignment(int axis, int item) const
	{
		if (item < cast(int) mAlignment[axis].length)
			return mAlignment[axis][item];
		else
			return mDefaultAlignment[axis];
	}

	/// Sets the Alignment of the columns.
	final void colAlignment(Alignment value) { mDefaultAlignment[0] = value; }

	/// Sets the Alignment of the rows.
	final void rowAlignment(Alignment value) { mDefaultAlignment[1] = value; }

	/// Use this to set variable Alignment for columns.
	final void colAlignment(Array!Alignment value) { mAlignment[0] = value; }

	/// Use this to set variable Alignment for rows.
	final void rowAlignment(Array!Alignment value) { mAlignment[1] = value; }

	/// Implementation of the layout interface
	/// See `Layout.preferredSize`.
	override Vector2i preferredSize(NVGContext nvg, const Widget widget, const Widget skipped = null) const
	{
		/* Compute minimum row / column sizes */
		import std.algorithm : sum;
		Array!(int)[2] grid;
		computeLayout(nvg, widget, grid, skipped);

		auto size = Vector2i(
			2*mMargin + sum(grid[0][])
			 + max(cast(int) grid[0].length - 1, 0) * mSpacing[0],
			2*mMargin + sum(grid[1][])
			 + max(cast(int) grid[1].length - 1, 0) * mSpacing[1]
		);

		const Window window = cast(const Window) widget;
		if (window && window.title.length)
			size[1] += widget.theme.mWindowHeaderHeight - mMargin/2;

		return size;
	}

	/// See `Layout.performLayout`.
	override void performLayout(NVGContext nvg, Widget widget) const
	{
		Vector2i fs_w = widget.fixedSize;
		auto containerSize = Vector2i(
			fs_w[0] ? fs_w[0] : widget.width,
			fs_w[1] ? fs_w[1] : widget.height
		);

		/* Compute minimum row / column sizes */
		Array!(int)[2] grid;
		computeLayout(nvg, widget, grid, null);
		if (grid[1].length == 0)
			return;
		int[2] dim = [ cast(int) grid[0].length, cast(int) grid[1].length ];

		Vector2i extra;
		const Window window = cast(const Window) widget;
		if (window && window.title.length)
			extra[1] += widget.theme.mWindowHeaderHeight - mMargin / 2;

		/* Strech to size provided by \c widget */
		for (int i = 0; i < 2; i++) {
			int gridSize = 2 * mMargin + extra[i];
			foreach (int s; grid[i]) {
				gridSize += s;
				if (i+1 < dim[i])
					gridSize += mSpacing[i];
			}

			if (gridSize < containerSize[i]) {
				/* Re-distribute remaining space evenly */
				int gap = containerSize[i] - gridSize;
				int g = gap / dim[i];
				int rest = gap - g * dim[i];
				for (int j = 0; j < dim[i]; ++j)
					grid[i][j] += g;
				for (int j = 0; rest > 0 && j < dim[i]; --rest, ++j)
					grid[i][j] += 1;
			}
		}

		int axis1 = cast(int) mOrientation, axis2 = (axis1 + 1) % 2;
		Vector2i start = Vector2i(mMargin, mMargin) + extra;

		size_t numChildren = widget.children.length;
		size_t child = 0;

		Vector2i pos = start;
		for (int i2 = 0; i2 < dim[axis2]; i2++) {
			pos[axis1] = start[axis1];
			for (int i1 = 0; i1 < dim[axis1]; i1++) {
				Widget w;
				do {
					if (child >= numChildren)
						return;
					w = widget.children()[child++];
				} while (!w.visible());

				Vector2i ps = w.preferredSize(nvg);
				Vector2i fs = w.fixedSize();
				auto targetSize = Vector2i(
					fs[0] ? fs[0] : ps[0],
					fs[1] ? fs[1] : ps[1]
				);

				auto itemPos = Vector2i(pos);
				for (int j = 0; j < 2; j++) {
					int axis = (axis1 + j) % 2;
					int item = j == 0 ? i1 : i2;
					Alignment algn = alignment(axis, item);

					final switch (algn) {
						case Alignment.Minimum:
							break;
						case Alignment.Middle:
							itemPos[axis] += (grid[axis][item] - targetSize[axis]) / 2;
							break;
						case Alignment.Maximum:
							itemPos[axis] += grid[axis][item] - targetSize[axis];
							break;
						case Alignment.Fill:
							targetSize[axis] = fs[axis] ? fs[axis] : grid[axis][item];
							break;
					}
				}
				w.position(itemPos);
				w.size(targetSize);
				w.performLayout(nvg);
				pos[axis1] += grid[axis1][i1] + mSpacing[axis1];
			}
			pos[axis2] += grid[axis2][i2] + mSpacing[axis2];
		}
	}

protected:
	/// Compute the maximum row and column sizes
	void computeLayout(NVGContext nvg, const Widget widget,
					   ref Array!(int)[2] grid, const Widget skipped) const
	{
		int axis1 = cast(int) mOrientation, axis2 = (axis1 + 1) % 2;
		size_t numChildren = widget.children.length, visibleChildren = 0;
		foreach (w; widget.children)
			visibleChildren += w.visible ? 1 : 0;

		Vector2i dim;
		dim[axis1] = mResolution;
		dim[axis2] = cast(int) ((visibleChildren + mResolution - 1) / mResolution);

		grid[axis1].clear(); grid[axis1].length = dim[axis1]; grid[axis1][] = 0;
		grid[axis2].clear(); grid[axis2].length = dim[axis2]; grid[axis2][] = 0;

		size_t child;
		for (int i2 = 0; i2 < dim[axis2]; i2++) {
			for (int i1 = 0; i1 < dim[axis1]; i1++) {
				import std.typecons : Rebindable;
				Rebindable!(const Widget) w;
				do {
					if (child >= numChildren)
						return;
					w = widget.children[child++];
				} while (!w.visible || w is skipped);

				Vector2i ps = w.preferredSize(nvg);
				Vector2i fs = w.fixedSize();
				auto targetSize = Vector2i(
					fs[0] ? fs[0] : ps[0],
					fs[1] ? fs[1] : ps[1]
				);

				grid[axis1][i1] = max(grid[axis1][i1], targetSize[axis1]);
				grid[axis2][i2] = max(grid[axis2][i2], targetSize[axis2]);
			}
		}
	}

	/// The Orientation defining this GridLayout.
	Orientation mOrientation;

	/// The default Alignment for this GridLayout.
	Alignment[2] mDefaultAlignment;

	/// The actual Alignment being used.
	Array!(Alignment)[2] mAlignment;

	/// The number of rows or columns before starting a new one, depending on the Orientation.
	int mResolution;

	/// The spacing used for each dimension.
	Vector2i mSpacing;

	/// The margin around this GridLayout.
	int mMargin;
}

///**
// * \class AdvancedGridLayout layout.h nanogui/layout.h
// *
// * \brief Advanced Grid layout.
// *
// * The is a fancier grid layout with support for items that span multiple rows
// * or columns, and per-widget alignment flags. Each row and column additionally
// * stores a stretch factor that controls how additional space is redistributed.
// * The downside of this flexibility is that a layout anchor data structure must
// * be provided for each widget.
// *
// * An example:
// *
// * \rst
// * .. code-block. cpp
// *
// *    using AdvancedGridLayout.Anchor;
// *    Label *label = new Label(window, "A label");
// *    // Add a centered label at grid position (1, 5), which spans two horizontal cells
// *    layout.setAnchor(label, Anchor(1, 5, 2, 1, Alignment.Middle, Alignment.Middle));
// *
// * \endrst
// *
// * The grid is initialized with user-specified column and row size vectors
// * (which can be expanded later on if desired). If a size value of zero is
// * specified for a column or row, the size is set to the maximum preferred size
// * of any widgets contained in the same row or column. Any remaining space is
// * redistributed according to the row and column stretch factors.
// *
// * The high level usage somewhat resembles the classic HIG layout:
// *
// * - https://web.archive.org/web/20070813221705/http://www.autel.cz/dmi/tutorial.html
// * - https://github.com/jaapgeurts/higlayout
// */
//class NANOGUI_EXPORT AdvancedGridLayout : public Layout {
//public:
//    /**
//     * \struct Anchor layout.h nanogui/layout.h
//     *
//     * \brief Helper struct to coordinate anchor points for the layout.
//     */
//    struct Anchor {
//        uint8_t pos[2];    ///< The ``(x, y)`` position.
//        uint8_t size[2];   ///< The ``(x, y)`` size.
//        Alignment align[2];///< The ``(x, y)`` Alignment.

//        /// Creates a ``0`` Anchor.
//        Anchor() { }

//        /// Create an Anchor at position ``(x, y)`` with specified Alignment.
//        Anchor(int x, int y, Alignment horiz = Alignment.Fill,
//              Alignment vert = Alignment.Fill) {
//            pos[0] = (uint8_t) x; pos[1] = (uint8_t) y;
//            size[0] = size[1] = 1;
//            align[0] = horiz; align[1] = vert;
//        }

//        /// Create an Anchor at position ``(x, y)`` of size ``(w, h)`` with specified alignments.
//        Anchor(int x, int y, int w, int h,
//              Alignment horiz = Alignment.Fill,
//              Alignment vert = Alignment.Fill) {
//            pos[0] = (uint8_t) x; pos[1] = (uint8_t) y;
//            size[0] = (uint8_t) w; size[1] = (uint8_t) h;
//            align[0] = horiz; align[1] = vert;
//        }

//        /// Allows for printing out Anchor position, size, and alignment.
//        operator std.string() const {
//            char buf[50];
//            NANOGUI_SNPRINTF(buf, 50, "Format[pos=(%i, %i), size=(%i, %i), align=(%i, %i)]",
//                pos[0], pos[1], size[0], size[1], (int) align[0], (int) align[1]);
//            return buf;
//        }
//    };

//    /// Creates an AdvancedGridLayout with specified columns, rows, and margin.
//    AdvancedGridLayout(const std.vector<int> &cols = {}, const std.vector<int> &rows = {}, int margin = 0);

//    /// The margin of this AdvancedGridLayout.
//    int margin() const { return mMargin; }

//    /// Sets the margin of this AdvancedGridLayout.
//    void setMargin(int margin) { mMargin = margin; }

//    /// Return the number of cols
//    int colCount() const { return (int) mCols.size(); }

//    /// Return the number of rows
//    int rowCount() const { return (int) mRows.size(); }

//    /// Append a row of the given size (and stretch factor)
//    void appendRow(int size, float stretch = 0.f) { mRows.push_back(size); mRowStretch.push_back(stretch); };

//    /// Append a column of the given size (and stretch factor)
//    void appendCol(int size, float stretch = 0.f) { mCols.push_back(size); mColStretch.push_back(stretch); };

//    /// Set the stretch factor of a given row
//    void setRowStretch(int index, float stretch) { mRowStretch.at(index) = stretch; }

//    /// Set the stretch factor of a given column
//    void setColStretch(int index, float stretch) { mColStretch.at(index) = stretch; }

//    /// Specify the anchor data structure for a given widget
//    void setAnchor(const Widget *widget, const Anchor &anchor) { mAnchor[widget] = anchor; }

//    /// Retrieve the anchor data structure for a given widget
//    Anchor anchor(const Widget *widget) const {
//        auto it = mAnchor.find(widget);
//        if (it == mAnchor.end())
//            throw std.runtime_error("Widget was not registered with the grid layout!");
//        return it.second;
//    }

//    /* Implementation of the layout interface */
//    /// See \ref Layout.preferredSize.
//    virtual Vector2i preferredSize(NVGContext *nvg, const Widget *widget) const override;

//    /// See \ref Layout.performLayout.
//    virtual void performLayout(NVGContext *nvg, Widget *widget) const override;

//protected:
//    /// Computes the layout
//    void computeLayout(NVGContext *nvg, const Widget *widget,
//                       std.vector<int> *grid) const;

//protected:
//    /// The columns of this AdvancedGridLayout.
//    std.vector<int> mCols;

//    /// The rows of this AdvancedGridLayout.
//    std.vector<int> mRows;

//    /// The stretch for each column of this AdvancedGridLayout.
//    std.vector<float> mColStretch;

//    /// The stretch for each row of this AdvancedGridLayout.
//    std.vector<float> mRowStretch;

//    /// The mapping of widgets to their specified anchor points.
//    std.unordered_map<const Widget *, Anchor> mAnchor;

//    /// The margin around this AdvancedGridLayout.
//    int mMargin;
//}

module nanogui.formhelper;
/*
	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/
/**
 * \file nanogui/formhelper.h
 *
 * \brief Helper class to construct forms for editing a set of variables of
 *		  various types.
 */
import std.container : Array;

import nanogui.common;
import nanogui.screen : Screen;
import nanogui.label : Label;
import nanogui.button : Button;
import nanogui.checkbox : CheckBox;
import nanogui.textbox : TextBox, FloatBox, IntBox;
import nanogui.combobox : ComboBox;
import nanogui.layout : AdvancedGridLayout;
import nanogui.window : Window;
import nanogui.widget : Widget;

/**
 * \class FormHelper formhelper.h nanogui/formhelper.h
 *
 * \brief Convenience class to create simple AntTweakBar-style layouts that
 *		  expose variables of various types using NanoGUI widgets
 *
 */
class FormHelper {
public:
	/// Create a helper class to construct NanoGUI widgets on the given screen
	this(Screen screen) { mScreen = screen; }

	/// Add a new top-level window
	Window addWindow(const Vector2i pos,
		const string title = "Untitled")
	 {
		assert(mScreen);
		mWindow = new Window(mScreen, title);
		mLayout = new AdvancedGridLayout([10, 0, 10, 0], []);
		mLayout.margin(10);
		mLayout.setColStretch(2, 1);
		mWindow.position = pos;
		mWindow.layout = mLayout;
		mWindow.visible = true;
		return mWindow;
	}

	/// Add a new group that may contain several sub-widgets
	Label addGroup(string caption)
	{
		Label label = new Label(mWindow, caption, mGroupFontName, mGroupFontSize);
		if (mLayout.rowCount() > 0)
			mLayout.appendRow(mPreGroupSpacing); /* Spacing */
		mLayout.appendRow(0);
		mLayout.setAnchor(label, AdvancedGridLayout.Anchor(0, mLayout.rowCount()-1, 4, 1));
		mLayout.appendRow(mPostGroupSpacing);
		return label;
	}

	auto addVariable(Type)(string label, void delegate(Type) setter,
		const Type delegate() getter, bool editable = true)
	{
		Label labelW = new Label(mWindow, label, mLabelFontName, mLabelFontSize);
		auto widget = new FormWidget!Type(mWindow);
		void delegate() refresh;
		(widget, getter){ refresh = {
				Type value = getter(), current = widget.value;
				if (value != current) widget.value = value;
			};
		}(widget, getter);

		refresh();

		widget.callback = setter;
		widget.editable = editable;
		widget.fontSize = mWidgetFontSize;
		Vector2i fs = widget.fixedSize();
		widget.fixedSize =Vector2i(fs.x != 0 ? fs.x : mFixedSize.x,
			fs.y != 0 ? fs.y : mFixedSize.y);
		mRefreshCallbacks.insertBack(refresh);
		if (mLayout.rowCount() > 0)
			mLayout.appendRow(mVariableSpacing);
		mLayout.appendRow(0);
		mLayout.setAnchor(labelW, AdvancedGridLayout.Anchor(1, mLayout.rowCount()-1));
		mLayout.setAnchor(widget, AdvancedGridLayout.Anchor(3, mLayout.rowCount()-1));
		return cast(FormWidget!Type) widget;
	}

	auto addVariable(Type)(string label, ref Type value, bool editable = true)
	{
		return addVariable!Type(label, (v) { value = v; },
			() { return value; }, editable);
	}

	/// Add a button with a custom callback
	Button addButton(const string label, void delegate() cb)
	{
		Button button = new Button(mWindow, label);
		button.callback = cb;
		button.fixedHeight = 25;
		if (mLayout.rowCount() > 0)
			mLayout.appendRow(mVariableSpacing);
		mLayout.appendRow(0);
		mLayout.setAnchor(button, AdvancedGridLayout.Anchor(1, mLayout.rowCount()-1, 3, 1));
		return button;
	}

	/// Add an arbitrary (optionally labeled) widget to the layout
	void addWidget(const string label, Widget widget)
	{
		mLayout.appendRow(0);
		if (label == "") {
			mLayout.setAnchor(widget, AdvancedGridLayout.Anchor(1, mLayout.rowCount()-1, 3, 1));
		} else {
			Label labelW = new Label(mWindow, label, mLabelFontName, mLabelFontSize);
			mLayout.setAnchor(labelW, AdvancedGridLayout.Anchor(1, mLayout.rowCount()-1));
			mLayout.setAnchor(widget, AdvancedGridLayout.Anchor(3, mLayout.rowCount()-1));
		}
	}

	/// Cause all widgets to re-synchronize with the underlying variable state
	void refresh()
	{
		foreach (const callback; mRefreshCallbacks) {
			callback();
		}
	}

	/// Access the currently active \ref Window instance
	Window window() { return mWindow; }

	/// Set the active \ref Window instance.
	void setWindow(Window window)
	{
		mWindow = window;
		mLayout = cast(AdvancedGridLayout)window.layout;
		if (mLayout is null)
			throw new Exception(
				"Internal error: window has an incompatible layout!");
	}

	/// Specify a fixed size for newly added widgets.
	void setFixedSize(ref const Vector2i fw) { mFixedSize = fw; }

	/// The current fixed size being used for newly added widgets.
	Vector2i fixedSize() { return mFixedSize; }

	/// The font name being used for group headers.
	string groupFontName() const { return mGroupFontName; }

	/// Sets the font name to be used for group headers.
	void setGroupFontName(const string name) { mGroupFontName = name; }

	/// The font name being used for labels.
	string labelFontName() const { return mLabelFontName; }

	/// Sets the font name being used for labels.
	void setLabelFontName(const string name) { mLabelFontName = name; }

	/// The size of the font being used for group headers.
	int groupFontSize() const { return mGroupFontSize; }

	/// Sets the size of the font being used for group headers.
	void setGroupFontSize(int value) { mGroupFontSize = value; }

	/// The size of the font being used for labels.
	int labelFontSize() const { return mLabelFontSize; }

	/// Sets the size of the font being used for labels.
	void setLabelFontSize(int value) { mLabelFontSize = value; }

	/// The size of the font being used for non-group / non-label widgets.
	int widgetFontSize() const { return mWidgetFontSize; }

	/// Sets the size of the font being used for non-group / non-label widgets.
	void setWidgetFontSize(int value) { mWidgetFontSize = value; }

protected:
	/// A reference to the \ref nanogui::Screen this FormHelper is assisting.
	Screen mScreen;

	/// A reference to the \ref nanogui::Window this FormHelper is controlling.
	Window mWindow;

	/// A reference to the \ref nanogui::AdvancedGridLayout this FormHelper is using.
	AdvancedGridLayout mLayout;

	/// The callbacks associated with all widgets this FormHelper is managing.
	Array!(void delegate()) mRefreshCallbacks;

	/// The group header font name.
	string mGroupFontName = "sans-bold";

	/// The label font name.
	string mLabelFontName = "sans";

	/// The fixed size for newly added widgets.
	Vector2i mFixedSize = Vector2i(0, 20);

	/// The font size for group headers.
	int mGroupFontSize = 20;

	/// The font size for labels.
	int mLabelFontSize = 16;

	/// The font size for non-group / non-label widgets.
	int mWidgetFontSize = 16;

	/// The spacing used **before** new groups.
	int mPreGroupSpacing = 15;

	/// The spacing used **after** each group.
	int mPostGroupSpacing = 5;

	/// The spacing between all other widgets.
	int mVariableSpacing = 5;

public:
//	  EIGEN_MAKE_ALIGNED_OPERATOR_NEW
};


/**
 * \class FormWidget formhelper.h nanogui/formhelper.h
 *
 * \brief A template wrapper class for assisting in the creation of various form widgets.
 */
import std.traits : isBoolean, isFloatingPoint, isSomeString, isIntegral;

class FormWidget(T) : CheckBox if(isBoolean!T)
{
	this(Widget p) { super(p, "", null); fixedWidth = 20; }

	alias value = checked;
	alias editable = enabled;
}

class FormWidget(T) : IntBox!T if (isIntegral!T)
{
	this(Widget p) { super(p); alignment = TextBox.Alignment.Right; }
}

class FormWidget(T) : FloatBox!T if (isFloatingPoint!T)
{
	this(Widget p) { super(p); alignment = TextBox.Alignment.Right; }
}

class FormWidget(T) : TextBox if (isSomeString!T)
{
	this(Widget p) { super(p); alignment = TextBox.Alignment.Left; }

	void callback(void delegate(string) cb) {
		super.callback = (string str) { cb(str); return true; };
	}
}

/+
template <typename T> class FormWidget<T, typename std::is_enum<T>::type> : public ComboBox {
public:
	/// Creates a new FormWidget with underlying type ComboBox.
	FormWidget(Widget *p) : ComboBox(p) { }

	/// Pass-through function for \ref nanogui::ComboBox::selectedIndex.
	T value() const { return (T) selectedIndex(); }

	/// Pass-through function for \ref nanogui::ComboBox::setSelectedIndex.
	void setValue(T value) { setSelectedIndex((int) value); mSelectedIndex = (int) value; }

	/// Pass-through function for \ref nanogui::ComboBox::setCallback.
	void setCallback(const std::function<void(const T &)> &cb) {
		ComboBox::setCallback([cb](int v) { cb((T) v); });
	}

	/// Pass-through function for \ref nanogui::Widget::setEnabled.
	void setEditable(bool e) { setEnabled(e); }

public:
	EIGEN_MAKE_ALIGNED_OPERATOR_NEW
};
+/

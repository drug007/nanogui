///
module nanogui.combobox;

/*
	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
	The widget drawing code is based on the NanoVG demo application
	by Mikko Mononen.

	All rights reserved. Use of this source code is governed by a
	BSD-style license that can be found in the LICENSE.txt file.
*/
import std.container.array : Array;
import nanogui.popupbutton : PopupButton;
import nanogui.button : Button;
import nanogui.widget : Widget;
import nanogui.common : Vector2i, Vector2f;

/**
 * Simple combo box widget based on a popup button.
 */
class ComboBox : PopupButton
{
public:
	/// Create an empty combo box
	this(Widget parent)
	{
		super(parent);
		mSelectedIndex = 0;
	}

	/// Create a new combo box with the given items
	this(Widget parent, const string[] items)
	{
		this(parent);
		this.items(items);
	}

	/**
	 * Create a new combo box with the given items, providing both short and
	 * long descriptive labels for each item
	 */
	this(Widget parent, const string[] items,
			 const string[] itemsShort)
	{
		this(parent);
		this.items(items, itemsShort);
	}

	/// The callback to execute for this ComboBox.
	final void delegate(int) callback() const { return mCallback; }

	/// Sets the callback to execute for this ComboBox.
	final void callback(void delegate(int) callback) { mCallback = callback; }

	/// The current index this ComboBox has selected.
	final int selectedIndex() const { return mSelectedIndex; }

	/// Sets the current index this ComboBox has selected.
	final void selectedIndex(int idx)
	{
		if (mItemsShort.empty)
			return;
		auto children = popup.children;
		(cast(Button) children[mSelectedIndex]).pushed = false;
		(cast(Button) children[idx]).pushed = true;
		mSelectedIndex = idx;
		caption = mItemsShort[idx];
	}

	/// Sets the items for this ComboBox, providing both short and long descriptive lables for each item.
	final void items(const string[] items, const string[] itemsShort)
	{
		import std.exception : enforce;

		enforce(items.length == itemsShort.length);
		mItems.clear;
		mItems.insertBack(items);
		mItemsShort.clear;
		mItemsShort.insertBack(itemsShort);
		if (mSelectedIndex < 0 || mSelectedIndex >= cast(int) items.length)
			mSelectedIndex = 0;
		while (mPopup.childCount != 0)
			mPopup.removeChild(mPopup.childCount-1);

		import nanogui.layout : GroupLayout;
		mPopup.layout = new GroupLayout(2, 2);
		int index;
		foreach (const ref str; items)
		{
			Button button = new Button(mPopup, str);
			button.flags = Button.Flags.RadioButton;
			button.callback = ((int idx) => () {
				mSelectedIndex = idx;
				caption = mItemsShort[idx];
				pushed = false;
				popup.visible = false;
				if (mCallback)
					mCallback(idx);
			})(index);
			index++;
		}
		selectedIndex = mSelectedIndex;
	}

	/// Sets the items for this ComboBox.
	final void items(const string[] i) { items(i, i); }

	/// The items associated with this ComboBox.
	final auto items() const { return mItems; }

	/// The short descriptions associated with this ComboBox.
	final auto itemsShort() const { return mItemsShort; }

	/// Handles mouse scrolling events for this ComboBox.
	override bool scrollEvent(Vector2i p, Vector2f rel)
	{
		import std.algorithm : min, max;

		if (rel.y < 0)
		{
			selectedIndex = min(mSelectedIndex+1, cast(int)(items.length-1));
			if (mCallback)
				mCallback(mSelectedIndex);
			return true;
		} else if (rel.y > 0)
		{
			selectedIndex(max(mSelectedIndex-1, 0));
			if (mCallback)
				mCallback(mSelectedIndex);
			return true;
		}
		return Widget.scrollEvent(p, rel);
	}

// /// Saves the state of this ComboBox to the specified Serializer.
// virtual void save(Serializer &s) const override;

// /// Sets the state of this ComboBox from the specified Serializer.
// virtual bool load(Serializer &s) override;

protected:
	/// The items associated with this ComboBox.
	Array!string mItems;

	/// The short descriptions of items associated with this ComboBox.
	Array!string mItemsShort;

	/// The callback for this ComboBox.
	void delegate(int) mCallback;

	/// The current index this ComboBox has selected.
	int mSelectedIndex;
}

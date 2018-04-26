// ///
// module nanogui.textbox;

// /*
// 	nanogui.textbox.d -- Fancy text box with builtin regular
// 	expression-based validation

// 	The text box widget was contributed by Christian Schueller.

// 	NanoGUI was developed by Wenzel Jakob <wenzel.jakob@epfl.ch>.
// 	The widget drawing code is based on the NanoVG demo application
// 	by Mikko Mononen.

// 	All rights reserved. Use of this source code is governed by a
// 	BSD-style license that can be found in the LICENSE.txt file.
// */

// // import nanogui.compat;
// import arsd.nanovega;// : NVGContext, NVGGlyphPosition;
// import nanogui.widget : Widget;
// import nanogui.theme : Theme;
// import nanogui.common : Vector2i, MouseAction, MouseButton, Cursor;

// /**
//  * Fancy text box with builtin regular expression-based validation.
//  *
//  * Remark:
//  *     This class overrides `nanogui.Widget.mIconExtraScale` to be `0.8f`,
//  *     which affects all subclasses of this Widget.  Subclasses must explicitly
//  *     set a different value if needed (e.g., in their constructor).
//  */
// class TextBox : Widget
// {
// public:
// 	/// How to align the text in the text box.
// 	enum Alignment {
// 		Left,
// 		Center,
// 		Right
// 	};

// 	this(Widget parent, string value = "Untitled")
// 	{
// 		super(parent);
// 		mEditable  = false;
// 		mSpinnable = false;
// 		mCommitted = true;
// 		mValue     = value;
// 		mDefaultValue = "";
// 		mAlignment = Alignment.Center;
// 		mUnits = "";
// 		mFormat = "";
// 		mUnitsImage = NVGImage();
// 		mValidFormat = true;
// 		mValueTemp = value;
// 		mCursorPos = -1;
// 		mSelectionPos = -1;
// 		mMousePos = Vector2i(-1,-1);
// 		mMouseDownPos = Vector2i(-1,-1);
// 		mMouseDragPos = Vector2i(-1,-1);
// 		mMouseDownModifier = 0;
// 		mTextOffset = 0;
// 		mLastClick = 0;
// 		if (mTheme) mFontSize = mTheme.mTextBoxFontSize;
// 		mIconExtraScale = 0.8f;// widget override
// 	}

// 	bool editable() const { return mEditable; }
// 	final void editable(bool editable)
// 	{
// 		mEditable = editable;
// 		cursor = editable ? Cursor.IBeam : Cursor.Arrow;
// 	}

// 	final bool spinnable() const { return mSpinnable; }
// 	final void spinnable(bool spinnable) { mSpinnable = spinnable; }

// 	final string value() const { return mValue; }
// 	final void value(string value) { mValue = value; }

// 	final string defaultValue() const { return mDefaultValue; }
// 	final void defaultValue(string defaultValue) { mDefaultValue = defaultValue; }

// 	final Alignment alignment() const { return mAlignment; }
// 	final void alignment(Alignment al) { mAlignment = al; }

// 	final string units() const { return mUnits; }
// 	final void units(string units) { mUnits = units; }

// 	final auto unitsImage() const { return mUnitsImage; }
// 	final void unitsImage(NVGImage image) { mUnitsImage = image; }

// 	/// Return the underlying regular expression specifying valid formats
// 	final string format() const { return mFormat; }
// 	/// Specify a regular expression specifying valid formats
// 	final void format(string format) { mFormat = format; }

// 	/// Return the placeholder text to be displayed while the text box is empty.
// 	final string placeholder() const { return mPlaceholder; }
// 	/// Specify a placeholder text to be displayed while the text box is empty.
// 	final void placeholder(string placeholder) { mPlaceholder = placeholder; }

// 	/// Set the `Theme` used to draw this widget
// 	override void theme(Theme theme)
// 	{
// 		Widget.theme(theme);
// 		if (mTheme)
// 			mFontSize = mTheme.mTextBoxFontSize;
// 	}

// 	/// The callback to execute when the value of this TextBox has changed.
// 	final bool delegate(string str) callback() const { return mCallback; }

// 	/// Sets the callback to execute when the value of this TextBox has changed.
// 	final void callback(bool delegate(string str) callback) { mCallback = callback; }

// 	override bool mouseButtonEvent(Vector2i p, MouseButton button, bool down, int modifiers);
// 	override bool mouseMotionEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers);
// 	override bool mouseDragEvent(Vector2i p, Vector2i rel, MouseButton button, int modifiers);
// 	override bool focusEvent(bool focused);
// 	override bool keyboardEvent(int key, int scancode, int action, int modifiers);
// 	override bool keyboardCharacterEvent(dchar codepoint);

// 	override Vector2i preferredSize(NVGContext nvg) const
// 	{
// 		Vector2i size = Vector2i(0, cast(int) (fontSize * 1.4f));

// 		float uw = 0;
// 		if (mUnitsImage > 0) 
// 		{
// 			int w, h;
// 			nvg.imageSize(mUnitsImage, w, h);
// 			float uh = size[1] * 0.4f;
// 			uw = w * uh / h;
// 		} else if (mUnits.length)
// 		{
// 			uw = nvg.textBounds(0, 0, mUnits, null);
// 		}
// 		float sw = 0;
// 		if (mSpinnable)
// 			sw = 14.f;

// 		float ts = nvg.textBounds(0, 0, mValue, null);
// 		size[0] = size[1] + ts + uw + sw;
// 		return size;
// 	}
// 	override void draw(NVGContext nvg);
// // override void save(Serializer &s) const;
// // override bool load(Serializer &s);
// protected:
// 	bool checkFormat(string input, string format);
// 	bool copySelection();
// 	void pasteFromClipboard();
// 	bool deleteSelection();

// 	void updateCursor(NVGContext nvg, float lastx,
// 					  const NVGGlyphPosition *glyphs, int size);
// 	float cursorIndex2Position(int index, float lastx,
// 							   const NVGGlyphPosition *glyphs, int size);
// 	int position2CursorIndex(float posx, float lastx,
// 							 const NVGGlyphPosition *glyphs, int size);

// 	/// The location (if any) for the spin area.
// 	enum SpinArea { None, Top, Bottom };
// 	SpinArea spinArea(Vector2i pos);

// protected:
// 	bool mEditable;
// 	bool mSpinnable;
// 	bool mCommitted;
// 	string mValue;
// 	string mDefaultValue;
// 	Alignment mAlignment;
// 	string mUnits;
// 	string mFormat;
// 	NVGImage mUnitsImage;
// 	bool delegate(string str) mCallback;
// 	bool mValidFormat;
// 	string mValueTemp;
// 	string mPlaceholder;
// 	int mCursorPos;
// 	int mSelectionPos;
// 	Vector2i mMousePos;
// 	Vector2i mMouseDownPos;
// 	Vector2i mMouseDragPos;
// 	int mMouseDownModifier;
// 	float mTextOffset;
// 	double mLastClick;
// }

// // /**
// //  * \class IntBox textbox.h nanogui/textbox.h
// //  *
// //  * \brief A specialization of TextBox for representing integral values.
// //  *
// //  * Template parameters should be integral types, e.g. `int`, `long`,
// //  * `uint32_t`, etc.
// //  */
// // template <typename Scalar>
// // class IntBox : public TextBox {
// // public:
// // 	IntBox(Widget *parent, Scalar value = (Scalar) 0) : TextBox(parent) {
// // 		setDefaultValue("0");
// // 		setFormat(std::is_signed<Scalar>::value ? "[-]?[0-9]*" : "[0-9]*");
// // 		setValueIncrement(1);
// // 		setMinMaxValues(std::numeric_limits<Scalar>::lowest(), std::numeric_limits<Scalar>::max());
// // 		setValue(value);
// // 		setSpinnable(false);
// // 	}

// // 	Scalar value() const {
// // 		std::istringstream iss(TextBox::value());
// // 		Scalar value = 0;
// // 		iss >> value;
// // 		return value;
// // 	}

// // 	void setValue(Scalar value) {
// // 		Scalar clampedValue = std::min(std::max(value, mMinValue),mMaxValue);
// // 		TextBox::setValue(std::to_string(clampedValue));
// // 	}

// // 	void setCallback(const std::function<void(Scalar)> &cb) {
// // 		TextBox::setCallback(
// // 			[cb, this](const string &str) {
// // 				std::istringstream iss(str);
// // 				Scalar value = 0;
// // 				iss >> value;
// // 				setValue(value);
// // 				cb(value);
// // 				return true;
// // 			}
// // 		);
// // 	}

// // 	void setValueIncrement(Scalar incr) {
// // 		mValueIncrement = incr;
// // 	}
// // 	void setMinValue(Scalar minValue) {
// // 		mMinValue = minValue;
// // 	}
// // 	void setMaxValue(Scalar maxValue) {
// // 		mMaxValue = maxValue;
// // 	}
// // 	void setMinMaxValues(Scalar minValue, Scalar maxValue) {
// // 		setMinValue(minValue);
// // 		setMaxValue(maxValue);
// // 	}

// // 	virtual bool mouseButtonEvent(Vector2i p, int button, bool down, int modifiers) override {
// // 		if ((mEditable || mSpinnable) && down)
// // 			mMouseDownValue = value();

// // 		SpinArea area = spinArea(p);
// // 		if (mSpinnable && area != SpinArea::None && down && !focused()) {
// // 			if (area == SpinArea::Top) {
// // 				setValue(value() + mValueIncrement);
// // 				if (mCallback)
// // 					mCallback(mValue);
// // 			} else if (area == SpinArea::Bottom) {
// // 				setValue(value() - mValueIncrement);
// // 				if (mCallback)
// // 					mCallback(mValue);
// // 			}
// // 			return true;
// // 		}

// // 		return TextBox::mouseButtonEvent(p, button, down, modifiers);
// // 	}
// // 	virtual bool mouseDragEvent(Vector2i p, Vector2i rel, int button, int modifiers) override {
// // 		if (TextBox::mouseDragEvent(p, rel, button, modifiers)) {
// // 			return true;
// // 		}
// // 		if (mSpinnable && !focused() && button == 2 /* 1 << GLFW_MOUSE_BUTTON_2 */ && mMouseDownPos.x() != -1) {
// // 				int valueDelta = static_cast<int>((p.x() - mMouseDownPos.x()) / float(10));
// // 				setValue(mMouseDownValue + valueDelta * mValueIncrement);
// // 				if (mCallback)
// // 					mCallback(mValue);
// // 				return true;
// // 		}
// // 		return false;
// // 	}
// // 	virtual bool scrollEvent(Vector2i p, const Vector2f &rel) override {
// // 		if (Widget::scrollEvent(p, rel)) {
// // 			return true;
// // 		}
// // 		if (mSpinnable && !focused()) {
// // 			  int valueDelta = (rel.y() > 0) ? 1 : -1;
// // 			  setValue(value() + valueDelta*mValueIncrement);
// // 			  if (mCallback)
// // 				  mCallback(mValue);
// // 			  return true;
// // 		}
// // 		return false;
// // 	}
// // private:
// // 	Scalar mMouseDownValue;
// // 	Scalar mValueIncrement;
// // 	Scalar mMinValue, mMaxValue;
// // public:
// // 	EIGEN_MAKE_ALIGNED_OPERATOR_NEW
// // };

// // /**
// //  * \class FloatBox textbox.h nanogui/textbox.h
// //  *
// //  * \brief A specialization of TextBox representing floating point values.

// //  * Template parameters should be float types, e.g. `float`, `double`,
// //  * `float64_t`, etc.
// //  */
// // template <typename Scalar>
// // class FloatBox : public TextBox {
// // public:
// // 	FloatBox(Widget *parent, Scalar value = (Scalar) 0.f) : TextBox(parent) {
// // 		mNumberFormat = sizeof(Scalar) == sizeof(float) ? "%.4g" : "%.7g";
// // 		setDefaultValue("0");
// // 		setFormat("[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?");
// // 		setValueIncrement((Scalar) 0.1);
// // 		setMinMaxValues(std::numeric_limits<Scalar>::lowest(), std::numeric_limits<Scalar>::max());
// // 		setValue(value);
// // 		setSpinnable(false);
// // 	}

// // 	string numberFormat() const { return mNumberFormat; }
// // 	void numberFormat(const string &format) { mNumberFormat = format; }

// // 	Scalar value() const {
// // 		return (Scalar) std::stod(TextBox::value());
// // 	}

// // 	void setValue(Scalar value) {
// // 		Scalar clampedValue = std::min(std::max(value, mMinValue),mMaxValue);
// // 		char buffer[50];
// // 		NANOGUI_SNPRINTF(buffer, 50, mNumberFormat.c_str(), clampedValue);
// // 		TextBox::setValue(buffer);
// // 	}

// // 	void setCallback(const std::function<void(Scalar)> &cb) {
// // 		TextBox::setCallback([cb, this](const string &str) {
// // 			Scalar scalar = (Scalar) std::stod(str);
// // 			setValue(scalar);
// // 			cb(scalar);
// // 			return true;
// // 		});
// // 	}

// // 	void setValueIncrement(Scalar incr) {
// // 		mValueIncrement = incr;
// // 	}
// // 	void setMinValue(Scalar minValue) {
// // 		mMinValue = minValue;
// // 	}
// // 	void setMaxValue(Scalar maxValue) {
// // 		mMaxValue = maxValue;
// // 	}
// // 	void setMinMaxValues(Scalar minValue, Scalar maxValue) {
// // 		setMinValue(minValue);
// // 		setMaxValue(maxValue);
// // 	}

// // 	virtual bool mouseButtonEvent(Vector2i p, int button, bool down, int modifiers) override {
// // 		if ((mEditable || mSpinnable) && down)
// // 			mMouseDownValue = value();

// // 		SpinArea area = spinArea(p);
// // 		if (mSpinnable && area != SpinArea::None && down && !focused()) {
// // 			if (area == SpinArea::Top) {
// // 				setValue(value() + mValueIncrement);
// // 				if (mCallback)
// // 					mCallback(mValue);
// // 			} else if (area == SpinArea::Bottom) {
// // 				setValue(value() - mValueIncrement);
// // 				if (mCallback)
// // 					mCallback(mValue);
// // 			}
// // 			return true;
// // 		}

// // 		return TextBox::mouseButtonEvent(p, button, down, modifiers);
// // 	}
// // 	virtual bool mouseDragEvent(Vector2i p, Vector2i rel, int button, int modifiers) override {
// // 		if (TextBox::mouseDragEvent(p, rel, button, modifiers)) {
// // 			return true;
// // 		}
// // 		if (mSpinnable && !focused() && button == 2 /* 1 << GLFW_MOUSE_BUTTON_2 */ && mMouseDownPos.x() != -1) {
// // 			int valueDelta = static_cast<int>((p.x() - mMouseDownPos.x()) / float(10));
// // 			setValue(mMouseDownValue + valueDelta * mValueIncrement);
// // 			if (mCallback)
// // 				mCallback(mValue);
// // 			return true;
// // 		}
// // 		return false;
// // 	}
// // 	virtual bool scrollEvent(Vector2i p, const Vector2f &rel) override {
// // 		if (Widget::scrollEvent(p, rel)) {
// // 			return true;
// // 		}
// // 		if (mSpinnable && !focused()) {
// // 			int valueDelta = (rel.y() > 0) ? 1 : -1;
// // 			setValue(value() + valueDelta*mValueIncrement);
// // 			if (mCallback)
// // 				mCallback(mValue);
// // 			return true;
// // 		}
// // 		return false;
// // 	}

// // private:
// // 	string mNumberFormat;
// // 	Scalar mMouseDownValue;
// // 	Scalar mValueIncrement;
// // 	Scalar mMinValue, mMaxValue;
// // public:
// // 	EIGEN_MAKE_ALIGNED_OPERATOR_NEW
// // };

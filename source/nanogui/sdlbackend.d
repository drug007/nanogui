module nanogui.sdlbackend;

import std.datetime : Clock;
import std.exception: enforce;

import std.experimental.logger: Logger;

import gfm.sdl2: SDL_Event, SDL_Cursor, SDL_SetCursor, SDL_FreeCursor;

import arsd.nanovega : kill, NVGContextFlag;

import nanogui.screen : Screen;
import nanogui.theme : Theme;
import nanogui.common : NanoContext, Vector2i, MouseButton, MouseAction, Cursor;
import nanogui.sdlapp : SdlApp;

class SdlBackend : Screen
{
	this(int w, int h, string title)
	{
		_sdlApp = new SdlApp(w, h, title);

		_sdlApp.onBeforeLoopStart = ()
		{
			import std.datetime : dur;

			currTime = Clock.currTime.stdTime;
			if (currTime - mBlinkingCursorTimestamp > dur!"msecs"(500).total!"hnsecs")
			{
				mBlinkingCursorVisible = !mBlinkingCursorVisible;
				_sdlApp.invalidate();
				mBlinkingCursorTimestamp = currTime;
			}

			if (_onBeforeLoopStart)
				_onBeforeLoopStart();
		};

		_sdlApp.onDraw = ()
		{
			if (mNeedToDraw)
				_sdlApp.invalidate;
			size = Vector2i(width, height);
			super.draw(ctx);
		};

		_sdlApp.onKeyDown = (ref const(SDL_Event) event)
		{
			import nanogui.common : KeyAction;

			_sdlApp.invalidate;

			auto key = event.key.keysym.sym.convertSdlKeyToNanoguiKey;
			int modifiers = event.key.keysym.mod.convertSdlModifierToNanoguiModifier;
			return super.keyboardEvent(key, event.key.keysym.scancode, KeyAction.Press, modifiers);
		};

		_sdlApp.onMouseWheel = (ref const(SDL_Event) event)
		{
			_sdlApp.invalidate;
			if (event.wheel.y > 0)
			{
				btn = MouseButton.WheelUp;
				return super.scrollCallbackEvent(0, +1, Clock.currTime.stdTime);
			}
			else if (event.wheel.y < 0)
			{
				btn = MouseButton.WheelDown;
				return super.scrollCallbackEvent(0, -1, Clock.currTime.stdTime);
			}
			return false;
		};
		
		_sdlApp.onMouseMotion = (ref const(SDL_Event) event)
		{
			import gfm.sdl2 : SDL_BUTTON_LMASK, SDL_BUTTON_RMASK, SDL_BUTTON_MMASK;

			_sdlApp.invalidate;

			ctx.mouse.x = event.motion.x;
			ctx.mouse.y = event.motion.y;

			if (event.motion.state & SDL_BUTTON_LMASK)
				btn = MouseButton.Left;
			else if (event.motion.state & SDL_BUTTON_RMASK)
				btn = MouseButton.Right;
			else if (event.motion.state & SDL_BUTTON_MMASK)
				btn = MouseButton.Middle;

			if (event.motion.state & SDL_BUTTON_LMASK)
				modifiers |= MouseButton.Left;
			if (event.motion.state & SDL_BUTTON_RMASK)
				modifiers |= MouseButton.Right;
			if (event.motion.state & SDL_BUTTON_MMASK)
				modifiers |= MouseButton.Middle;

			action = MouseAction.Motion;
			return super.cursorPosCallbackEvent(ctx.mouse.x, ctx.mouse.y, Clock.currTime.stdTime);
		};

		_sdlApp.onMouseUp = (ref const(SDL_Event) event)
		{
			import gfm.sdl2 : SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT, SDL_BUTTON_MIDDLE;

			_sdlApp.invalidate;

			switch(event.button.button)
			{
				case SDL_BUTTON_LEFT:
					btn = MouseButton.Left;
				break;
				case SDL_BUTTON_RIGHT:
					btn = MouseButton.Right;
				break;
				case SDL_BUTTON_MIDDLE:
					btn = MouseButton.Middle;
				break;
				default:
			}
			action = MouseAction.Release;
			return super.mouseButtonCallbackEvent(btn, action, modifiers, Clock.currTime.stdTime);
		};

		_sdlApp.onMouseDown = (ref const(SDL_Event) event)
		{
			import gfm.sdl2 : SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT, SDL_BUTTON_MIDDLE;

			_sdlApp.invalidate;

			switch(event.button.button)
			{
				case SDL_BUTTON_LEFT:
					btn = MouseButton.Left;
				break;
				case SDL_BUTTON_RIGHT:
					btn = MouseButton.Right;
				break;
				case SDL_BUTTON_MIDDLE:
					btn = MouseButton.Middle;
				break;
				default:
			}
			action = MouseAction.Press;
			return super.mouseButtonCallbackEvent(btn, action, modifiers, Clock.currTime.stdTime);
		};

		_sdlApp.onKeyboardChar = delegate(dchar codepoint)
		{
			return keyboardCharacterEvent(codepoint);
		};

		_sdlApp.onClose = ()
		{
			if (_onClose)
				return _onClose();

			return true;
		};

		ctx = NanoContext(NVGContextFlag.Debug);
		enforce(ctx !is null, "cannot initialize NanoGui");

		import gfm.sdl2;
		mCursorSet[Cursor.Arrow]     = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_ARROW);
		mCursorSet[Cursor.IBeam]     = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_IBEAM);
		mCursorSet[Cursor.Crosshair] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_CROSSHAIR);
		mCursorSet[Cursor.Hand]      = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_HAND);
		mCursorSet[Cursor.HResize]   = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZEWE);
		mCursorSet[Cursor.VResize]   = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZENS);

		super(w, h, Clock.currTime.stdTime);
		theme = new Theme(ctx);
	}

	~this()
	{
		SDL_FreeCursor(mCursorSet[Cursor.Arrow]);
		SDL_FreeCursor(mCursorSet[Cursor.IBeam]);
		SDL_FreeCursor(mCursorSet[Cursor.Crosshair]);
		SDL_FreeCursor(mCursorSet[Cursor.Hand]);
		SDL_FreeCursor(mCursorSet[Cursor.HResize]);
		SDL_FreeCursor(mCursorSet[Cursor.VResize]);

		ctx.kill();
		destroy(_sdlApp);
	}

	private void delegate () _onBeforeLoopStart;
	void onBeforeLoopStart(void delegate () dg)
	{
		_onBeforeLoopStart = dg;
	}
	
	private bool delegate() _onClose;
	void onClose(bool delegate() dg) @safe
	{
		_onClose = dg;
	}

	void run()
	{
		onVisibleForTheFirstTime();

		_sdlApp.run();
	}

	void close()
	{
		_sdlApp.close();
	}

	auto invalidate() { _sdlApp.invalidate; }

	abstract void onVisibleForTheFirstTime();

	override Logger logger() { return _sdlApp.logger; }

protected:
	SdlApp _sdlApp;

	MouseButton btn;
	MouseAction action;
	int modifiers;

	NanoContext ctx;

	SDL_Cursor*[6] mCursorSet;

	override void cursor(Cursor value)
	{
		mCursor = value;
		SDL_SetCursor(mCursorSet[mCursor]);
	}

	override Cursor cursor() const
	{
		return mCursor;
	}
}

private auto convertSdlKeyToNanoguiKey(int sdlkey)
{
	import gfm.sdl2;
	import nanogui.common : KeyAction, Key;

	int nanogui_key;
	switch(sdlkey)
	{
		case SDLK_LEFT:
			nanogui_key = Key.Left;
		break;
		case SDLK_RIGHT:
			nanogui_key = Key.Right;
		break;
		case SDLK_UP:
			nanogui_key = Key.Up;
		break;
		case SDLK_DOWN:
			nanogui_key = Key.Down;
		break;
		case SDLK_BACKSPACE:
			nanogui_key = Key.Backspace;
		break;
		case SDLK_DELETE:
			nanogui_key = Key.Delete;
		break;
		case SDLK_HOME:
			nanogui_key = Key.Home;
		break;
		case SDLK_END:
			nanogui_key = Key.End;
		break;
		case SDLK_RETURN:
			nanogui_key = Key.Enter;
		break;
		case SDLK_a:
			nanogui_key = Key.A;
		break;
		case SDLK_x:
			nanogui_key = Key.X;
		break;
		case SDLK_c:
			nanogui_key = Key.C;
		break;
		case SDLK_v:
			nanogui_key = Key.V;
		break;
		case SDLK_ESCAPE:
			nanogui_key = Key.Esc;
		break;
		default:
			nanogui_key = sdlkey;
	}

	return nanogui_key;
}

private auto convertSdlModifierToNanoguiModifier(int mod)
{
	import gfm.sdl2;
	import nanogui.common : KeyMod;

	int nanogui_mod;

	if (mod & KMOD_LCTRL)
		nanogui_mod |= KeyMod.Ctrl;
	if (mod & KMOD_LSHIFT)
		nanogui_mod |= KeyMod.Shift;
	if (mod & KMOD_LALT)
		nanogui_mod |= KeyMod.Alt;
	if (mod & KMOD_RCTRL)
		nanogui_mod |= KeyMod.Ctrl;
	if (mod & KMOD_RSHIFT)
		nanogui_mod |= KeyMod.Shift;
	if (mod & KMOD_RALT)
		nanogui_mod |= KeyMod.Alt;

	return nanogui_mod;
}
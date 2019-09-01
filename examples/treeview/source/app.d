module examples.sdl;

import std.datetime : Clock;
import std.traits : isDynamicArray;
import arsd.nanovega;
import nanogui.sdlbackend : SdlBackend;
import nanogui.widget : Widget;
import nanogui.glcanvas : GLCanvas;

struct Model(T) if (is(T == struct))
{
	const(T)* data;

	this(ref T t)
	{
		data = &t;
	}

	auto opSlice()
	{
		return Range!T(data);
	}

	struct Range(R)
	{
		@disable
		this();

		private
		{
			const(R)* source;
			size_t idx;

			auto helper(size_t i)
			{
				import std.conv : text;
				switch(i)
				{
					static foreach(j; 0..R.tupleof.length)
					{
						case j:
							return text((*source).tupleof[j]);
					}
					default:
					{
						assert(0);
					}
				}
			}
		}

		this(const(R)* source)
		{
			this.source = source;
		}

		auto front()
		{
			return helper(idx);
		}

		auto empty() const
		{
			return idx == R.tupleof.length;
		}

		void popFront()
		{
			assert(!empty);
			idx++;
		}
	}
}


struct Model(T) if (isDynamicArray!T)
{
	@disable
	this();

	T data;

	this(T t)
	{
		data = t;
	}

	auto opSlice()
	{
		return Range!(typeof(data))(data, 0, data.length);
	}

	struct Range(R)
	{
		@disable
		this();

		private
		{
			R source;
			size_t from, to;
		}

		this(R source, size_t from, size_t to)
		{
			this.source = source;
			this.from   = from;
			this.to     = to;
		}

		auto front()
		{
			return source[from];
		}

		auto empty() const
		{
			return from == to;
		}

		void popFront()
		{
			assert(!empty);
			from++;
		}
	}
}

auto model(T)(T t) if (isDynamicArray!T)
{
	return Model!T(t);
}

auto model(T)(ref T t) if (is(T == struct))
{
	return Model!T(t);
}

// void main()
// {
// 	string[] data = [ "item1", "item2", "item3", "item4", "item5", "item6" ];
// 	auto model1 = model(data);

// 	static struct Foo
// 	{
// 		int i;
// 		float f;
// 		string str = "test";
// 	}
// 	Foo foo;
// 	auto model2 = model(foo);


// 	import std.stdio;
// 	writeln(model1[]);
// 	writeln(model2[]);
// }

class MyGui : SdlBackend
{
	this(int w, int h, string title)
	{
		super(w, h, title);
	}

	override void onVisibleForTheFirstTime()
	{
		import nanogui.screen : Screen;
		import nanogui.widget, nanogui.theme, nanogui.checkbox, nanogui.label, 
			nanogui.common, nanogui.window, nanogui.layout, nanogui.button,
			nanogui.popupbutton, nanogui.entypo, nanogui.popup, nanogui.vscrollpanel,
			nanogui.combobox, nanogui.textbox, nanogui.formhelper;
		
		{
			auto window = new Window(screen, "TreeView demo", true);
			window.position(Vector2i(400, 245));
			window.size = Vector2i(150, 260);
			// window.size = Vector2i(screen.size.x - 30, screen.size.y - 30);
			window.layout(new BoxLayout(Orientation.Vertical));

			import nanogui.experimental.treeview;
			new TreeView!float(window, "TreeView_______", 10, null);
			new TreeView!float(window, "TreeView_2_____", 11, null);
			new TreeView!float(window, "TreeView_3_____", 12, null);
			new TreeView!float(window, "TreeView_4_____", 13, null);
			new TreeView!(float[])(window, "TreeView_5_____", [14.0f, 29, 100], null);
		}

		// now we should do layout manually yet
		screen.performLayout(ctx);
	}
}

void main () {
	auto gui = new MyGui(1000, 800, "Nanogui TreeView example");
	gui.run();
}

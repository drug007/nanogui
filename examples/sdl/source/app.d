module examples.sdl;

import std.datetime : Clock;
import std.getopt : defaultGetoptPrinter, getopt;
import arsd.nanovega;
import nanogui.sdlbackend : SdlBackend;
import nanogui.widget : Widget;
import nanogui.glcanvas : GLCanvas;

struct Vertex
{
	import nanogui.common;
	Vector3f position;
	Vector3f color;
}

extern(C)
uint timer_callback(uint interval, void *param) nothrow
{
	import gfm.sdl2;

    SDL_Event event;
    SDL_UserEvent userevent;

    userevent.type = SDL_USEREVENT;
    userevent.code = 0;
    userevent.data1 = null;
    userevent.data2 = null;

    event.type = SDL_USEREVENT;
    event.user = userevent;

    SDL_PushEvent(&event);
    return(interval);
}

class MyGlCanvas : GLCanvas
{
	import std.typecons : scoped;
	import gfm.opengl;
	import gfm.math;
	import nanogui.common;

	this(Widget parent, int w, int h)
	{
		super(parent, w, h);

		const program_source = 
			"#version 130

			#if VERTEX_SHADER
			uniform mat4 modelViewProj;
			in vec3 position;
			in vec3 color;
			out vec4 frag_color;
			void main() {
				frag_color  = modelViewProj * vec4(0.5 * color, 1.0);
				gl_Position = modelViewProj * vec4(position / 2, 1.0);
			}
			#endif

			#if FRAGMENT_SHADER
			out vec4 color;
			in vec4 frag_color;
			void main() {
				color = frag_color;
			}
			#endif";

		_program = new GLProgram(program_source);
		assert(_program);
		auto vert_spec = scoped!(VertexSpecification!Vertex)(_program);
		_rotation = Vector3f(0.25f, 0.5f, 0.33f);

		int[12*3] indices =
		[
			0, 1, 3,
			3, 2, 1,
			3, 2, 6,
			6, 7, 3,
			7, 6, 5,
			5, 4, 7,
			4, 5, 1,
			1, 0, 4,
			4, 0, 3,
			3, 7, 4,
			5, 6, 2,
			2, 1, 5,
		];

		auto vertices = 
		[
			Vertex(Vector3f(-1,  1,  1), Vector3f(1, 0, 0)),
			Vertex(Vector3f(-1,  1, -1), Vector3f(0, 1, 0)),
			Vertex(Vector3f( 1,  1, -1), Vector3f(1, 1, 0)),
			Vertex(Vector3f( 1,  1,  1), Vector3f(0, 0, 1)),
			Vertex(Vector3f(-1, -1,  1), Vector3f(1, 0, 1)),
			Vertex(Vector3f(-1, -1, -1), Vector3f(0, 1, 1)),
			Vertex(Vector3f( 1, -1, -1), Vector3f(1, 1, 1)),
			Vertex(Vector3f( 1, -1,  1), Vector3f(0.5, 0.5, 0.5)),
		];

		auto vbo = scoped!GLBuffer(GL_ARRAY_BUFFER, GL_STATIC_DRAW, vertices);
		auto ibo = scoped!GLBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_STATIC_DRAW, indices);

		_vao = scoped!GLVAO();
		// prepare VAO
		{
			_vao.bind();
			vbo.bind();
			ibo.bind();
			vert_spec.use();
			_vao.unbind();
		}

		{
			import gfm.sdl2 : SDL_AddTimer;
			uint delay = 40;
			_timer_id = SDL_AddTimer(delay, &timer_callback, null);
		}
	}

	~this()
	{
		import gfm.sdl2 : SDL_RemoveTimer;
		SDL_RemoveTimer(_timer_id);
	}

	override void drawGL()
	{
		static long start_time;
		mat4f mvp;
		mvp = mat4f.identity;

		if (start_time == 0)
			start_time = Clock.currTime.stdTime;

		auto angle = (Clock.currTime.stdTime - start_time)/10_000_000.0*rotateSpeed;
		mvp = mvp.rotation(angle, _rotation);

		GLboolean depth_test_enabled;
		glGetBooleanv(GL_DEPTH_TEST, &depth_test_enabled);
		if (!depth_test_enabled)
			glEnable(GL_DEPTH_TEST);
		scope(exit)
		{
			if (!depth_test_enabled)
				glDisable(GL_DEPTH_TEST);
		}

		_program.uniform("modelViewProj").set(mvp);
		_program.use();
		scope(exit) _program.unuse();

		_vao.bind();
		glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, cast(void *) 0);
		_vao.unbind();
	}

private:
	GLProgram _program;
	Vector3f  _rotation;

	import gfm.sdl2 : SDL_TimerID;
	SDL_TimerID _timer_id;

	import std.typecons : scoped;
	import gfm.opengl : GLVAO;

	float rotateSpeed = 1.0;
	alias ScopedGLVAO = typeof(scoped!GLVAO());
	ScopedGLVAO    _vao;
}

class MyGui : SdlBackend
{
	import nanogui.label;
	import resusage : ProcessCPUWatcher;

	Label lblCpuUsage;
	ProcessCPUWatcher cpuWatcher;

	this(int w, int h, string title, int scale)
	{
		super(w, h, title, scale);
	}

	override void onVisibleForTheFirstTime()
	{
		import nanogui.screen : Screen;
		import nanogui.widget, nanogui.theme, nanogui.checkbox, nanogui.label, 
			nanogui.common, nanogui.window, nanogui.layout, nanogui.button,
			nanogui.popupbutton, nanogui.entypo, nanogui.popup, nanogui.vscrollpanel,
			nanogui.combobox, nanogui.textbox, nanogui.formhelper;
		
		{
			auto window = new Window(screen, "Button demo", true);
			window.position(Vector2i(15, 15));
			window.size = Vector2i(190, 370);
			window.layout(new GroupLayout());

			new Label(window, "Push buttons", "sans-bold");

			auto checkbox = new CheckBox(window, "Checkbox #1", null);
			checkbox.position = Vector2i(100, 190);
			checkbox.size = checkbox.preferredSize(ctx);
			checkbox.checked = true;

			auto label = new Label(window, "Label");
			label.position = Vector2i(100, 300);
			label.size = label.preferredSize(ctx);

			Popup popup;

			auto btn = new Button(window, "Button");
			btn.callback = () { 
				popup.children[0].visible = !popup.children[0].visible; 
				label.caption = popup.children[0].visible ? 
					"Popup label is visible" : "Popup label isn't visible";
			};

			auto popupBtn = new PopupButton(window, "PopupButton", Entypo.ICON_EXPORT);
			popup = popupBtn.popup;
			popup.layout(new GroupLayout());
			new Label(popup, "Arbitrary widgets can be placed here");
			new CheckBox(popup, "A check box", null);

			window.tooltip = "Button demo tooltip";
		}

		{
			auto window = new Window(screen, "Button group example");
			window.position(Vector2i(220, 15));
			window.layout(new GroupLayout());

			auto buttonGroup = ButtonGroup();

			auto btn = new Button(window, "RadioButton1");
			btn.flags = Button.Flags.RadioButton;
			btn.buttonGroup = buttonGroup;
			btn.tooltip = "Radio button ONE";
			buttonGroup ~= btn;

			btn = new Button(window, "RadioButton2");
			btn.flags = Button.Flags.RadioButton;
			btn.buttonGroup = buttonGroup;
			btn.tooltip = "Radio button TWO";
			buttonGroup ~= btn;

			btn = new Button(window, "RadioButton3");
			btn.flags = Button.Flags.RadioButton;
			btn.buttonGroup = buttonGroup;
			btn.tooltip = "Radio button THREE";
			buttonGroup ~= btn;

			window.tooltip = "Radio button group tooltip";
		}

		{
			auto window = new Window(screen, "Button with image window");
			window.position(Vector2i(400, 15));
			window.layout(new GroupLayout());

			auto image = ctx.nvg.createImage("resources/icons/start.jpeg", [NVGImageFlags.ClampToBorderX, NVGImageFlags.ClampToBorderY]);
			auto btn = new Button(window, "Start", image);
			// some optional height, not font size, not icon height
			btn.fixedHeight = 130;

			// yet another Button with the same image but default size
			new Button(window, "Start", image);

			window.tooltip = "Window with button that has image as an icon";
		}

		{
			auto window = new Window(screen, "Combobox window");
			window.position(Vector2i(600, 15));
			window.layout(new GroupLayout());

			new Label(window, "Message dialog", "sans-bold");
			import std.algorithm : map;
			import std.range : iota;
			import std.array : array;
			import std.conv : text;
			auto items = 15.iota.map!(a=>text("items", a)).array;
			auto cb = new ComboBox(window, items);
			cb.cursor = Cursor.Hand;
			cb.tooltip = "This widget has custom cursor value - Cursor.Hand";

			window.tooltip = "Window with ComboBox tooltip";
		}

		{
			const width  = 340;
			const height = 350;

			auto window = new Window(screen, "Virtual TreeView demo", true);
			window.position(Vector2i(10, 400));
			window.size(Vector2i(width, height));
			window.setId = "window";
			auto layout = new BoxLayout(Orientation.Vertical);
			window.layout(layout);
			layout.margin = 5;
			layout.setAlignment = Alignment.Fill;

			version(none)
			{
				auto panel = new Widget(window);
				panel.setId = "panel";
				auto layout2 = new BoxLayout(Orientation.Horizontal);
				panel.layout(layout2);
				layout2.margin = 5;
				layout2.setAlignment = Alignment.Fill;
			}

			import std.random : uniform, Random;
			auto rnd = Random(19937);

			Item[] data;
			enum total = 1_000_000;
			data.reserve(total);
			foreach(i; 0..total)
			{
				import std.conv : text;
				const x = uniform(0, 6, rnd);
				switch(x)
				{
					case 0:
						float f = cast(float) i;
						data ~= Item(f);
					break;
					case 1:
						int n = cast(int) i;
						data ~= Item(n);
					break;
					case 2:
						string str = text("item #", i);
						data ~= Item(str);
					break;
					case 3:
						double d = cast(double) i;
						data ~= Item(d);
					break;
					case 4:
						Test t;
						data ~= Item(t);
					break;
					default:
					case 5:
						Test2 t2;
						data ~= Item(t2);
					break;
				}
			}

			import nanogui.experimental.list;
			auto list = new List!(typeof(data))(window, data);
			version(none) auto list = new List!(typeof(data))(panel, data);
			list.collapsed = false;
			list.setId = "virtual list";
		}

		{
			auto asian_theme = new Theme(ctx);

			{
				// sorta hack because loading font in nvg results in
				// conflicting font id
				auto nvg2 = nvgCreateContext(NVGContextFlag.Debug);
				scope(exit) nvg2.kill;
				nvg2.createFont("chihaya", "./resources/fonts/n_chihaya_font.ttf");
				ctx.nvg.addFontsFrom(nvg2);
				asian_theme.mFontNormal = ctx.nvg.findFont("chihaya");
			}

			auto window = new Window(screen, "Textbox window");
			window.position = Vector2i(750, 15);
			window.fixedSize = Vector2i(200, 350);
			window.layout(new GroupLayout());
			window.tooltip = "Window with TextBoxes";

			auto tb = new TextBox(window, "Россия");
			tb.editable = true;

			tb = new TextBox(window, "England");
			tb.editable = true;

			tb = new TextBox(window, "日本");
			tb.theme = asian_theme;
			tb.editable = true;

			tb = new TextBox(window, "中国");
			tb.theme = asian_theme;
			tb.editable = true;

			version(none)
			{

			// Added two arabic themes after https://forum.dlang.org/thread/sbymyafmdrsfgemlgsld@forum.dlang.org
			// currently don't work as expected

			auto arabic_theme1 = new Theme(ctx);
			{
				// sorta hack because loading font in nvg results in
				// conflicting font id
				auto nvg2 = nvgCreateContext(NVGContextFlag.Debug);
				scope(exit) nvg2.kill;
				nvg2.createFont("arabic1", "./resources/fonts/Amiri-Regular.ttf");
				ctx.nvg.addFontsFrom(nvg2);
				arabic_theme1.mFontNormal = ctx.nvg.findFont("arabic1");
			}

			auto arabic_theme2 = new Theme(ctx);
			{
				// sorta hack because loading font in nvg results in
				// conflicting font id
				auto nvg2 = nvgCreateContext(NVGContextFlag.Debug);
				scope(exit) nvg2.kill;
				nvg2.createFont("arabic2", "./resources/fonts/ElMessiri-VariableFont_wght.ttf");
				ctx.nvg.addFontsFrom(nvg2);
				arabic_theme2.mFontNormal = ctx.nvg.findFont("arabic2");
			}

			tb = new TextBox(window, "حالكم");
			tb.theme = arabic_theme1;
			tb.editable = true;

			tb = new TextBox(window, "حالكم");
			tb.theme = arabic_theme2;
			tb.editable = true;

			} // version(none)
		}

		{
			auto window = new Window(screen, "GLCanvas Demo", true);
			window.size(Vector2i(280, 510));
			window.position = Vector2i(400, 240);
			window.layout = new GroupLayout();
			auto glcanvas = new MyGlCanvas(window, 250, 250);
			glcanvas.backgroundColor = Color(0.1f, 0.1f, 0.1f, 1.0f);
			glcanvas = new MyGlCanvas(window, 200, 200);
			glcanvas.fixedSize = Vector2i(200, 200);
			glcanvas.backgroundColor = Color(0.2f, 0.3f, 0.4f, 1.0f);
			glcanvas.rotateSpeed = 0.5;
		}

		{
			auto window = new Window(screen, "AdvancedGridLayout");
			auto layout = new AdvancedGridLayout(
				[7, 0, 70,  70,  6, 70, 6], // columns width
				[7, 0,  5, 240, 17,  0, 6], // rows height
			);
			window.position = Vector2i(700, 400);
			window.layout = layout;

			auto title   = new Label(window, "Advanced grid layout");
			auto content = new Label(window, "Some text");
			layout.setAnchor(title,                        AdvancedGridLayout.Anchor(1, 1, 5, 1, Alignment.Middle, Alignment.Middle));
			layout.setAnchor(content,                      AdvancedGridLayout.Anchor(1, 3, 5, 1, Alignment.Middle, Alignment.Middle));
			layout.setAnchor(new Button(window, "Help"),   AdvancedGridLayout.Anchor(1, 5, 1, 1));
			layout.setAnchor(new Button(window, "Ok"),     AdvancedGridLayout.Anchor(3, 5, 1, 1));
			layout.setAnchor(new Button(window, "Cancel"), AdvancedGridLayout.Anchor(5, 5, 1, 1));
		}

		{
			static bool bvar = true;
			static int ivar = 12345678;
			static double dvar = 3.1415926;
			static float fvar = 3.1415926;
			static string strval = "A string";

			auto gui = new FormHelper(screen);
			gui.addWindow(Vector2i(220, 180),"Form helper example");
			gui.addGroup("Basic types");
			gui.addVariable("bool", bvar);
			gui.addVariable("string", strval, true);

			gui.addGroup("Validating fields");
			// Expose an integer variable by reference
			gui.addVariable("int", ivar);
			// Expose a float variable via setter/getter functions
			gui.addVariable("float",
				(float value) { fvar = value; },
				() { return fvar; });
			gui.addVariable("double", dvar).spinnable = true;
			gui.addButton("Button", () { /* noop */ });
		}

		{
			auto window = new Window(screen, "CPU usage", true);
			window.position(Vector2i(15, 225));
			window.size = Vector2i(100, 60);
			window.layout(new GroupLayout());

			import std.process : thisProcessID;
			import std.conv : text;
			cpuWatcher = new ProcessCPUWatcher(thisProcessID);

			lblCpuUsage = new Label(window, cpuWatcher.current().text, "sans-bold");
		}

		{
			auto window = new Window(screen, "TreeView demo", true);
			window.position(Vector2i(600, 130));
			window.size = Vector2i(240, 360);
			window.layout(new BoxLayout(Orientation.Vertical));

			import nanogui.experimental.treeview;
			new TreeView!float(window, "TreeView_______", 10f, null);
			new TreeView!(float[])(window, "TreeView_2_____", [11f, 22f, 33, 44], null);
			new TreeView!Test(window, "TreeView_3_____", Test(), null);
			new TreeView!Test2(window, "TreeView_4_____", Test2(), null);

			auto items = [
				Item(0.3f),
				Item(3),
				Item("some string"),
				Item(double.nan),
				Item(Test(99, 100, "another text")),
				Item(Test2(9.9, 11, Test(-1, -20, "nested Test"))),
			];
			new TreeView!(Item[])(window, "TaggedAlgebraic[]", items, null);
		}

		// now we should do layout manually yet
		screen.performLayout(ctx);
	}
}

struct Test
{
	float f = 7.7;
	int i = 8;
	string s = "some text";
}

struct Test2
{
	double d = 8.8;
	long l = 999;
	Test t;
}

import taggedalgebraic : TaggedAlgebraic;
union Payload
{
	float f;
	int i;
	string str;
	double d;
	Test t;
	Test2 t2;
}
alias Item = TaggedAlgebraic!Payload;

int main (string[] args)
{
	int scale = 1;

	auto helpInformation = getopt(
		args,
		"scale", "Scale, 2 for 4K monitors and 1 for the rest", &scale,
	);

	if (helpInformation.helpWanted)
	{
		defaultGetoptPrinter("Usage:", helpInformation.options);
		return 0;
	}

	if (scale != 1 && scale != 2)
	{
		import std;
		stderr.writeln("Scale can be 1 or 2 only");
		return 1;
	}

	auto gui = new MyGui(1000, 800, "Nanogui using SDL2 backend", scale);
	gui.onBeforeLoopStart = () {
		import std.datetime : SysTime, seconds, Clock;
		static SysTime prevStdTime;
		const currStdTime = Clock.currTime;
		if (currStdTime - prevStdTime > 1.seconds)
		{
			prevStdTime = currStdTime;
			import std.format : format;
			import std.parallelism : totalCPUs;
			gui.lblCpuUsage.caption = format("%2.2f%%", gui.cpuWatcher.current*totalCPUs);
		}
	};
	gui.run();

	return 0;
}

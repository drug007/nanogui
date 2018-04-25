D port of [nanogui](https://github.com/wjakob/nanogui)

The port is incomplete - not all widgets are ported, but all ported widgets are fully usable.

There is difference with origin. For example:
- instead of const references passing by value is used
- as a color and vector implementation gfm.math is used (in origin eigen used as a vector implementation and own implementation of color type)
- no locking on glfw, instead two backends are available - arsd.simpledisplay (no external dependencies) and SDL2 (depends on SDL2 library obviously)

Examples

Two examples added:
- arsd.simpledisplay based, run it using `dub --config=arsd`
- SDL2 based, run it using `dub --config=sdl`
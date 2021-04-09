# What is it? [![.github/workflows/main.yml](https://github.com/drug007/nanogui/actions/workflows/main.yml/badge.svg)](https://github.com/drug007/nanogui/actions/workflows/main.yml)

D port of [nanogui](https://github.com/wjakob/nanogui)

The port is incomplete - not all widgets are ported, but all ported widgets are fully usable.

There is difference with origin. For example:
- instead of const references passing by value is used
- as a color and vector implementation gfm.math is used (in origin eigen used as a vector implementation and own implementation of color type)
- no locking on glfw, instead two backends are available - arsd.simpledisplay (no external dependencies) and SDL2 (depends on SDL2 library obviously), SDL backend is more developed than arsd one (due to lack of time). Other backend like glfw, sfml etc can be easily added, nanogui is agnostic to underlying layer.

## Install dependencies

On Ubuntu and debian based Linux run this command to install system dependencies:

```sh
sudo apt-get install libfontconfig1-dev
```

## Cloning source

```
git clone https://github.com/drug007/nanogui.git
```

# Examples

Directory `examples` contains two packages, providing examples for `arsd` and `sdl` backends. To run example `cd` to corresponding directory and run `dub` command. For example:
```
cd examples/sdl
dub
```
SDL2 based example is more advanced (due to lack of time).

# Screenshot

Screenshot is a bit old and do not show some widgets for example GLCanvas
![Screenshot](https://github.com/drug007/nanogui/blob/develop/resources/readme/nanogui_001.gif)

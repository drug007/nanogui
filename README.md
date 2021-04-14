# What is it? 

[![.github/workflows/main.yml](https://github.com/drug007/nanogui/actions/workflows/main.yml/badge.svg)](https://github.com/drug007/nanogui/actions/workflows/main.yml)
[![Build](https://github.com/drug007/nanogui/actions/workflows/main.yml/badge.svg)](https://github.com/drug007/nanogui/actions/workflows/main.yml)

### Disclaimer

Release 1.0.0 is a regular release and is not a major one. The only reason to make this release was transition to [dsemver](https://github.com/symmetryinvestments/dsemver). It means that versions like 0.x.x are not possible so this release was numbered 1.0.0. The release contains experimental widgets List and TreeView but they are under development, also arsd backed has been dropped.

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

Directory `examples` contains a package, providing example for `sdl` backends. To run example `cd example/sdl` and run `dub` command. For example:
```
cd examples/sdl
dub
```

# Screenshot

Screenshot #1 is a bit old and do not show some widgets for example GLCanvas
![Screenshot #1](https://github.com/drug007/nanogui/blob/develop/resources/readme/nanogui_001.gif)
Screenshot #2 is a recent one and demonstrates GLCanvas, advanced grid layout, experimental widgets List and TreeView
<img src="resources/readme/nanogui_002.webm?raw=true" alt="nanogui_002.webm">


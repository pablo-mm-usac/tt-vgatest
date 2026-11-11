<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

VGA Bounce & Clone displays moving logos on a 640x480 VGA screen using Verilog.

The logos bounce off screen edges and change colors. Users can adjust their speed from 1 to 32 pixels per frame using `ui_in[6:2]`.

When `ui_in[7]` is enabled, each collision creates a new logo, up to a maximum of 4 logos. Each moves independently.

## How to test

1. Run the design in Tiny Tapeout VGA Playground.
2. Use `ui_in[2:6]` to adjust movement speed.
3. Enable `ui_in[7]` to duplicate logos upon collision.
4. Enable `ui_in[1]` for color changes.
5. Enable `ui_in[0]` for tile mode.
6. Disable `ui_in[7]` to return to one logo.


## External hardware

TinyVGA PMOD and a compatible VGA monitor for physical hardware testing. No external hardware is required for simulation.

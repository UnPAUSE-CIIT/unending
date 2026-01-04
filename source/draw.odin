package main

import rl "vendor:raylib"

Text_Align :: enum {
	Left,
	Center,
	Right,
}

draw_text:: proc(text: cstring, font_size: f32, font_name: cstring = "title", x,y: f32, align: Text_Align) {
    line_size := rl.MeasureTextEx(fonts[font_name], text, font_size, 2)
	xoff: f32 = 0.0

	switch align {
	case .Left:
		xoff = 0
	case .Center:
		xoff = line_size.x / 2
	case .Right:
		xoff = line_size.x
	}

	rl.DrawTextEx(fonts[font_name], text, {x - xoff, y}, font_size, 1, rl.WHITE)
}

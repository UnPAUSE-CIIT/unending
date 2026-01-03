package main

import rl "vendor/raylib"

draw_text :: proc(text: cstring, font_size) {
    line_width := rl.MeasureTextEx(fonts["title"], name, 48, 2)
	rl.DrawTextEx(fonts["title"], name, {f32(center) - line_width.x / 2, y}, 48, 2, rl.WHITE)
}

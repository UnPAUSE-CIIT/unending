package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

draw_button :: proc {
	draw_text_button,
	draw_image_button,
}

draw_image_button :: proc(
	image: rl.Texture2D,
	bounds: rl.Rectangle,
	on_click: proc(),
	alpha: V2i = {50, 255}, // alpha.x = normal, .y = hovered
) {
	mouse_pos := rl.GetMousePosition()
	is_hovered := rl.CheckCollisionPointRec(mouse_pos, bounds)

	a := is_hovered ? alpha.y : alpha.x
	base_col := rl.Color{255, 255, 255, u8(a)}

	src := rl.Rectangle{0, 0, f32(image.width), f32(image.height)}
	rl.DrawTexturePro(image, src, bounds, V2f(0), 0, base_col)

	if is_hovered && rl.IsMouseButtonPressed(.LEFT) {
		if on_click != nil {
			on_click()
		}
	}
}

// maybe find some way to abstract common button props (is_hovered, on_click, etc)
draw_text_button :: proc(text: cstring, bounds: rl.Rectangle, on_click: proc()) {
	mouse_pos := rl.GetMousePosition()
	is_hovered := rl.CheckCollisionPointRec(mouse_pos, bounds)

	base_col := rl.Color{0, 0, 0, 50}
	if is_hovered {
		base_col = rl.BLACK
	}

	rl.DrawRectangleRounded(bounds, 0.3, 5, base_col)
	line_width := rl.MeasureTextEx(fonts["body"], text, 24, 2)
	rl.DrawTextEx(
		fonts["body"],
		text,
		{bounds.x + bounds.width / 2 - line_width.x / 2, bounds.y + 12},
		24,
		2,
		rl.WHITE,
	)

	if is_hovered && rl.IsMouseButtonPressed(.LEFT) {
		if on_click != nil {
			on_click()
		}
	}
}

draw_wrapped_text :: proc(
	font: rl.Font,
	text: string,
	pos: rl.Vector2,
	font_size: f32,
	spacing: f32,
	max_width: f32,
	color: rl.Color,
) -> f32 {
	words := strings.split(text, " ")
	line := ""
	line_y := pos.y
	line_height: f32

	for word in words {
		// simulate adding the next word
		candidate :=
			line == "" ? word : strings.join({line, word}, sep = " ", allocator = context.temp_allocator)

		size := rl.MeasureTextEx(font, fmt.ctprintf(candidate), font_size, spacing)
		line_height = size.y
		if size.x > max_width {
			// draw current line
			rl.DrawTextEx(
				font,
				fmt.ctprintf(line),
				rl.Vector2{pos.x, line_y},
				font_size,
				spacing,
				color,
			)
			// start new line
			line = word
			line_y += line_height + 5
		} else {
			line = candidate
		}
	}

	// draw last line
	if line != "" {
		size := rl.MeasureTextEx(font, fmt.ctprintf(line), font_size, spacing)
		line_height = size.y

		rl.DrawTextEx(
			font,
			fmt.ctprintf(line),
			rl.Vector2{pos.x, line_y},
			font_size,
			spacing,
			color,
		)
	}

	return line_y + line_height
}

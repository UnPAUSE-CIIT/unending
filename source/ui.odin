package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

PANEL_DEFAULT_PADDING :: 24.0

BUTTON_DEFAULT_ROUNDING :: 0.3
BUTTON_DEFAULT_PADDING :: V2f{12.0, 8.0}
BUTTON_DEFAULT_COLOR :: rl.BLACK

draw_button :: proc {
	draw_text_button,
	draw_image_button,
}

draw_image_button :: proc(
	image: rl.Texture2D,
	bounds: rl.Rectangle,
	alpha: V2i = {50, 255}, // alpha.x = normal, .y = hovered
) -> bool {
	mouse_pos := rl.GetMousePosition()
	is_hovered := rl.CheckCollisionPointRec(mouse_pos, bounds)

	a := is_hovered ? alpha.y : alpha.x
	base_col := rl.Color{255, 255, 255, u8(a)}

	src := rl.Rectangle{0, 0, f32(image.width), f32(image.height)}
	rl.DrawTexturePro(image, src, bounds, V2f(0), 0, base_col)

	return is_hovered && rl.IsMouseButtonPressed(.LEFT) 
}

// @returns button size (v2f), is pressed (bool)
draw_text_button :: proc(text: cstring, x, y: f32, w: f32 = 0) -> (V2f, bool) {
	width := w + BUTTON_DEFAULT_PADDING.x
	line_size := rl.MeasureTextEx(fonts["body"], text, 18, 2)

	if w == 0 { // fit content
		width = line_size.x + BUTTON_DEFAULT_PADDING.x
	}

	bounds := rl.Rectangle{
		x, y,
		width,
		line_size.y + ( BUTTON_DEFAULT_PADDING.y * 2 ),
	}

	mouse_pos := rl.GetMousePosition()
	is_hovered := rl.CheckCollisionPointRec(mouse_pos, bounds)
	base_col := BUTTON_DEFAULT_COLOR
	base_col.a = is_hovered ? 255 : 50

	rl.DrawRectangleRounded(bounds, BUTTON_DEFAULT_ROUNDING, 5, base_col)
	rl.DrawTextEx(
		fonts["body"],
		text,
		{bounds.x + bounds.width / 2 - line_size.x / 2, bounds.y + line_size.y / 2},
		18,
		1,
		rl.WHITE,
	)

	return {bounds.width, bounds.height}, is_hovered && rl.IsMouseButtonPressed(.LEFT)
}

Text_Align :: enum {
	Left,
	Center,
	Right,
}

// @returns line size (V2f)
draw_text:: proc(text: cstring, font_size: f32, font_name: cstring = "title", x,y: f32, align: Text_Align) -> V2f {
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

	return line_size
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

Layout_Direction :: enum {
	Horizontal,
	Vertical,
}

Layout :: struct {
	top_x: f32,
	top_y: f32,
	curr_y: f32,
	curr_x: f32,
	width: f32,
	height: f32,

	spacing: f32,
	direction: Layout_Direction,
	padding: V2f,
	background_color: rl.Color,
	rect: rl.Rectangle,
}

layout_create :: proc( 
	x, y: f32, 
	spacing: f32 = 8, 
	direction: Layout_Direction = .Vertical, 
	padding: V2f = V2f(0.0), 
	background_color: rl.Color = {0, 0, 0, 0}
) -> Layout {
	return Layout{
		top_x = x,
		top_y = y,
		curr_y = y,
		curr_x = x,
		spacing = spacing,
		direction = direction,
		padding = padding,
		background_color = background_color,
	}
}

layout_update_rect :: proc( layout: ^Layout ) {
	layout.height = layout.top_y + layout.curr_y
	layout.width = layout.top_x + layout.curr_x
}

layout_push_text :: proc( layout: ^Layout, str: string, font_size: f32, font_name: cstring, align: Text_Align ) {
	size := draw_text(to_cstr(str), font_size, font_name, layout.curr_x, layout.curr_y, align)
	if layout.direction == .Vertical {
		layout.curr_y += font_size + layout.spacing
	} else {
		layout.curr_x += size.x + layout.spacing
	}
}

layout_push_text_button :: proc(
	layout: ^Layout,
	text: cstring, 
) -> bool {
	btn_size, is_pressed := draw_button(
		text,
		layout.curr_x,
		layout.curr_y,
	)

	if layout.direction == .Vertical {
		layout.curr_y += btn_size.y + layout.spacing
	} else {
		layout.curr_x += btn_size.x + layout.spacing
	}

	return is_pressed
}

layout_push_image_button :: proc(
	layout: ^Layout,
	image: rl.Texture2D,
	on_click: proc(),
	alpha: V2i = {50, 255}, // alpha.x = normal, .y = hovered
) {
}

layout_push_sub_layout :: proc( layout: ^Layout, child: ^Layout ) {
	child.top_x = layout.curr_x
	child.top_y = layout.curr_y

	child.curr_x = layout.curr_x
	child.curr_y = layout.curr_y
}

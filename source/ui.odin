package main

/*
   the UI system consists of 2 UI foundations
   - rects for overall layout structure (groups)
   - cursors for individual placement inside a rect/group

   this UI system assumes that you are building either 
   - LTR (left to right) horizontal layouts
   - or TTB (top to bottom) vertical layouts
*/

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

TEXT_DEFAULT_LINE_SPACING :: 2.0

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
draw_text:: proc(text: cstring, font_size: f32, font_name: cstring = "title", x,y: f32, align: Text_Align, color: rl.Color = rl.WHITE) -> V2f {
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

	rl.DrawTextEx(fonts[font_name], text, {x - xoff, y}, font_size, 1, color)

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
	curr_y: f32 = 0.0
	line_height: f32 = font_size + spacing

	for line in strings.split_lines(text) {
		words := strings.split(line, " ")
		curr_line := ""

		for word in words {
			test_line := fmt.ctprintf( "{}{} ", curr_line, word )
			if rl.MeasureTextEx( font, test_line, font_size, 2 ).x > max_width {
				rl.DrawTextEx( 
					font,
					fmt.ctprintf(curr_line),
					V2f{pos.x, pos.y + curr_y},
					font_size,
					spacing,
					color,
				)
				curr_y += line_height
				curr_line = ""
			}

			curr_line = fmt.tprintf( "{}{} ", curr_line, word )
		}

		if curr_line != "" {
			rl.DrawTextEx( 
					font,
					fmt.ctprintf(curr_line),
					V2f{pos.x, pos.y + curr_y},
					font_size,
					spacing,
					color,
				)
		}

		curr_y += line_height
	}

	return curr_y
}

Layout_Direction :: enum {
	Horizontal,
	Vertical,
}

Layout :: struct {
	top: V2f,
	max: V2f,
	curr: V2f,

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
	max_width: f32 = 0,
	max_height: f32 = 0,
	spacing: f32 = 8, 
	direction: Layout_Direction = .Vertical, 
	padding: V2f = V2f(0.0), 
	background_color: rl.Color = {0, 0, 0, 0}
) -> Layout {
	return Layout{
		top = { x, y, },
		curr = { x, y, },
		width = 0,
		height = 0,
		max = { max_width, max_height },
		spacing = spacing,
		direction = direction,
		padding = padding,
		background_color = background_color,
	}
}

layout_push_text :: proc( layout: ^Layout, str: string, font_size: f32, font_name: cstring, align: Text_Align, wrapped: bool = false, color: rl.Color = rl.WHITE ) {
	size: V2f

	// prob should force wrapping everywhere if layout has max_width?
	// tho that is expensive
	if wrapped {
		size.y = draw_wrapped_text(
			fonts[font_name],
			str,
			layout.curr,
			font_size,
			TEXT_DEFAULT_LINE_SPACING,
			layout.max.x,
			color,
		)
		size.x = layout.max.x
	} else {
		size = draw_text(
			  to_cstr(str), 
			  font_size, 
			  font_name, 
			  layout.curr.x, 
			  layout.curr.y, 
			  align,
			  color,
			)
	} 

	if layout.direction == .Vertical {
		layout.curr.y += size.y + layout.spacing
		layout.width = max( layout.width, size.x ) 
		layout.height = layout.curr.y - layout.top.y
	} else {
		layout.curr.x += size.x + layout.spacing
		layout.width = layout.curr.x - layout.top.x
		layout.height = max( layout.height, size.y )
	}

}

layout_push_text_button :: proc(
	layout: ^Layout,
	text: cstring, 
) -> bool {
	size, is_pressed := draw_button(
		text,
		layout.curr.x,
		layout.curr.y,
	)

	if layout.direction == .Vertical {
		layout.curr.y += size.y + layout.spacing
		layout.width = max( layout.width, size.x )
	} else {
		layout.curr.x += size.x + layout.spacing
		layout.height = max( layout.height, size.y )
	}

	return is_pressed
}

layout_push_image_button :: proc(
	layout: ^Layout,
	image: rl.Texture2D,
	on_click: proc(),
	alpha: V2i = {50, 255}, // alpha.x = normal, .y = hovered
) {
	// layout.width = max( layout.width, layout.width + size.x )
	// layout.height = max( layout.height, layout.height + size.y )
}

layout_complete :: proc( layout: ^Layout ) {
	rl.DrawRectangle( i32(layout.top.x), i32(layout.top.y), 10, 10, rl.RED )
	rl.DrawRectangle( i32(layout.top.x), i32(layout.top.y), i32(layout.width), i32(layout.height), { 255, 255, 0, 10 } )
	rl.DrawRectangle( i32(layout.curr.x), i32(layout.curr.y), 10, 10, rl.BLUE )
}

layout_append :: proc( layout: ^Layout, child: ^Layout ) {
	if layout.direction == .Vertical {
		layout.curr.y += child.height + layout.spacing
	} else {
		layout.curr.x += child.width + layout.spacing
	}
}

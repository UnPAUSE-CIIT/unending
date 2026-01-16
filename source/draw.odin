package main

import rl "vendor:raylib"

get_window_size :: proc() -> V2f {
	return { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}

draw_image :: proc(image_name: cstring, pos: V2f, size: V2f = V2f(0.0), rotation: f32 = 0.0) {
	image, ok := textures[image_name]
	if !ok {
		image = textures["missing"]
	}

	src := rl.Rectangle{0, 0, f32(image.width), f32(image.height)}
	s := size
	if size.x == 0 {
		s.x = src.width
		s.y = src.height 
	}

	bounds := rl.Rectangle{pos.x, pos.y, s.x, s.y}
	rl.DrawTexturePro(image, src, bounds, V2f(0), rotation, rl.WHITE)
}


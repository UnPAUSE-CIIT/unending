package main

import rl "vendor:raylib"

get_window_size :: proc() -> V2f {
	return { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}

draw_image :: proc(image_name: cstring, pos, size: V2f) {
	image, ok := textures[image_name]
	if !ok {
		image = textures["missing"]
	}

	src := rl.Rectangle{0, 0, f32(image.width), f32(image.height)}
	bounds := rl.Rectangle{pos.x, pos.y, size.x, size.y}
	rl.DrawTexturePro(image, src, bounds, V2f(0), 0, rl.WHITE)
}


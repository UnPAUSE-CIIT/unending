package main

import rl "vendor:raylib"

active_gamepad: i32 = 0

setup_gamepad :: proc() {
	for i in 0 ..< 10 {
		if rl.IsGamepadAvailable(i32(i)) {
			active_gamepad = i32(i)
			break
		}
	}
}

on_left_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.A) ||
		   rl.IsKeyPressed(.LEFT) ||
		   rl.IsGamepadButtonPressed(active_gamepad, .LEFT_FACE_LEFT)
}

on_right_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.D) ||
		   rl.IsKeyPressed(.RIGHT) ||
		   rl.IsGamepadButtonPressed(active_gamepad, .LEFT_FACE_RIGHT)
}

on_submit_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.ENTER) || 
		   rl.IsGamepadButtonPressed(active_gamepad, .RIGHT_FACE_DOWN)
}

on_cancel_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.ESCAPE) ||
		   rl.IsKeyPressed(.BACKSPACE) ||
		   rl.IsGamepadButtonPressed(active_gamepad, .RIGHT_FACE_RIGHT) ||
		   rl.IsMouseButtonPressed(.RIGHT)
}

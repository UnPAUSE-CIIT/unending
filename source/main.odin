package main

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(800, 600, "UnEnding")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawText("UnPAUSing the Nation", 150, 280, 20, rl.WHITE)

		rl.EndDrawing()
	}
}

package main
import "core:encoding/json"
import "core:fmt"
import "core:log"
import la "core:math/linalg"
import "core:os"

import rl "vendor:raylib"

Game :: struct {
	name:               string,
	description:        string,
	genres:             []string,
	developers:         []string,
	supported_controls: []string,
	download_link:      string,
	game_file:          string,
}

g_games := make([dynamic]Game)
currently_selected: int = 0

load_all_games :: proc() {
	dir_handle, dir_err := os.open("build/games")
	if dir_err != nil {
		log.error("dir err", dir_err)
		return
	}
	defer os.close(dir_handle)

	entries, err := os.read_dir(dir_handle, -1, context.temp_allocator)
	assert(err == nil, "err fetching game infos")
	defer delete(entries, context.temp_allocator)

	for entry in entries {
		if !entry.is_dir {
			continue
		}

		game_info_data, ok := os.read_entire_file_from_filename(
			fmt.tprintf("%s/game.json", entry.fullpath),
		)
		assert(ok, fmt.tprint("failed to read game info for:", entry.name))

		game_info: Game
		json_err := json.unmarshal(game_info_data, &game_info)
		assert(json_err == nil, fmt.tprint("error reading", entry.name, json_err))
		append(&g_games, game_info)
	}
}

move_camera :: proc(i: int) {
}

main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger
	load_all_games()

	rl.InitWindow(rl.GetMonitorWidth(0), rl.GetMonitorHeight(0), "UnEnding")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)
	rl.ToggleBorderlessWindowed()

	for !rl.WindowShouldClose() {
		// :Update
		if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
			currently_selected = (currently_selected - 1 + len(g_games)) % len(g_games)
			move_camera(currently_selected)
		}
		if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
			currently_selected = (currently_selected + 1) % len(g_games)
			move_camera(currently_selected)
		}

		// :Draw
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawText(fmt.ctprint(currently_selected), 10, 260, 20, rl.WHITE)

		if len(g_games) > 0 {
			rl.DrawText(fmt.ctprint(g_games[currently_selected].name), 10, 280, 20, rl.WHITE)
			rl.DrawText(
				fmt.ctprint(g_games[currently_selected].description),
				10,
				300,
				20,
				rl.WHITE,
			)
		}

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	free_all(context.temp_allocator)
}

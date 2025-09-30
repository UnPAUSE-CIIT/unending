package main
import "core:encoding/json"
import "core:fmt"
import "core:log"
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
		log.info(game_info)
	}
}

main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger
	load_all_games()

	rl.InitWindow(800, 600, "UnEnding")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawText("UnPAUSing the Nation", 150, 280, 20, rl.WHITE)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	free_all(context.temp_allocator)
}

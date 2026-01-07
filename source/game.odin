#+feature dynamic-literals
package main
import "core:encoding/json"
import rl "vendor:raylib"
import "core:strings"
import "core:fmt"
import "core:log"
import "core:os"

Supported_Control :: enum {
	Keyboard,
	Mouse,
	Controller,
}

Game :: struct {
	name:               string,
	description:        string,
	genres:             []string,
	developers:         []string,
	members:            []string,
	download_link:      string,
	supported_controls: []Supported_Control,
	fullpath:           string,
	game_file:          string,
	model:              rl.Model,
	texture:            rl.Texture2D,
	rotation:           f32,
	hidden:             bool,
	qr_img:             rl.Texture2D,
	aabb:               rl.BoundingBox,
	tr_aabb:            rl.BoundingBox,
}

INPUT_TEXTURES := map[Supported_Control]cstring {
	.Keyboard   = "keyboard",
	.Mouse      = "mouse",
	.Controller = "controller",
}


g_games: [dynamic]Game
load_all_games :: proc() {
	g_games = make([dynamic]Game)
	dir_handle, dir_err := os.open(g_config.games_path)
	if dir_err != nil {
		log.error("dir err", dir_err)
		return
	}
	defer os.close(dir_handle)

	entries, err := os.read_dir(dir_handle, -1, context.temp_allocator)
	assert(err == nil, "err fetching game infos")
	defer delete(entries, context.temp_allocator)

	for &entry in entries {
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

		if game_info.hidden {
			continue
		}

		game_info.fullpath = strings.clone(entry.fullpath)

		// this will load the same model for all games, Raylib has no way to copy/make unique materials
		game_info.model = rl.LoadModel("assets/box_art_base.glb")
		game_info.texture = rl.LoadTexture(to_cstr("%s/box_art.png", entry.fullpath))
		game_info.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = game_info.texture // 0 is default material

		game_info.qr_img = rl.LoadTexture(to_cstr("%s/qr.png", entry.fullpath))
		game_info.aabb = rl.GetMeshBoundingBox(game_info.model.meshes[0])
		append(&g_games, game_info)
	}
}

launch_game :: proc(game: Game) {
	run_game_threaded(game)
	is_viewing_game_details = false

	rl.PlaySound(sounds["sfx_launch"])
}

free_all_games :: proc() {
	for &g in g_games {
		rl.UnloadModel(g.model)
		rl.UnloadTexture(g.texture)
	}
	delete(g_games)
}

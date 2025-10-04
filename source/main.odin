package main
import "core:encoding/json"
import "core:fmt"
import "core:log"
import la "core:math/linalg"
import "core:os"
import "core:os/os2"
import "core:strings"
import "core:sync/chan"
import "core:thread"
import "core:unicode/utf8"

import rl "vendor:raylib"

TITLE :: "UnENDING v1.0.1"
V2f :: [2]f32
V3f :: [3]f32

BOX_OFFSETS :: 4.0

Game :: struct {
	name:               string,
	description:        string,
	genres:             []string,
	developers:         []string,
	members:            []string,
	supported_controls: []string,
	download_link:      string,
	fullpath:           string,
	game_file:          string,
	model:              rl.Model,
	texture:            rl.Texture2D,
	rotation:           f32,
	hidden:             bool,
}

g_games := make([dynamic]Game)
currently_selected: int = 0
is_viewing_game_details := false

camera_target_position := V3f{0.0, 0.0, -1.0}
do_camera_move := false

load_all_games :: proc() {
	dir_handle, dir_err := os.open("games")
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

		// load model
		game_info.model = rl.LoadModel("assets/box_art_base.glb")
		game_info.texture = rl.LoadTexture(to_cstr("%s/box_art.png", entry.fullpath))
		game_info.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = game_info.texture // 0 is default material

		append(&g_games, game_info)
	}

	// @TODO remove when org weave is done ?
	// force mutiny to be first in list
	{
		mutiny_id: int = -1
		for game, i in g_games {
			if game.name == "Mutiny" {
				mutiny_id = i
				continue
			}
		}

		prev_one := g_games[0]
		g_games[0] = g_games[mutiny_id]
		g_games[mutiny_id] = prev_one
	}
}

move_camera :: proc(i: int, camera: ^rl.Camera3D) {
	trg_pos := V3f{f32(i) * BOX_OFFSETS, 0.0, 0.0}

	if is_viewing_game_details {
		trg_pos.x -= 1.9
		trg_pos.y += 0.3
	}

	camera_target_position = V3f{trg_pos.x, trg_pos.y, 5}
	do_camera_move = true
	current_tab = .General
}

draw_basic_details :: proc(game: Game) {
	name := to_cstr(game.name)
	devs := to_cstr(strings.join(game.developers, ", ", context.temp_allocator))
	tags := to_cstr(strings.join(game.genres, ", ", context.temp_allocator))

	center := (rl.GetScreenWidth() / 2)
	line_width := rl.MeasureTextEx(fonts["title"], name, 48, 2)
	y := la.floor(f32(rl.GetScreenHeight()) * .78)
	rl.DrawTextEx(fonts["title"], name, {f32(center) - line_width.x / 2, y}, 48, 2, rl.WHITE)

	y += 50
	line_width = rl.MeasureTextEx(fonts["body"], devs, 24, 1)
	rl.DrawTextEx(fonts["body"], devs, {f32(center) - line_width.x / 2, y}, 24, 1, rl.WHITE)

	y += 32
	line_width = rl.MeasureTextEx(fonts["body_italic"], tags, 18, 1)
	rl.DrawTextEx(fonts["body_italic"], tags, {f32(center) - line_width.x / 2, y}, 18, 1, rl.WHITE)
}

Detail_Tab :: enum {
	General,
	Credits,
}
current_tab: Detail_Tab = .General
draw_complete_details :: proc(game: Game) {
	x := la.floor(f32(rl.GetScreenWidth()) * 0.1)
	y := la.floor(f32(rl.GetScreenHeight()) * 0.2)

	padding := f32(30)

	draw_button(
		text = "Info",
		bounds = rl.Rectangle{x + 5, y - padding - 64, 100, 54},
		on_click = proc() {
			current_tab = .General
		},
	)
	draw_button(
		text = "Credits",
		bounds = rl.Rectangle{x + 110, y - padding - 64, 100, 54},
		on_click = proc() {
			current_tab = .Credits
		},
	)

	rl.DrawRectangleRounded(
		rl.Rectangle{x - padding, y - padding, 900 + padding * 2, f32(rl.GetScreenHeight()) * 0.7},
		0.05,
		18,
		{0, 0, 0, 50},
	)

	// header
	itch_rec := rl.Rectangle{x + 670, y, 740 * 0.3, 228 * 0.3}
	rl.DrawTexturePro(
		textures["itch"],
		rl.Rectangle{0, 0, 740, 228},
		itch_rec,
		{0, 0},
		0,
		rl.WHITE,
	)

	name := to_cstr(game.name)
	devs := to_cstr(strings.join(game.developers, ", ", context.temp_allocator))

	rl.DrawTextEx(fonts["title"], name, {x, y}, 52, 2, rl.WHITE)
	y += 52 + 18

	rl.DrawTextEx(fonts["body_italic"], devs, {x, y}, 18, 1, rl.WHITE)
	y += 48

	if current_tab == .General {
		desc := to_cstr(game.description)
		tags := to_cstr(strings.join(game.genres, ", ", context.temp_allocator))

		last_y := draw_wrapped_text(fonts["body"], game.description, {x, y}, 24, 1, 900, rl.WHITE)
		y = last_y + 24

		rl.DrawTextEx(fonts["body_italic"], to_cstr("Genres: %s", tags), {x, y}, 24, 1, rl.WHITE)
		y += 24 + 6
	} else {
		rl.DrawTextEx(fonts["body_italic"], "Members", {x, y}, 32, 1, rl.WHITE)
		y += 32 + 18
		members := to_cstr(strings.join(game.members, "\n", context.temp_allocator))
		rl.DrawTextEx(fonts["body"], members, {x, y}, 24, 1, rl.WHITE)
	}
}

main :: proc() {
	// mac doesnt use app dir as working directory
	rl.ChangeDirectory(rl.GetApplicationDirectory())

	logger := log.create_console_logger()
	context.logger = logger

	rl.SetConfigFlags({.MSAA_4X_HINT, .FULLSCREEN_MODE, .VSYNC_HINT})
	rl.InitWindow(rl.GetMonitorWidth(0), rl.GetMonitorHeight(0), TITLE)
	defer rl.CloseWindow()

	rl.SetExitKey(.F10)

	setup_game_runner()

	// :font loading
	load_font("title")
	load_font("body", font_size = 48)
	load_font("body_italic", font_size = 48)
	rl.SetTextLineSpacing(16)

	load_texture("bg")
	load_texture("itch")
	load_texture("left_chev")
	load_texture("right_chev")
	load_all_games()

	camera := rl.Camera3D {
		up         = V3f{0.0, 1.0, 0.0},
		target     = camera_target_position,
		position   = V3f{0.0, 0.0, 5.0},
		fovy       = 45.0,
		projection = .PERSPECTIVE,
	}

	rl.SetTargetFPS(120)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, .CUSTOM)

		if do_camera_move {
			dist := rl.Vector3Distance(camera.position, camera_target_position)
			if dist >= 0.01 {
				camera.position = la.lerp(
					camera.position,
					camera_target_position,
					20 * rl.GetFrameTime(),
				)
				camera.target = camera.position + V3f{0, 0, -1}
			} else {
				do_camera_move = false
			}
		}

		// :Update
		if !is_game_launched {
			if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
				currently_selected = (currently_selected - 1 + len(g_games)) % len(g_games)
				move_camera(currently_selected, &camera)
			}
			if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
				currently_selected = (currently_selected + 1) % len(g_games)
				move_camera(currently_selected, &camera)
			}
			if rl.IsKeyPressed(.ENTER) {
				if !is_viewing_game_details {
					is_viewing_game_details = true
				} else {
					run_game_threaded(g_games[currently_selected])
					is_viewing_game_details = false
				}
				move_camera(currently_selected, &camera)
			}

			if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.BACKSPACE) {
				is_viewing_game_details = false
				move_camera(currently_selected, &camera)
			}
		} else {
			wait_for_game_close()
		}

		// :Draw
		rl.BeginDrawing()
		rl.ClearBackground(rl.DARKBLUE)

		// @TODO replace bg with screenshot
		rl.DrawTextureRec(
			textures["bg"],
			rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
			V2f(0.0),
			rl.WHITE,
		)

		rl.DrawTextEx(fonts["title"], TITLE, {10, 10}, 24, 2, {255, 255, 255, 50})

		// :bottom bar
		bar_height := i32(72)
		bar_pos := V2f{0, f32(rl.GetScreenHeight() - bar_height)}
		rl.DrawRectangle(0, i32(bar_pos.y), rl.GetScreenWidth(), bar_height, {0, 0, 0, 180})

		// @TODO use sprites for this, use a spritesheet or use a font?
		bottom_bar_text: cstring =
			!is_viewing_game_details ? "A/D - navigate\t\tEnter - view game\t\tF10 - quit" : "Enter - launch game\t\tEsc/Backspace - back to selection"

		if is_game_launched {
			bottom_bar_text = fmt.ctprintf("running {}...", g_games[currently_selected].name)
		}

		rl.DrawTextEx(
			fonts["title"],
			bottom_bar_text,
			{bar_pos.x + 10, bar_pos.y + 16},
			32,
			2,
			rl.WHITE,
		)

		rl.BeginMode3D(camera)
		for &game, i in g_games {
			if i == currently_selected {
				rot_speed: f32 = is_game_launched ? 900 : 30
				game.rotation += rl.GetFrameTime() * rot_speed
			} else {
				game.rotation = 0
			}

			if (is_viewing_game_details || is_game_launched) && i != currently_selected {
				continue
			}

			// @TODO use lit shader with basic directional light?
			rl.DrawModelEx(
				game.model,
				V3f{f32(i) * BOX_OFFSETS, 0.2, 0},
				V3f{0, 1, 0},
				game.rotation,
				V3f(1.0),
				rl.WHITE,
			)
		}
		rl.EndMode3D()

		if len(g_games) > 0 {
			curr_game := g_games[currently_selected]
			if is_viewing_game_details {
				draw_complete_details(curr_game)
			} else {
				draw_basic_details(curr_game)
			}
		}

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	for &game in g_games {
		rl.UnloadModel(game.model)
		rl.UnloadTexture(game.texture)
	}

	free_resources()
	destroy_game_runner()

	free_all(context.temp_allocator)
}

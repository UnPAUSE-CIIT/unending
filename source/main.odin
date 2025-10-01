package main
import "core:encoding/json"
import "core:fmt"
import "core:log"
import la "core:math/linalg"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

V2f :: [2]f32
V3f :: [3]f32

BOX_OFFSETS :: 4.0

Game :: struct {
	name:               string,
	description:        string,
	genres:             []string,
	developers:         []string,
	supported_controls: []string,
	download_link:      string,
	game_file:          string,
	model:              rl.Model,
	texture:            rl.Texture2D,
	rotation:           f32,
}

g_games := make([dynamic]Game)
currently_selected: int = 0
camera_target_position := V3f{0.0, 0.0, -1.0}
do_camera_move := false

title_font: rl.Font
body_font: rl.Font
body_font_italic: rl.Font

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

		// load model
		game_info.model = rl.LoadModel("build/assets/box_art_base.glb")
		game_info.texture = rl.LoadTexture(fmt.ctprintf("%s/box_art.png", entry.fullpath))
		game_info.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = game_info.texture // 0 is default material

		append(&g_games, game_info)
	}
}

move_camera :: proc(i: int, camera: ^rl.Camera3D) {
	trg_pos := V3f{f32(i) * BOX_OFFSETS, 0.0, 0.0}
	camera_target_position = V3f{trg_pos.x, 0, 5}
	do_camera_move = true
}

draw_basic_details :: proc(game: Game) {
	name := fmt.ctprint(game.name)
	devs := fmt.ctprint(strings.join(game.developers, ", ", context.temp_allocator))
	tags := fmt.ctprint(strings.join(game.genres, ", ", context.temp_allocator))

	center := (rl.GetScreenWidth() / 2)
	line_width := rl.MeasureTextEx(title_font, name, 48, 2)
	y := la.floor(f32(rl.GetScreenHeight()) * .80)
	rl.DrawTextEx(title_font, name, {f32(center) - line_width.x / 2, y}, 48, 2, rl.WHITE)

	y += 50
	line_width = rl.MeasureTextEx(body_font, devs, 24, 1)
	rl.DrawTextEx(body_font, devs, {f32(center) - line_width.x / 2, y}, 24, 1, rl.WHITE)

	y += 32
	line_width = rl.MeasureTextEx(body_font_italic, tags, 18, 1)
	rl.DrawTextEx(body_font_italic, tags, {f32(center) - line_width.x / 2, y}, 18, 1, rl.WHITE)
}

main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger

	rl.SetConfigFlags({.MSAA_4X_HINT, .FULLSCREEN_MODE, .VSYNC_HINT})
	rl.InitWindow(rl.GetMonitorWidth(0), rl.GetMonitorHeight(0), "UnEnding")
	defer rl.CloseWindow()

	// load fonts
	title_font = rl.LoadFontEx("build/assets/title.ttf", 48, nil, 0)
	body_font = rl.LoadFontEx("build/assets/body.ttf", 48, nil, 0)
	body_font_italic = rl.LoadFontEx("build/assets/body_italic.ttf", 48, nil, 0)
	rl.SetTextLineSpacing(16)

	bg_tex := rl.LoadTexture("build/assets/bg.png")
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
			}
		}

		// :Update
		if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
			currently_selected = (currently_selected - 1 + len(g_games)) % len(g_games)
			move_camera(currently_selected, &camera)
		}
		if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
			currently_selected = (currently_selected + 1) % len(g_games)
			move_camera(currently_selected, &camera)
		}

		// :Draw
		rl.BeginDrawing()
		rl.ClearBackground(rl.DARKBLUE)

		rl.DrawTextureRec(
			bg_tex,
			rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
			V2f(0.0),
			rl.WHITE,
		)

		rl.BeginMode3D(camera)
		for &game, i in g_games {
			if i == currently_selected {
				game.rotation += rl.GetFrameTime() * 30
			} else {
				game.rotation = 0
			}

			rl.DrawModelEx(
				game.model,
				V3f{f32(i) * BOX_OFFSETS, 0, 0},
				V3f{0, 1, 0},
				game.rotation,
				V3f(1.0),
				rl.WHITE,
			)
		}
		rl.EndMode3D()

		if len(g_games) > 0 {
			draw_basic_details(g_games[currently_selected])
		}

		rl.DrawFPS(10, 10)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	for &game in g_games {
		rl.UnloadModel(game.model)
		rl.UnloadTexture(game.texture)
	}
	rl.UnloadFont(title_font)
	rl.UnloadFont(body_font)
	rl.UnloadFont(body_font_italic)

	rl.CloseWindow()

	free_all(context.temp_allocator)
}

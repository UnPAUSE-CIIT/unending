#+feature dynamic-literals
package main
import "core:encoding/json"
import "core:flags"
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

TITLE :: "UnENDING v1.3.3"
V2f :: [2]f32
V3f :: [3]f32
V2i :: [2]i32

BOX_OFFSETS :: 4.0

Supported_Control :: enum {
	Keyboard,
	Mouse,
	Controller,
}

INPUT_TEXTURES := map[Supported_Control]cstring {
	.Keyboard   = "keyboard",
	.Mouse      = "mouse",
	.Controller = "controller",
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

Launch_Flags :: struct {
	fullscreen: bool,
}

// @TODO, use screen/panel contexts/flags instead of these bools
active_gamepad: i32 = 0
g_games := make([dynamic]Game)
currently_selected: int = 0
is_viewing_game_details := false
is_showing_qr := false

game_camera: rl.Camera3D
camera_target_position := V3f{0.0, 0.0, -1.0}
do_camera_move := false

idle_timer: f32 = 0
last_demo_shift_trigger: i32 = -1
AFK_DEMO_THRESHOLD :: f32(30.0)
DEMO_SHIFT_DURATION :: 5
is_demo_mode := false

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

		log.info(game_info)

		if game_info.hidden {
			continue
		}

		game_info.fullpath = strings.clone(entry.fullpath)

		// load model
		game_info.model = rl.LoadModel("assets/box_art_base.glb")
		game_info.texture = rl.LoadTexture(to_cstr("%s/box_art.png", entry.fullpath))
		game_info.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = game_info.texture // 0 is default material

		game_info.qr_img = rl.LoadTexture(to_cstr("%s/qr.png", entry.fullpath))
		game_info.aabb = rl.GetMeshBoundingBox(game_info.model.meshes[0])
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

move_dir :: proc(dir: int, reset_timer: bool = true) {
	if is_game_launched {
		return
	}

	currently_selected = (currently_selected + dir + len(g_games)) % len(g_games)
	move_camera_to_curr(reset_timer = reset_timer)
}
// `on_move_complete` is so bad please i need to rewrite this this is so bad
move_camera_to_curr :: proc(reset_timer: bool = true) {
	trg_pos := V3f{f32(currently_selected) * BOX_OFFSETS, 0.0, 0.0}

	if is_viewing_game_details {
		trg_pos.x -= 1.9
		trg_pos.y += 0.3
	}

	camera_target_position = V3f{trg_pos.x, trg_pos.y, 5}
	do_camera_move = true
	current_tab = .General

	if reset_timer do idle_timer = 0
	is_demo_mode = false
}

draw_basic_details :: proc(game: Game) {
	name := to_cstr(game.name)
	devs := to_cstr(strings.join(game.developers, ", ", context.temp_allocator))
	tags := to_cstr(strings.join(game.genres, ", ", context.temp_allocator))

	center := (rl.GetScreenWidth() / 2)

	y := la.floor(f32(rl.GetScreenHeight()) * .74)

	line_width := rl.MeasureTextEx(fonts["title"], name, 48, 2)
	rl.DrawTextEx(fonts["title"], name, {f32(center) - line_width.x / 2, y}, 48, 2, rl.WHITE)

	y += 50
	line_width = rl.MeasureTextEx(fonts["body"], devs, 24, 1)
	rl.DrawTextEx(fonts["body"], devs, {f32(center) - line_width.x / 2, y}, 24, 1, rl.WHITE)

	y += 32
	line_width = rl.MeasureTextEx(fonts["body_italic"], tags, 18, 1)
	rl.DrawTextEx(fonts["body_italic"], tags, {f32(center) - line_width.x / 2, y}, 18, 1, rl.WHITE)

	y += 32
	x := f32(center) - f32((32 / 2) * len(game.supported_controls))
	for c, i in game.supported_controls {
		tex := textures[INPUT_TEXTURES[c]]
		rl.DrawTexturePro(
			tex,
			rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)},
			rl.Rectangle{x + f32(i * 32), y, 32, 32},
			{},
			0,
			rl.WHITE,
		)
	}
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
	draw_button(
		text = "Launch >",
		bounds = rl.Rectangle{900 + padding * 2, y - padding - 64, 130, 54},
		on_click = proc() {
			_launch_game(g_games[currently_selected])
			move_camera_to_curr()
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
	draw_image_button(
		image = textures["itch"],
		alpha = {200, 255},
		bounds = itch_rec,
		on_click = proc() {
			is_showing_qr = true
		},
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

@(private = "file")
_launch_game :: proc(game: Game) {
	run_game_threaded(game)
	is_viewing_game_details = false

	rl.PlaySound(sounds["sfx_launch"])
}

draw_nav_buttons :: proc() {
	img := textures["left_chev"]
	y := f32(rl.GetScreenHeight() / 2 - img.height / 2)
	alpha: V2i = {20, 50}

	draw_image_button(
		image = textures["left_chev"],
		bounds = rl.Rectangle{20, y, 128, 128},
		alpha = alpha,
		on_click = proc() {
			move_dir(-1)
		},
	)

	right := f32(rl.GetScreenWidth() - 20 - img.width)
	draw_image_button(
		image = textures["right_chev"],
		bounds = rl.Rectangle{right, y, 128, 128},
		alpha = alpha,
		on_click = proc() {
			move_dir(1)
		},
	)
}

main :: proc() {
	launch_flags: Launch_Flags
	flags.parse(&launch_flags, os.args[1:], .Unix)

	// mac doesnt use app dir as working directory
	rl.ChangeDirectory(rl.GetApplicationDirectory())

	logger := log.create_console_logger()
	context.logger = logger

	rl_flags: rl.ConfigFlags = {.MSAA_4X_HINT, .VSYNC_HINT}
	w, h: i32 = 1600, 900
	//if launch_flags.fullscreen {
	//	rl_flags += {.FULLSCREEN_MODE}
	//	w = rl.GetMonitorWidth(0)
	//	h = rl.GetMonitorHeight(0)
	//}

	rl.SetConfigFlags(rl_flags)
	rl.InitWindow(w, h, TITLE)
	defer rl.CloseWindow()

	// force check which gamepad works
	for i in 0 ..< 10 {
		if rl.IsGamepadAvailable(i32(i)) {
			active_gamepad = i32(i)
			log.info("found gamepad:", active_gamepad)
			break
		}
	}

	rl.SetExitKey(.F10)

	rl.InitAudioDevice()
	load_sound("sfx_launch")

	// :font loading
	load_font("title")
	load_font("body", font_size = 48)
	load_font("body_italic", font_size = 48)
	rl.SetTextLineSpacing(16)

	load_texture("bg")
	load_texture("itch")

	// ui icons
	load_texture("left_chev")
	load_texture("right_chev")
	load_texture("keyboard")
	load_texture("mouse")
	load_texture("controller")

	load_all_games()

	game_camera = rl.Camera3D {
		up         = V3f{0.0, 1.0, 0.0},
		target     = camera_target_position,
		position   = V3f{0.0, 0.0, 5.0},
		fovy       = 45.0,
		projection = .PERSPECTIVE,
	}

	rl.SetTargetFPS(120)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&game_camera, .CUSTOM)

		if do_camera_move {
			dist := rl.Vector3Distance(game_camera.position, camera_target_position)
			if dist >= 0.01 {
				game_camera.position = la.lerp(
					game_camera.position,
					camera_target_position,
					19 * rl.GetFrameTime(),
				)
				game_camera.target = game_camera.position + V3f{0, 0, -1}
			} else {
				do_camera_move = false
			}
		}

		// :Update
		if !is_game_launched {
			if !is_showing_qr {
				if rl.IsKeyPressed(.A) ||
				   rl.IsKeyPressed(.LEFT) ||
				   rl.IsGamepadButtonPressed(active_gamepad, .LEFT_FACE_LEFT) {
					move_dir(-1)
				}
				if rl.IsKeyPressed(.D) ||
				   rl.IsKeyPressed(.RIGHT) ||
				   rl.IsGamepadButtonPressed(active_gamepad, .LEFT_FACE_RIGHT) {
					move_dir(1)
				}
				if rl.IsKeyPressed(.ENTER) ||
				   rl.IsGamepadButtonPressed(active_gamepad, .RIGHT_FACE_DOWN) {
					if !is_viewing_game_details {
						is_viewing_game_details = true
					} else {
						_launch_game(g_games[currently_selected])
					}
					move_camera_to_curr()
				}
			}

			if rl.IsKeyPressed(.ESCAPE) ||
			   rl.IsKeyPressed(.BACKSPACE) ||
			   rl.IsGamepadButtonPressed(active_gamepad, .RIGHT_FACE_RIGHT) ||
			   rl.IsMouseButtonPressed(.RIGHT) {
				if is_viewing_game_details {
					is_viewing_game_details = false
				}
				if is_showing_qr {
					is_showing_qr = false
				}
				move_camera_to_curr()
			}
		} else {
			wait_for_game_close()
		}

		ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), game_camera)

		// @TODO optimize this? this loops through ALL of the box arts
		// an optimization would be checking 3 models at a time (before, current, and next)
		for g, i in g_games {
			hit := rl.GetRayCollisionBox(ray, g.tr_aabb)
			if rl.IsMouseButtonPressed(.LEFT) && hit.hit {
				if !do_camera_move && currently_selected == i {
					is_viewing_game_details = true
				}
				currently_selected = i
				move_camera_to_curr()
				break
			}
		}

		idle_timer += rl.GetFrameTime()

		// :DEMO MODE
		if idle_timer > AFK_DEMO_THRESHOLD {
			if i32(idle_timer) % DEMO_SHIFT_DURATION == 0 &&
			   i32(idle_timer) != last_demo_shift_trigger {
				move_dir(1, false)
				is_demo_mode = true
				last_demo_shift_trigger = i32(idle_timer)
			}
		}

		if is_showing_qr && rl.IsMouseButtonPressed(.LEFT) {
			is_showing_qr = false
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
			!is_viewing_game_details ? "A,D / <,> - navigate\t\tEnter - view game\t\tF10 - quit" : "Enter - launch game\t\tEsc/Backspace - back to selection"

		if is_demo_mode {
			bottom_bar_text = "DEMO MODE! Press A,D or <-, -> to select a game"
		}

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

		rl.BeginMode3D(game_camera)
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

			pos := V3f{f32(i) * BOX_OFFSETS, 0.2, 0}

			// @TODO use lit shader with basic directional light?
			rl.DrawModelEx(game.model, pos, V3f{0, 1, 0}, game.rotation, V3f(1.0), rl.WHITE)

			game.tr_aabb = rl.BoundingBox {
				min = rl.Vector3Transform(game.aabb.min, rl.MatrixTranslate(pos.x, pos.y, pos.z)),
				max = rl.Vector3Transform(game.aabb.max, rl.MatrixTranslate(pos.x, pos.y, pos.z)),
			}
		}
		rl.EndMode3D()

		if len(g_games) > 0 {
			curr_game := g_games[currently_selected]
			if is_viewing_game_details {
				draw_complete_details(curr_game)
			} else {
				if !is_game_launched {
					draw_nav_buttons()
				}
				draw_basic_details(curr_game)
			}
		}

		// :draw qr
		if is_showing_qr {
			qr_box: f32 = 370
			qr_bounds := rl.Rectangle {
				f32(rl.GetScreenWidth() / 2) - qr_box / 2,
				f32(rl.GetScreenHeight() / 2) - qr_box / 2,
				qr_box,
				qr_box,
			}

			// dim bg
			rl.DrawRectangle(
				0,
				0,
				rl.GetScreenWidth(),
				rl.GetScreenHeight(),
				rl.Color{0, 0, 0, 200},
			)
			rl.DrawTexturePro(
				g_games[currently_selected].qr_img,
				{0, 0, 370, 370},
				qr_bounds,
				{},
				0,
				rl.WHITE,
			)

			dl_link := to_cstr(g_games[currently_selected].download_link)
			rl.DrawTextEx(
				fonts["body"],
				dl_link,
				{
					f32(rl.GetScreenWidth() / 2) -
					rl.MeasureTextEx(fonts["body"], dl_link, 32, 1).x / 2,
					f32(40),
				},
				32,
				1,
				rl.WHITE,
			)
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

	rl.CloseAudioDevice()

	free_all(context.temp_allocator)
}

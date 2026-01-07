package main
import "core:fmt"
import "core:log"
import la "core:math/linalg"
import "core:strings"

import rl "vendor:raylib"

g_config: Config

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

move_dir :: proc(dir: int) {
	if is_game_launched {
		return
	}

	currently_selected = (currently_selected + dir + len(g_games)) % len(g_games)
	move_camera_to_curr()
}

BOX_OFFSETS :: 4.0
move_camera_to_curr :: proc() {
	trg_pos := V3f{f32(currently_selected) * BOX_OFFSETS, 0.0, 0.0}

	if is_viewing_game_details {
		trg_pos.x -= 1.9
		trg_pos.y += 0.3
	}

	camera_target_position = V3f{trg_pos.x, trg_pos.y, 5}
	do_camera_move = true
	current_tab = .General // force back to main screen

	if is_demo_mode {
		idle_timer = 0
	}
	else {
		is_demo_mode = false
	}
}

draw_basic_details :: proc(game: Game) {
	center := (f32)(rl.GetScreenWidth() / 2)
	layout := layout_create(center, la.floor(f32(rl.GetScreenHeight()) * .74))

	layout_push_text(&layout, to_cstr(game.name), 48, "title", .Center)
	layout_push_text(&layout, to_cstr(strings.join(game.developers, ", ", context.temp_allocator)), 24, "body", .Center)
	layout_push_text(&layout, to_cstr(strings.join(game.genres, ", ", context.temp_allocator)), 18, "body_italic", .Center)

	x := f32(center) - f32((32 / 2) * len(game.supported_controls))
	for c, i in game.supported_controls {
		tex := textures[INPUT_TEXTURES[c]]
		rl.DrawTexturePro(
			tex,
			rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)},
			rl.Rectangle{x + f32(i * 32), layout.curr_y, 32, 32},
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
	y := la.floor(f32(rl.GetScreenHeight()) * 0.1)

	details_panel := layout_create(x,y)

	// Top info buttons
	{
		layout := layout_create(x, y, direction = .Horizontal)
		layout_push_sub_layout(&details_panel, &layout)
		if layout_push_text_button(&layout, text = "Info") {
			current_tab = .General
		}
		if layout_push_text_button(&layout, text = "Credits") {
			current_tab = .Credits
		}
		if layout_push_text_button(&layout, text = "Launch") {
			launch_game(g_games[currently_selected])
			move_camera_to_curr()
		}
	}

	{
		layout := layout_create(
					x = x, 
					y = y,
					background_color = {0,0,0, 50},
					padding = PANEL_DEFAULT_PADDING,
				)

		layout_push_sub_layout(&details_panel, &layout)

		// rl.DrawRectangleRounded(
		// 	rl.Rectangle{x - padding, y - padding, 900 + padding * 2, f32(rl.GetScreenHeight()) * 0.7},
		// 	0.05,
		// 	18,
		// 	{0, 0, 0, 50},
		// )

		// header
		// itch_rec := rl.Rectangle{x + 670, y, 740 * 0.3, 228 * 0.3}
		// if draw_image_button(
		// 	image = textures["itch"],
		// 	alpha = {200, 255},
		// 	bounds = itch_rec,
		// ) {
		// 	is_showing_qr = true
		// }

		name := to_cstr(game.name)
		devs := to_cstr(strings.join(game.developers, ", ", context.temp_allocator))
		layout_push_text( &layout, game.name, 52, "title", .Left)

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

		layout_update_rect(&layout)
	}
}

draw_nav_buttons :: proc() {
	img := textures["left_chev"]
	y := f32(rl.GetScreenHeight() / 2 - img.height / 2)
	alpha: V2i = {20, 50}

	if draw_image_button(
		image = textures["left_chev"],
		bounds = rl.Rectangle{20, y, 128, 128},
		alpha = alpha,
	) {
		move_dir(-1)
	}

	right := f32(rl.GetScreenWidth() - 20 - img.width)
	if draw_image_button(
		image = textures["right_chev"],
		bounds = rl.Rectangle{right, y, 128, 128},
		alpha = alpha,
	) {
		move_dir(1)
	}
}

main :: proc() {
	// mac doesnt use app dir as working directory
	rl.ChangeDirectory(rl.GetApplicationDirectory())

	init_config(&g_config)
	init_resources()

	logger := log.create_console_logger()
	context.logger = logger

	// init raylib
	rl.SetConfigFlags(g_config.rl_flags)
	rl.InitWindow(g_config.window_size.x, g_config.window_size.y, g_config.window_title)
	defer rl.CloseWindow()
	rl.SetExitKey(.F10)

	setup_gamepad()

	// :load resources
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
				if on_left_pressed() {
					move_dir(-1)
				}
				if on_right_pressed() {
					move_dir(1)
				}
				if on_submit_pressed() {
					if !is_viewing_game_details {
						is_viewing_game_details = true
					} else {
						launch_game(g_games[currently_selected])
					}
					move_camera_to_curr()
				}
			}

			if on_cancel_pressed() {
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
				is_demo_mode = true
				move_dir(1)
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

		rl.DrawTextEx(fonts["title"], g_config.window_title, {10, 10}, 24, 2, {255, 255, 255, 50})

		// :bottom bar
		bar_height := i32(72)
		bar_pos := V2f{0, f32(rl.GetScreenHeight() - bar_height)}
		rl.DrawRectangle(0, i32(bar_pos.y), rl.GetScreenWidth(), bar_height, {0, 0, 0, 180})

		// @TODO use sprites for this, use a spritesheet or use a font?
		bottom_bar_text: cstring =
			!is_viewing_game_details ? "A,D / <,> - navigate\t\tEnter - view game\t\tF10 - quit" : "Enter - launch game\t\tEsc/Backspace - back to selection"

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

	free_resources()
	free_all_games()
	destroy_game_runner()

	rl.CloseAudioDevice()

	free_all(context.temp_allocator)
}

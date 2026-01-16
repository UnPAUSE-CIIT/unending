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

	layout_push_text(&layout, game.name, 48, "title", .Center)
	layout_push_text(&layout, strings.join(game.developers, ", ", context.temp_allocator), 24, "body", .Center)
	layout_push_text(&layout, strings.join(game.genres, ", ", context.temp_allocator), 18, "body_italic", .Center)

	x := f32(center) - f32((32 / 2) * len(game.supported_controls))
	for c, i in game.supported_controls {
		tex := textures[INPUT_TEXTURES[c]]
		rl.DrawTexturePro(
			tex,
			rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)},
			rl.Rectangle{x + f32(i * 32), layout.curr.y, 32, 32},
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

	panel := layout_create( x, y )

	// Top info buttons
	{
		layout := layout_create( x, y, direction = .Horizontal )
		if layout_push_text_button( &layout, text = "Info" ) {
			current_tab = .General
		}
		if layout_push_text_button( &layout, text = "Credits" ) {
			current_tab = .Credits
		}
		if layout_push_text_button( &layout, text = "Launch" ) {
			launch_game( g_games[currently_selected] )
			move_camera_to_curr()
		}
		if layout_push_text_button( &layout, text = "View download link" ) {
			is_showing_qr = true
		}

		layout_append( &panel, &layout )
	}

	layout_push_space( &panel, 12 )

	{
		layout := layout_create(
					x = panel.curr.x, 
					y = panel.curr.y,
					max_width = 900,
				)

		// header
		{
			header := layout_create(
				x = layout.curr.x,
				y = layout.curr.y,
				max_width = 900,
			)
			layout_push_text( &header, game.name, 52, "title", .Left)
			layout_push_text( &header, strings.join(game.developers, ", ", context.temp_allocator), 18, "body_italic", .Left)

			layout_append( &layout, &header )
		}

		switch current_tab {
		case .General: {
			layout_push_text( &layout, game.description, 24, "body", .Left, wrapped = true )
			layout_push_text( &layout, strings.join(game.genres, ", ", context.temp_allocator), 24, "body_italic", .Left )
		}
		case .Credits:{
			rl.DrawTextEx(fonts["body_italic"], "Members", {x, y}, 32, 1, rl.WHITE)
			y += 32 + 18
			members := to_cstr(strings.join(game.members, "\n", context.temp_allocator))
			rl.DrawTextEx(fonts["body"], members, {x, y}, 24, 1, rl.WHITE)
		}
		}

		layout_append( &panel, &layout )
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

draw_bottom_bar :: proc() {
	win_size := get_window_size()

	bottom_nav_img: cstring = is_viewing_game_details ? "game_dt_bottom_nav" : "home_bottom_nav"
	draw_image(bottom_nav_img, V2f{0,0}, win_size)
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

	rl.InitAudioDevice()
	rl.SetExitKey(.F10)

	setup_gamepad()

	load_resources()
	load_all_games()

	rl.SetTextLineSpacing(16)
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
		draw_bottom_bar()

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
			qr_img := g_games[currently_selected].qr_img
			qr_box: f32 = 370.0
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
				qr_img,
				{0, 0, f32(qr_img.width), f32(qr_img.height)},
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

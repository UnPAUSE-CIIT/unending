package main

import "core:encoding/ini"
import "core:fmt"
import rl "vendor:raylib"
import "core:strconv"

Config :: struct {
	window_size: V2i,
	window_title: cstring,
	fullscreen: bool,

	app_version: string,
	rl_flags: rl.ConfigFlags,

	games_path: string,
}

init_config :: proc(c: ^Config) {
	conf, err, ok := ini.load_map_from_path("launch.ini", context.temp_allocator)
	assert(ok, fmt.tprintfln("Error loading config file: {}", err))

	c.app_version = conf["app"]["version"]
	c.games_path = conf["app"]["games_path"]

	if fs, ok := strconv.parse_bool(conf["window"]["fullscreen"]); ok {
		c.fullscreen = fs
	}

	if ww, ok := strconv.parse_int(conf["window"]["width"]); ok {
		c.window_size.x = i32(ww)
	}

	if wh, ok := strconv.parse_int(conf["window"]["height"]); ok {
		c.window_size.y = i32(wh)
	}

	c.window_title = fmt.caprintf("UnENDING {}", c.app_version)
	c.rl_flags = {.MSAA_4X_HINT, .VSYNC_HINT}

	c.window_size.x = 1600
	c.window_size.y = 900
	if c.fullscreen {
		c.rl_flags += {.FULLSCREEN_MODE}
		c.window_size.x = rl.GetMonitorWidth(0)
		c.window_size.y = rl.GetMonitorHeight(0)
	}

}

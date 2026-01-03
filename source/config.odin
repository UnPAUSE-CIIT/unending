package main

import "core:flags"
import "core:encoding/ini"
import rl "vendor:raylib"
import "core:os"

Config :: struct {
	app_version: string,
	window_size: V2i,
	window_title: cstring,
	rl_flags: rl.ConfigFlags,
}

Launch_Flags :: struct {
	fullscreen: bool,
}

init_config :: proc(conf: ^Config) {
	using conf

	window_title = "UnENDING"
	launch_flags: Launch_Flags
	flags.parse(&launch_flags, os.args[1:], .Unix)

	rl_flags = {.MSAA_4X_HINT, .VSYNC_HINT}

	window_size.x = 1600
	window_size.y = 900
	if launch_flags.fullscreen {
		rl_flags += {.FULLSCREEN_MODE}
		window_size.x = rl.GetMonitorWidth(0)
		window_size.y = rl.GetMonitorHeight(0)
	}
}

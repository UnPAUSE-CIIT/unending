package main

idle_timer: f32 = 0
last_demo_shift_trigger: i32 = -1
AFK_DEMO_THRESHOLD :: f32(30.0)
DEMO_SHIFT_DURATION :: 5
is_demo_mode := false


stop_demo_mode :: proc() {
	is_demo_mode = false
	idle_timer = 0
}

/*
    this file contains procs that starts a game and waits for it
    to close
*/
package main
import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:sync/chan"
import "core:thread"

is_game_launched: bool
launched_game_handle: os2.Process
game_wait_thread: ^thread.Thread
game_wait_channel: chan.Chan(bool)

@(private = "file")
_create_game_waiter_thread :: proc(p: os2.Process, close_chan: chan.Chan(bool, .Send)) {
	log.debug("waiting for game to close")
	state, err := os2.process_wait(p)
	assert(err == nil)

	log.info("[game runner] game has closed?", state.exited)
	chan.send(close_chan, state.exited)
}

// this runs on the main thread
wait_for_game_close :: proc() {
	game_closed_value, ok := chan.try_recv(game_wait_channel)
	if ok {
		set_window_focus(false)
		log.info("[game runner] requested game close:", game_closed_value)
		is_game_launched = !game_closed_value
		chan.close(game_wait_channel)
	}
}

run_game_threaded :: proc(game: Game) {
	game_path := fmt.tprintf("%s/%s", game.fullpath, game.game_file)
	log.debug("running game at ", game_path)

	if !os.exists(game_path) {
		log.errorf("[game runner] {} does not exist!", game.name)
		return
	}

	launch_cmd: []string

	when ODIN_OS == .Windows {
		launch_cmd = { game_path }
	} else when ODIN_OS == .Darwin {
		launch_cmd = { "open", game_path }
	} else {
		launch_cmd = { "umu-run", game_path }
	}

	process_handle, err := os2.process_start(
		os2.Process_Desc{command = launch_cmd, stdout = os2.stdout},
	)
	assert(err == nil, fmt.tprint("error running game:", err))
	launched_game_handle = process_handle
	is_game_launched = true


	game_wait_channel, _ = chan.create_unbuffered(chan.Chan(bool), context.allocator)
	// start wait thread
	game_wait_thread = thread.create_and_start_with_poly_data2(
		process_handle,
		chan.as_send(game_wait_channel),
		_create_game_waiter_thread,
	)

	set_window_focus(true)
}

destroy_game_runner :: proc() {
	if game_wait_thread != nil {
		err := os2.process_kill(launched_game_handle)
		assert(err == nil, "failed to close game!")

		thread.join(game_wait_thread)
		thread.destroy(game_wait_thread)
		game_wait_thread = nil
	}

	if !chan.is_closed(game_wait_channel) {
		chan.close(game_wait_channel)
		chan.destroy(game_wait_channel)
		game_wait_channel = {}
	}
}

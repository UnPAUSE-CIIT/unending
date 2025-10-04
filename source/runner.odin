/*
    this file contains procs that starts a game and waits for it
    to close
*/
package main
import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:sync"
import "core:sync/chan"
import "core:thread"

is_game_launched: bool
game_wait_thread: ^thread.Thread
game_wait_channel: chan.Chan(bool)

setup_game_runner :: proc() {
	game_wait_channel, _ = chan.create_unbuffered(chan.Chan(bool), context.allocator)
}

@(private = "file")
_create_game_waiter_thread :: proc(p: os2.Process, close_chan: chan.Chan(bool, .Send)) {
	fmt.println("waiting for game to close")
	state, err := os2.process_wait(p)
	assert(err == nil)

	fmt.println("[game runner] game has closed?", state.exited)
	chan.send(close_chan, state.exited)
}

// this runs on the main thread
wait_for_game_close :: proc() {
	game_closed_value, ok := chan.try_recv(game_wait_channel)
	if ok {
		fmt.println("[game runner] requested game close:", game_closed_value)
		is_game_launched = !game_closed_value
		chan.close(game_wait_channel)
	}
}

run_game_threaded :: proc(game: Game) {
	game_path := fmt.tprintf("%s/%s", game.fullpath, game.game_file)
	log.info("running game at ", game_path)

	if !os.exists(game_path) {
		log.errorf("[game runner] {} does not exist!", game.name)
		return
	}

	// @TODO run diff start process depending on OS
	process_handle, err := os2.process_start(
		os2.Process_Desc{command = {"umu-run", game_path}, stdout = os2.stdout},
	)
	assert(err == nil, fmt.tprint("error running game:", err))
	is_game_launched = true

	// start wait thread
	game_wait_thread = thread.create_and_start_with_poly_data2(
		process_handle,
		chan.as_send(game_wait_channel),
		_create_game_waiter_thread,
	)
}

destroy_game_runner :: proc() {
	chan.destroy(game_wait_channel)
	thread.destroy(game_wait_thread)
}

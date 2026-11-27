extends SceneTree
const Run = preload("res://proof/run_model.gd")
var count := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("exercise")

func capture(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/mesh-city-" + name + ".png")

func exercise() -> void:
	var game = load("res://proof_course.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	check(not game.active, "game waits for a deliberate start")
	check(game.coach_label.text.begins_with("SOLO"), "guide is named Solo")
	check(game.reduced_effects and game.effects_button.text == "Effects: low", "reduced-effects control works")
	game._toggle_effects()
	await capture("ready")
	game._start_run("demo")
	for i in 20:
		game._physics_process(1.0 / 60)
	var tick: int = game.run.ticks
	game._toggle_pause()
	game._physics_process(1.0 / 60)
	check(game.run.ticks == tick, "pause freezes recording and simulation time")
	game._toggle_pause()
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused, "losing focus pauses the run")
	game._toggle_pause()
	for i in 20000:
		if not game.active:
			break
		game._physics_process(1.0 / 60)
	check(game.finished and game.docked == game.orbs.size(), "full demo completes through gameplay")
	check(game.last_run.lane == "demo", "autopilot stays in demo lane")
	check(game.status_label.text == "LOCAL REPLAY MATCH", "completion reports local replay only")
	check(game.result_label.text.contains("NOT ISSUED"), "completion does not promise a Runtime signature")
	check(not game.replay_button.disabled and not game.export_button.disabled, "completed run unlocks replay and export")
	await capture("complete")
	var original := JSON.stringify(game.last_run)
	game._replay_last()
	for i in 20000:
		if not game.active:
			break
		game._physics_process(1.0 / 60)
	check(game.finished, "saved input playback finishes")
	check(JSON.stringify(game.last_run) == original, "playback leaves original evidence unchanged")
	game._export_run()
	check(FileAccess.file_exists("user://mesh-city-run.json"), "native export writes a run file")
	var exported = JSON.parse_string(FileAccess.get_file_as_string("user://mesh-city-run.json"))
	check(Run.verify(exported, game.world, game.build_id).ok, "exported file independently replays")
	game._start_run("human")
	check(game.run.ticks == 0 and game.docked == 0, "new run resets score and input log")
	check(not game.autopilot and game.run_lane == "human", "human run disables demo driver")
	game.last_run = {}
	game._load_last_run()
	check(not game.last_run.is_empty(), "saved completion recovers after memory reset")
	game.last_run.result.time_ms = 1
	game.active = false
	game._replay_last()
	check(not game.active and game.status_label.text.contains("checksum"), "tampered saved run cannot start replay")
	game.queue_free()
	await process_frame
	print("GAME FLOW: %d checks, %d failures" % [count, failures])
	quit(1 if failures else 0)

extends SceneTree
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	var city = load("res://main.tscn").instantiate()
	root.add_child(city)
	current_scene = city
	await process_frame
	var portal = city.find_child("ProofCourseButton", true, false)
	check(portal is Button, "existing city exposes the proof course")
	check(city.SOLO_TEXTURE.get_width() > 0, "existing Solo character remains loaded")
	portal.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://proof_course.tscn", "city opens the course in the same game")
	var course = current_scene
	course._start_run("demo")
	course._leave_course()
	var confirmation: ConfirmationDialog
	for child in course.get_children():
		if child is ConfirmationDialog:
			confirmation = child
	check(confirmation != null and confirmation.visible and course.paused, "leaving an active run asks before discarding it")
	confirmation.canceled.emit()
	course.active = false
	course._leave_course()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://main.tscn", "course returns to the preserved city")
	print("PORTAL FLOW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

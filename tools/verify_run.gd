extends SceneTree
const Run = preload("res://proof/run_model.gd")
const World = preload("res://proof/run_world.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		print("Usage: godot --headless --path . --script tools/verify_run.gd -- run.json")
		quit(2)
		return
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null or file.get_length() > Run.MAX_BYTES:
		print("REJECTED: missing or oversized run file")
		quit(1)
		return
	var doc = JSON.parse_string(file.get_as_text())
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/repos.json"))
	var build = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
	if not data is Dictionary or not build is Dictionary:
		print("REJECTED: expected build and snapshot are unavailable")
		quit(1)
		return
	var check := Run.verify(doc, World.from_repos(data.get("repos", [])), build.get("id", ""))
	print(JSON.stringify(check))
	quit(0 if check.ok else 1)

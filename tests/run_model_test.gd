extends SceneTree
const Run = preload("res://proof/run_model.gd")
const World = preload("res://proof/run_world.gd")
var count := 0
var failures := 0
var points := [{"id": "Meshtool/a", "x": 1000, "z": 6000, "radius": 100},
	{"id": "Meshtool/b", "x": 2000, "z": 6000, "radius": 100}]

func check(ok: bool, name: String) -> void:
	count += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + name)
	else:
		print("PASS: " + name)

func resign(doc: Dictionary) -> Dictionary:
	doc.erase("checksum")
	doc.checksum = Run.digest(doc)
	return doc

func _initialize() -> void:
	var run = Run.new(points)
	for i in 12:
		run.step(1, 0)
	var doc: Dictionary = run.document("test-build", "human")
	check(run.complete(), "real inputs finish two checkpoints")
	check(run.visits == ["Meshtool/a", "Meshtool/b"], "each checkpoint scored once in order")
	check(run.result().time_ms == 200, "fixed simulation time")
	check(Run.verify(doc, points, "test-build").ok, "recorded run replays")
	var roundtrip = JSON.parse_string(JSON.stringify(doc, "  "))
	check(Run.verify(roundtrip, points, "test-build").ok, "JSON export and restore replay identically")
	check(not Run.verify(doc, points, "other-build").ok, "wrong build rejected")
	var changed_world := points.duplicate(true)
	changed_world[0].x += 100
	check(not Run.verify(doc, changed_world, "test-build").ok, "changed repo layout rejected")
	var tampered := doc.duplicate(true)
	tampered.result.time_ms = 1
	check(not Run.verify(tampered, points, "test-build").ok, "changed time checksum rejected")
	check(not Run.verify(resign(tampered), points, "test-build").ok, "forged result with recomputed checksum rejected")
	tampered = doc.duplicate(true)
	tampered.inputs[0] = [-1, 0]
	check(not Run.verify(resign(tampered), points, "test-build").ok, "altered inputs cannot reproduce claimed finish")
	tampered = doc.duplicate(true)
	tampered.inputs.append([0, 0])
	check(not Run.verify(resign(tampered), points, "test-build").ok, "post-finish input rejected")
	tampered = doc.duplicate(true)
	tampered.inputs = [[0, 0]]
	check(not Run.verify(resign(tampered), points, "test-build").ok, "incomplete run rejected")
	for axis in [2, -2, 0.5, "1", true, null, INF, NAN]:
		tampered = doc.duplicate(true)
		tampered.inputs[0] = [axis, 0]
		check(not Run.verify(tampered, points, "test-build").ok, "invalid axis rejected: " + str(axis))
	tampered = doc.duplicate(true)
	tampered.inputs = [null]
	check(not Run.verify(tampered, points, "test-build").ok, "malformed movement rejected")
	tampered = doc.duplicate(true)
	tampered.inputs = []
	tampered.inputs.resize(Run.MAX_TICKS + 1)
	check(not Run.verify(tampered, points, "test-build").ok, "oversized input log rejected before replay")
	check(not Run.verify([], points, "test-build").ok, "malformed root rejected")
	tampered = doc.duplicate(true)
	tampered.result = {"nested": [{"unexpected": [1, 2, 3]}]}
	check(not Run.verify(tampered, points, "test-build").ok, "malformed result rejected before hashing")
	tampered = doc.duplicate(true)
	tampered.result.position_mm = [true, 0]
	check(not Run.verify(tampered, points, "test-build").ok, "boolean result position rejected")
	tampered = doc.duplicate(true)
	tampered.runtime_verified = true
	check(not Run.verify(tampered, points, "test-build").ok, "injected verification claim rejected")
	check(not Run.verify(doc, points, "test-build").runtime_verified, "local match never asserts runtime verification")
	check(not Run.new([]).complete(), "empty world cannot finish")
	run.step(1, 0)
	check(run.ticks == 12, "no scoring after finish")
	var diagonal = Run.new(points)
	diagonal.step(1, 1)
	check(diagonal.position == Vector2i(118, 6118), "diagonal speed is fixed")
	var edge = Run.new(points)
	for i in 400:
		edge.step(-1, 0)
	check(edge.position.x == -Run.LIMIT, "world bounds enforced")
	var repos := [{"org": "Meshtool", "name": "z"}, {"org": "Meshtool", "name": "a"}]
	var layout := World.from_repos(repos)
	repos.reverse()
	check(layout == World.from_repos(repos), "API order cannot change stable layout")
	# Exercise all current repos through the same integer inputs used by the demo.
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/repos.json"))
	var real_world := World.from_repos(data.repos)
	var full = Run.new(real_world)
	for i in 20000:
		if full.complete():
			break
		for point in real_world:
			if point.id not in full.visits:
				full.step(signi(int(point.x) - full.position.x), signi(int(point.z) - full.position.y))
				break
	check(full.complete(), "full repo snapshot is reachable")
	check(Run.verify(full.document("test-build", "demo"), real_world, "test-build").ok, "full snapshot demo replays")
	print("RUN MODEL: %d checks, %d failures" % [count, failures])
	quit(1 if failures else 0)

extends Node3D
## MESH CITY: PROOF RUN — the Meshtool estate as a deep-sea field of seat orbs.
## Same visual language as runtime.meshtool.ai / meshtool.ai: near-black sea,
## lava rising, crisp particle orbs, clean type on quiet cards.
##
## Every public repo is an orb. Size = repo size. Brightness = how fresh the last push is.
## Swirl = how busy it was this week. Turquoise = Meshtool, gold = RightOnPar.
## The runtime hangs in the middle. You are your own seat orb: fly to each repo to dock.

const SOLO_TEXTURE = preload("res://assets/solo/solo-v1.png")
const UI_FONT = preload("res://assets/fonts/InterVariable.ttf")
const SPARK = preload("res://assets/particles/spark.png")
const Run = preload("res://proof/run_model.gd")
const World = preload("res://proof/run_world.gd")

const DATA_PATH := "res://data/repos.json"
const DESK_PATH := "res://data/desk.json"

const SEA := Color(0.012, 0.016, 0.024)
const TURQ := Color(0.13, 0.83, 0.93)     # #22d3ee
const GOLD := Color(1.0, 0.76, 0.28)
const VIOLET := Color(0.62, 0.48, 1.0)
const LAVA := Color(1.0, 0.45, 0.16)
const INK := Color(0.93, 0.95, 0.97)
const MUTED := Color(0.55, 0.6, 0.66)
const CARD_BG := Color(0.018, 0.032, 0.045, 0.98)

const SPEED := 10.0
const DOCK_RADIUS := 4.0
const HEART := Vector3(0, 9, 0)

var player: Node3D
var cam: Camera3D
var orbs: Array = []        # {node, repo, pos, light, visited, radius}
var docked := 0
var near = null
var autopilot := "--demo" in OS.get_cmdline_user_args()
var finished := false
var data_generated := ""
var desk := {}

var ui_count: Label
var ui_live: Label
var card: PanelContainer
var card_kicker: Label
var card_title: Label
var card_body: Label
var done_card: PanelContainer
var run: RefCounted
var world: Array = []
var build_id := ""
var active := false
var paused := false
var replaying := false
var replay_cursor := 0
var last_run: Dictionary = {}
var run_lane := "human"
var status_label: Label
var clock_label: Label
var coach_label: Label
var result_label: Label
var replay_button: Button
var export_button: Button
var pause_button: Button
var touch_input := Vector2i.ZERO
var reduced_effects := true
var effects_button: Button
var smoke := "--smoke" in OS.get_cmdline_user_args()


func _ready() -> void:
	_setup_input()
	_setup_world()
	var repos := _load_repos()
	world = World.from_repos(repos)
	var build = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
	if build is Dictionary:
		build_id = build.get("id", "")
	run = Run.new(world)
	_build_field(repos)
	_build_heart()
	_build_player()
	_load_desk()
	_build_ui()
	ui_live.text = "SNAPSHOT  ·  %d REPOS  ·  UPDATED %s" % [orbs.size(), _ago(data_generated).to_upper()]
	_load_last_run()
	reduced_effects = false
	_toggle_effects()
	if world.is_empty() or build_id.is_empty():
		status_label.text = "Run unavailable: build data is missing."
	elif autopilot:
		_start_run("demo")
	print("=== Mesh City ready: %d repos ===" % orbs.size())


# ---------- world ----------

func _setup_input() -> void:
	var binds := {
		"mv_left": [KEY_A, KEY_LEFT], "mv_right": [KEY_D, KEY_RIGHT],
		"mv_fwd": [KEY_W, KEY_UP], "mv_back": [KEY_S, KEY_DOWN],
		"open_repo": [KEY_E], "pause_run": [KEY_P, KEY_ESCAPE],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SEA
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.16)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = SEA
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# the big letters in the deep, like the sites' background word
	var word := Label3D.new()
	word.text = "MESHTOOL"
	word.font_size = 400
	word.pixel_size = 0.05
	word.modulate = Color(1, 1, 1, 0.045)
	word.outline_size = 0
	word.position = Vector3(0, 16, -75)
	add_child(word)

	# lava rising slowly out of the deep
	var lava := CPUParticles3D.new()
	lava.amount = 48
	lava.lifetime = 14.0
	lava.preprocess = 14.0
	lava.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	lava.emission_box_extents = Vector3(70, 2, 70)
	lava.position.y = -6
	lava.direction = Vector3.UP
	lava.spread = 6.0
	lava.gravity = Vector3(0, 0.25, 0)
	lava.initial_velocity_min = 0.4
	lava.initial_velocity_max = 1.1
	lava.scale_amount_min = 0.4
	lava.scale_amount_max = 1.3
	lava.scale_amount_curve = _twinkle_curve()
	var lm := SphereMesh.new()
	lm.radius = 0.09
	lm.height = 0.18
	lm.material = _glow(LAVA, 2.2)
	lava.mesh = lm
	lava.add_to_group("ambient_effects")
	add_child(lava)


# ---------- data ----------

func _load_repos() -> Array:
	if not FileAccess.file_exists(DATA_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	data_generated = parsed.get("generated", "")
	return parsed.get("repos", [])


func _load_desk() -> void:
	if not FileAccess.file_exists(DESK_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DESK_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		desk = parsed


func _days_since(iso: String) -> float:
	if iso.is_empty():
		return 999.0
	var t := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	return max(0.0, (Time.get_unix_time_from_system() - t) / 86400.0)


func _ago(iso: String) -> String:
	var d := _days_since(iso)
	if d >= 999.0:
		return "?"
	if d < 1.0 / 24.0:
		return "just now"
	if d < 1.0:
		return "%dh ago" % int(d * 24.0)
	return "%dd ago" % int(d)


# ---------- the field ----------

func _build_field(repos: Array) -> void:
	var lookup := {}
	for repo in repos:
		lookup["%s/%s" % [repo.get("org", ""), repo.get("name", "")]] = repo
	for point in world:
		var repo: Dictionary = lookup[point.id]
		var pos := Vector3(point.x / 1000.0, 2.2, point.z / 1000.0)
		_build_repo_orb(repo, pos, TURQ if repo.get("org", "") == "Meshtool" else GOLD)


func _build_repo_orb(repo: Dictionary, pos: Vector3, tint: Color) -> void:
	var fresh := clampf(1.0 - _days_since(repo.get("pushed", "")) / 21.0, 0.0, 1.0)
	var archived: bool = repo.get("archived", false)
	var commits := int(repo.get("effort", {}).get("commits_7d", 0))
	var radius := 0.8 + log(float(repo.get("size", 1)) + 1.0) * 0.22
	var color := MUTED if archived else tint
	var o := _particle_orb(color, radius, 0.35 + fresh * 0.65, clampf(commits / 10.0, 0.0, 1.0))
	o.position = pos
	add_child(o)

	var name := Label3D.new()
	name.text = repo.get("name", "?")
	name.font = UI_FONT
	name.font_size = 30
	name.fixed_size = true
	name.pixel_size = 0.0007
	name.outline_size = 6
	name.outline_modulate = Color(0, 0, 0, 0.8)
	name.modulate = Color(INK, 0.9)
	name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name.position = pos + Vector3(0, -radius - 0.6, 0)
	add_child(name)

	orbs.append({"node": o, "repo": repo, "pos": pos, "light": o.get_node("light"),
		"visited": false, "radius": radius, "color": color})


func _build_heart() -> void:
	var h := _particle_orb(GOLD, 3.2, 1.0, 0.6, 900)
	h.position = HEART
	add_child(h)
	var l := Label3D.new()
	l.font = UI_FONT
	l.text = "runtime"
	l.font_size = 40
	l.fixed_size = true
	l.pixel_size = 0.0008
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.modulate = GOLD
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = HEART + Vector3(0, -4.2, 0)
	add_child(l)
	# faint threads: every repo answers to the runtime
	for ob in orbs:
		var a: Vector3 = ob.pos
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02, 0.02, a.distance_to(HEART))
		f.mesh = bm
		var m := _glow(ob.color, 0.6)
		m.albedo_color.a = 0.18
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		f.material_override = m
		add_child(f)
		f.position = (a + HEART) * 0.5
		f.look_at(HEART, Vector3.UP)


func _particle_orb(color: Color, radius: float, brightness: float, busy: float, amount := 0) -> Node3D:
	## The seat-orb look: a cloud of crisp points around a bright core.
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = radius * 0.09
	cm.radial_segments = 16
	cm.rings = 8
	cm.height = radius * 0.16
	core.mesh = cm
	core.material_override = _glow(color.lerp(Color.WHITE, 0.5), 1.5 + brightness * 2.0)
	root.add_child(core)

	var n := mini(amount, 240) if amount > 0 else int(48 + radius * 28)
	for layer in 2:  # color cloud + a few white sparks
		var p := CPUParticles3D.new()
		p.amount = n if layer == 0 else maxi(12, n / 5)
		p.lifetime = 3.0
		p.preprocess = 3.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.12
		p.tangential_accel_min = busy * 0.6
		p.tangential_accel_max = busy * 1.4
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		p.scale_amount_curve = _twinkle_curve()
		# Two-triangle billboards borrow Godot's MIT-licensed spark texture.
		# Keep transparent particles tiny and bounded for WebGL fill-rate.
		var dm := QuadMesh.new()
		dm.size = Vector2.ONE * (0.1 if layer == 0 else 0.06)
		var c := color if layer == 0 else Color(1, 0.97, 0.9)
		var material := _glow(c, 1.0)
		material.albedo_texture = SPARK
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		dm.material = material
		p.mesh = dm
		p.add_to_group("ambient_effects")
		root.add_child(p)

	var halo := Sprite3D.new()
	halo.texture = SPARK
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.modulate = Color(color, 0.24)
	halo.pixel_size = radius * 0.045
	root.add_child(halo)

	var light := OmniLight3D.new()
	light.name = "light"
	light.light_color = color
	light.light_energy = 0.4 + brightness * 1.4
	light.omni_range = radius * 4.0
	root.add_child(light)
	return root


func _twinkle_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(0.75, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


# ---------- you ----------

func _build_player() -> void:
	player = _particle_orb(TURQ.lerp(Color.WHITE, 0.25), 0.45, 1.0, 0.8, 160)
	player.position = Vector3(0, 2.2, 6)
	add_child(player)
	var beacon := Label3D.new()
	beacon.text = "YOU"
	beacon.font = UI_FONT
	beacon.font_size = 28
	beacon.pixel_size = 0.009
	beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon.modulate = TURQ
	beacon.position.y = 0.95
	player.add_child(beacon)
	cam = Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.position = player.position + Vector3(0, 8, 16)
	cam.look_at(player.position)


func _physics_process(_delta: float) -> void:
	if not active or paused:
		return
	var direction := Vector2i.ZERO
	if replaying:
		if replay_cursor >= last_run.inputs.size():
			return
		var sample: Array = last_run.inputs[replay_cursor]
		direction = Vector2i(int(sample[0]), int(sample[1]))
		replay_cursor += 1
	elif autopilot:
		for point in world:
			if point.id not in run.visits:
				direction = Vector2i(signi(int(point.x) - run.position.x), signi(int(point.z) - run.position.y))
				break
	else:
		var keys := Input.get_vector("mv_left", "mv_right", "mv_fwd", "mv_back")
		direction = Vector2i(signi(int(round(keys.x))), signi(int(round(keys.y))))
		if touch_input != Vector2i.ZERO:
			direction = touch_input
	run.step(direction.x, direction.y)
	player.position = Vector3(run.position.x / 1000.0, 2.2, run.position.y / 1000.0)
	for i in orbs.size():
		var ob: Dictionary = orbs[i]
		if not ob.visited and world[i].id in run.visits:
			ob.visited = true
			ob.light.light_energy *= 2.2
			docked += 1
			coach_label.text = "SOLO  ·  Docked %s.\n%s" % [ob.repo.get("name", "repo"), _next_hint()]
	ui_count.text = "Docked  %d / %d" % [docked, orbs.size()]
	clock_label.text = "%06.2fs  ·  %s" % [run.ticks / 60.0, "REPLAY" if replaying else run_lane.to_upper()]
	if run.complete():
		_finish_run()
	elif run.ticks >= Run.MAX_TICKS:
		active = false
		status_label.text = "30-minute run limit reached. Start a new run."
		coach_label.text = "SOLO  ·  No completed run to verify."


func _next_hint() -> String:
	for point in world:
		if point.id not in run.visits:
			return "Next: " + String(point.id).get_slice("/", 1)
	return "Every repo docked. Checking the recorded inputs."


func _start_run(lane: String) -> void:
	if world.is_empty() or build_id.is_empty():
		return
	_rewind()
	run_lane = lane
	autopilot = lane == "demo"
	replaying = false
	active = true
	status_label.text = "Recording your route · %s run" % lane
	coach_label.text = "SOLO  ·  Dock every glowing repo.\n" + _next_hint()


func _rewind() -> void:
	run = Run.new(world)
	docked = 0
	finished = false
	paused = false
	touch_input = Vector2i.ZERO
	pause_button.text = "Pause"
	player.position = Vector3(0, 2.2, 6)
	for ob in orbs:
		if ob.visited:
			ob.light.light_energy /= 2.2
		ob.visited = false
	done_card.visible = false
	ui_count.text = "Docked  0 / %d" % orbs.size()


func _finish_run() -> void:
	active = false
	finished = true
	var doc: Dictionary = last_run if replaying else run.document(build_id, run_lane)
	var check := Run.verify(doc, world, build_id)
	var saved := true
	if check.ok and not replaying:
		last_run = doc
		var file := FileAccess.open("user://last-run.json", FileAccess.WRITE)
		saved = file != null
		if saved:
			file.store_string(JSON.stringify(doc))
	status_label.text = "LOCAL REPLAY MATCH" if check.ok else "REPLAY REJECTED"
	coach_label.text = "SOLO  ·  " + check.message
	result_label.text = ("Every repo docked in %.2fs.\n\nLocal replay: MATCH\nRuntime signature: NOT ISSUED\n\nExport the run or watch the same route again." % (run.ticks / 60.0)) if check.ok else check.message
	if not saved:
		result_label.text += "\nLocal save unavailable. Export before leaving."
	done_card.visible = true
	replay_button.disabled = not check.ok
	export_button.disabled = not check.ok
	print("=== ALL DOCKED · %s · %d ticks ===" % [check.status, run.ticks])
	if smoke:
		if check.ok:
			var file := FileAccess.open("user://smoke-run.json", FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(doc))
		get_tree().quit(0 if check.ok else 1)


func _replay_last() -> void:
	var check := Run.verify(last_run, world, build_id)
	if not check.ok:
		status_label.text = check.message
		return
	_rewind()
	replaying = true
	replay_cursor = 0
	active = true
	autopilot = false
	status_label.text = "Replaying the saved inputs · local check only"


func _export_run() -> void:
	var check := Run.verify(last_run, world, build_id)
	if not check.ok:
		status_label.text = check.message
		return
	var content := JSON.stringify(last_run, "  ").to_utf8_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(content, "mesh-city-run.json", "application/json")
		status_label.text = "Run download requested · local evidence, unsigned"
	else:
		var file := FileAccess.open("user://mesh-city-run.json", FileAccess.WRITE)
		if file:
			file.store_buffer(content)
			status_label.text = "Exported: " + ProjectSettings.globalize_path("user://mesh-city-run.json")
		else:
			status_label.text = "Export failed. Local storage is unavailable."


func _load_last_run() -> void:
	var file := FileAccess.open("user://last-run.json", FileAccess.READ)
	if file == null or file.get_length() > Run.MAX_BYTES:
		return
	var doc = JSON.parse_string(file.get_as_text())
	var check := Run.verify(doc, world, build_id)
	if check.ok:
		last_run = doc
		replay_button.disabled = false
		export_button.disabled = false
		status_label.text = "Previous run recovered · local replay matched"
	else:
		status_label.text = "Previous run unavailable for this build. Start a new run."


func _toggle_pause() -> void:
	if not active:
		return
	paused = not paused
	touch_input = Vector2i.ZERO
	pause_button.text = "Resume" if paused else "Pause"
	status_label.text = "Paused · simulation clock stopped" if paused else "Replaying inputs" if replaying else "Recording inputs"


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for ob in orbs:
		var n: Node3D = ob.node
		n.position.y = ob.pos.y + sin(t * 0.8 + ob.pos.x) * 0.25
		n.rotate_y(delta * 0.15)
	var target := player.position + Vector3(0, 8, 16)
	cam.position = cam.position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	cam.look_at(player.position + Vector3(0, 1.2, 0))
	_update_near()


func _update_near() -> void:
	var best = null
	var best_d := DOCK_RADIUS
	for ob in orbs:
		var d: float = (ob.pos - player.position).length() - ob.radius
		if d < best_d:
			best_d = d
			best = ob
	near = best
	if best == null:
		card.visible = false
		return
	_fill_card(best.repo)
	card.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_run"):
		_toggle_pause()
	if event.is_action_pressed("open_repo") and near != null:
		var url: String = near.repo.get("url", "")
		if url.begins_with("https://github.com/"):
			if active and not paused:
				_toggle_pause()
			OS.shell_open(url)


# ---------- UI: quiet cards, like the sites ----------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var brand := _label("meshtool", 22, INK)
	brand.position = Vector2(24, 18)
	ui.add_child(brand)
	var sub := _label("/  proof course", 22, MUTED)
	sub.position = Vector2(128, 18)
	ui.add_child(sub)
	ui_live = _kicker("", TURQ)
	ui_live.position = Vector2(24, 52)
	ui.add_child(ui_live)

	effects_button = _button("Effects: full", _toggle_effects)
	effects_button.anchor_left = 1.0
	effects_button.anchor_right = 1.0
	effects_button.offset_left = -330
	effects_button.offset_right = -206
	effects_button.offset_top = 20
	ui.add_child(effects_button)

	var pill := _card(Color(1, 1, 1, 0.1))
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.offset_left = -190
	pill.offset_right = -24
	pill.offset_top = 18
	ui_count = _label("Docked  0 / %d" % orbs.size(), 16, INK)
	ui_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(ui_count)
	ui.add_child(pill)

	card = _card(Color(TURQ, 0.35))
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -404
	card.offset_right = -24
	card.offset_top = 80
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card_kicker = _kicker("", TURQ)
	card_title = _label("", 24, INK)
	card_body = _label("", 15, MUTED)
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_body.custom_minimum_size = Vector2(340, 0)
	vb.add_child(card_kicker)
	vb.add_child(card_title)
	vb.add_child(card_body)
	card.add_child(vb)
	card.visible = false
	ui.add_child(card)

	if not desk.is_empty():
		var dc := _card(Color(VIOLET, 0.35))
		dc.anchor_top = 1.0
		dc.anchor_bottom = 1.0
		dc.offset_left = 24
		dc.offset_top = -132
		dc.offset_bottom = -24
		var dv := VBoxContainer.new()
		dv.add_theme_constant_override("separation", 6)
		dv.add_child(_kicker("DEVDESK  ·  SNAPSHOT", VIOLET))
		dv.add_child(_label("%d on the desk" % int(desk.get("open", 0)), 20, INK))
		dv.add_child(_label("%d claimed  ·  %d waiting 2+ days" % [
			int(desk.get("claimed", 0)), int(desk.get("stale_48h", 0))], 14, MUTED))
		dc.add_child(dv)
		ui.add_child(dc)

	var guide := _card(Color(TURQ, 0.3))
	guide.position = Vector2(24, 88)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 10)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	var portrait := TextureRect.new()
	portrait.texture = SOLO_TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(52, 64)
	heading.add_child(portrait)
	heading.add_child(_kicker("SOLO  /  PROOF COURSE", GOLD))
	gv.add_child(heading)
	coach_label = _label("SOLO  ·  Follow the lights. Dock every repo.\nFinish your route, then replay the proof.", 15, INK)
	coach_label.custom_minimum_size = Vector2(340, 0)
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	gv.add_child(coach_label)
	clock_label = _label("00.00s  ·  READY", 24, TURQ)
	gv.add_child(clock_label)
	var row := HBoxContainer.new()
	row.add_child(_button("Start run", func(): _start_run("human")))
	row.add_child(_button("Watch demo", func(): _start_run("demo")))
	pause_button = _button("Pause", _toggle_pause)
	row.add_child(pause_button)
	gv.add_child(row)
	var row2 := HBoxContainer.new()
	replay_button = _button("Replay last", _replay_last)
	export_button = _button("Export run", _export_run)
	replay_button.disabled = true
	export_button.disabled = true
	row2.add_child(replay_button)
	row2.add_child(export_button)
	row2.add_child(_button("Back to city", _leave_course))
	gv.add_child(row2)
	status_label = _label("Ready · Runtime verification is not connected", 13, MUTED)
	status_label.custom_minimum_size = Vector2(340, 0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	gv.add_child(status_label)
	gv.add_child(_label("WASD / arrows  ·  P pause  ·  E open repo", 13, MUTED))
	guide.add_child(gv)
	ui.add_child(guide)

	# Pointer controls also work on touch devices; release cancels held movement.
	var pad := HBoxContainer.new()
	pad.anchor_left = 1.0
	pad.anchor_right = 1.0
	pad.anchor_top = 1.0
	pad.anchor_bottom = 1.0
	pad.offset_left = -292
	pad.offset_right = -24
	pad.offset_top = -76
	pad.offset_bottom = -24
	for entry in [["←", Vector2i(-1, 0)], ["↑", Vector2i(0, -1)], ["↓", Vector2i(0, 1)], ["→", Vector2i(1, 0)]]:
		var button := _button(entry[0], func(): pass)
		button.custom_minimum_size = Vector2(60, 48)
		var direction: Vector2i = entry[1]
		button.button_down.connect(func(): touch_input = direction)
		button.button_up.connect(func(): touch_input = Vector2i.ZERO)
		button.mouse_exited.connect(func(): touch_input = Vector2i.ZERO)
		pad.add_child(button)
	ui.add_child(pad)

	done_card = _card(Color(GOLD, 0.5))
	done_card.set_anchors_preset(Control.PRESET_CENTER)
	done_card.offset_left = -210
	done_card.offset_top = -20
	done_card.offset_right = 210
	var dvb := VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 10)
	dvb.add_child(_kicker("RUN COMPLETE  ·  LOCAL EVIDENCE", GOLD))
	result_label = _label("", 20, INK)
	result_label.custom_minimum_size = Vector2(380, 0)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dvb.add_child(result_label)
	dvb.add_child(_button("Close result", func(): done_card.visible = false))
	done_card.add_child(dvb)
	done_card.visible = false
	ui.add_child(done_card)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(7)
		style.set_border_width_all(1)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.bg_color = Color(0.04, 0.09, 0.12)
		style.border_color = Color(TURQ, 0.22)
		if text == "Start run" and state != "disabled":
			style.bg_color = Color(0.05, 0.45, 0.5)
			style.border_color = Color(TURQ, 0.8)
		if state in ["hover", "focus"]:
			style.border_color = TURQ
		if state == "pressed":
			style.bg_color = Color(0.04, 0.3, 0.34)
		if state == "disabled":
			style.bg_color.a = 0.4
			style.border_color.a = 0.08
		button.add_theme_stylebox_override(state, style)
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	return button


func _fill_card(repo: Dictionary) -> void:
	var org: String = repo.get("org", "")
	var accent := TURQ if org == "Meshtool" else GOLD
	card_kicker.text = "REPO  ·  %s" % org.to_upper()
	card_kicker.add_theme_color_override("font_color", accent)
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
	sb.border_color = Color(accent, 0.35)
	card_title.text = repo.get("name", "")
	var lines := []
	var desc: String = repo.get("desc", "")
	if desc != "":
		lines.append(desc)
	var lang: String = repo.get("lang", "")
	lines.append("%s  ·  pushed %s" % [lang if lang != "" else "—", _ago(repo.get("pushed", ""))])
	var commit: String = repo.get("commit", "")
	if commit != "":
		lines.append("Last commit: %s" % commit)
	var ef: Dictionary = repo.get("effort", {})
	if not ef.is_empty():
		var who := []
		for b in ef.get("builders", {}):
			who.append("%s %d" % [b, int(ef.builders[b])])
		var ci: String = {"success": "CI passing", "failure": "CI failing"}.get(ef.get("ci", ""), "")
		var parts := ["%d commits this week" % int(ef.get("commits_7d", 0))]
		if not who.is_empty():
			parts.append(", ".join(PackedStringArray(who)))
		if ci != "":
			parts.append(ci)
		lines.append("  ·  ".join(PackedStringArray(parts)))
	var issues := int(repo.get("issues", 0))
	if issues > 0:
		lines.append("%d open issues / PRs" % issues)
	lines.append("Press E to open on GitHub")
	card_body.text = "\n".join(lines)


# ---------- helpers ----------

func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _kicker(text: String, color: Color) -> Label:
	var l := _label(text, 12, color)
	var fv := FontVariation.new()
	fv.base_font = UI_FONT
	fv.spacing_glyph = 2
	l.add_theme_font_override("font", fv)
	return l


func _card(border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _toggle_effects() -> void:
	reduced_effects = not reduced_effects
	for effect in get_tree().get_nodes_in_group("ambient_effects"):
		effect.visible = not reduced_effects
		effect.emitting = not reduced_effects
	effects_button.text = "Effects: low" if reduced_effects else "Effects: full"


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and not paused:
		_toggle_pause()


func _leave_course() -> void:
	if active:
		if not paused:
			_toggle_pause()
		var confirm := ConfirmationDialog.new()
		confirm.dialog_text = "Leave this unfinished run? Your last completed replay stays saved."
		confirm.confirmed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
		confirm.canceled.connect(func(): confirm.queue_free())
		add_child(confirm)
		confirm.popup_centered()
	else:
		get_tree().change_scene_to_file("res://main.tscn")

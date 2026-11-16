extends Node3D
## MESH CITY · GONZO RUN — a fever-dream drive down the repo strip.
## Ink splatter, acid neon, and a fever that climbs with every orb.
## Each public repo is a tower: height = size, glow = how recently it was pushed,
## orbs = open issues/PRs (+1 per repo). Collect every orb to sync the estate.
## Walk up to a tower to read its card; press E to open the repo.

const UI_FONT = preload("res://assets/fonts/InterVariable.ttf")
const RELEASE_ID := "solo-v1-20261115"
const SOLO_TEXTURE = preload("res://assets/solo/solo-v1.png")
const DATA_PATH := "res://data/repos.json"
const GOLD := Color(1.0, 0.78, 0.25)
const TURQ := Color(0.18, 0.95, 0.85)
const LAVA := Color(1.0, 0.42, 0.12)
const DIM := Color(0.35, 0.35, 0.4)
const ACID := Color(1.0, 0.12, 0.62)
const INFO_RADIUS := 4.5
const SPEED := 9.0
const JUMP := 9.0
const GRAVITY := 24.0

var player: CharacterBody3D
var cam: Camera3D
var towers: Array = []   # {node, repo, pos}
var tickers: Array = []  # {label, text, off} — each tower scrolls its own last commit
var ticker_clock := 0.0
var self_repo := ""      # "org/name" of this game's own repo (from repos.json)
var self_pos = null
var data_generated := ""
const HEART := Vector3(0, 16, 0)  # the runtime: every repo's receipts flow here
var pulses: Array = []   # {node, from, to, t, speed}

# ---- the effort layer: who is building, and how hard ----
const DESK_PATH := "res://data/desk.json"
const BUILDER_COLORS := {
	"Claude": Color(1.0, 0.55, 0.35), "Copilot": Color(0.7, 0.45, 1.0),
	"Codex": Color(0.6, 1.0, 0.75), "dependabot": Color(0.45, 0.5, 0.55),
	"github-actions": Color(0.45, 0.5, 0.55),
}
var moths: Array = []    # {node, path:[Vector3], seg, t, speed, wobble}
var bricks: Array = []   # {node, y, delay}
var rings: Array = []    # {node, base, phase}
var storms: Array = []   # {light, phase}
var lanterns: Array = [] # {node, r, ang, h, speed, stale}
var week := {"commits": 0, "merged": 0, "builders": {}}
var desk := {}
var hud_effort: Label
var orbs: Array = []     # Area3D
var total_orbs := 0
var collected := 0
var elapsed := 0.0
var finished := false
var near_repo = null
var calm_motion := true
var motion_button: Button
var autopilot := "--demo" in OS.get_cmdline_user_args()

var hud_title: Label
var hud_count: Label
var hud_time: Label
var hud_data: Label
var card: PanelContainer
var card_title: Label
var card_body: Label
var banner: Label
var dispatch: Label
var dispatch_timer := 0.0
var fever_mat: ShaderMaterial
var fever_overlay: ColorRect
var splats: SplatLayer
var fever := 0.0


func _ready() -> void:
	_setup_input()
	_setup_environment()
	_build_ground()
	_build_lava()
	var repos := _load_repos()
	_build_city(repos)
	_build_player()
	_build_hud()
	hud_data.text = "%d public repos / snapshot %s" % [towers.size(), _ago(data_generated)]
	if week.commits > 0 or not desk.is_empty():
		var who := []
		for b in week.builders:
			who.append("%s %d" % [b, int(week.builders[b])])
		hud_effort.text = "THIS WEEK  %d commits · %d PRs merged · builders: %s" % [
			week.commits, week.merged, ", ".join(PackedStringArray(who)) if not who.is_empty() else "—"]
	print("=== SOLO ready: %d studios, %d orbs ===" % [towers.size(), total_orbs])
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")


# ---------- setup ----------

func _setup_input() -> void:
	var binds := {
		"mv_left": [KEY_A, KEY_LEFT], "mv_right": [KEY_D, KEY_RIGHT],
		"mv_fwd": [KEY_W, KEY_UP], "mv_back": [KEY_S, KEY_DOWN],
		"mv_jump": [KEY_SPACE], "open_repo": [KEY_E, KEY_ENTER],
		"toggle_motion": [KEY_M], "restart_run": [KEY_R],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.24, 0.25)  # dusk at the roadside studios
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.80, 0.62)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.29, 0.22)
	env.fog_density = 0.006
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_color = Color(1.0, 0.82, 0.59)
	sun.light_energy = 0.8
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(140, 1, 140)
	col.shape = shape
	ground.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.material_override = _mat(Color(0.40, 0.28, 0.17), Color.BLACK, 0.0, 0.0)  # baked desert hardpan
	ground.add_child(mesh)
	ground.position.y = -0.5
	add_child(ground)

	# grid lines: the mesh under the city
	for i in range(-60, 61, 6):
		for axis in 2:
			var line := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(120, 0.02, 0.04) if axis == 0 else Vector3(0.04, 0.02, 120)
			line.mesh = lb
			line.position = Vector3(0, 0.01, i) if axis == 0 else Vector3(i, 0.01, 0)
			line.material_override = _mat(Color(0.65, 0.46, 0.27), Color.BLACK, 0.0, 0.0)
			add_child(line)


func _build_lava() -> void:
	# warm embers drifting up out of the deep — the estate's lava lamp
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(55, 0.5, 55)
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.material = _mat(LAVA, LAVA, 3.0, 0.0)
	p.mesh = sm
	add_child(p)


# ---------- data ----------

func _load_repos() -> Array:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("repos.json missing")
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	self_repo = parsed.get("self", "Meshtool/godot-starter-3d")
	data_generated = parsed.get("generated", "")
	return parsed.get("repos", [])


func _ago(iso: String) -> String:
	var d := _days_since(iso)
	if d >= 999.0:
		return "?"
	if d < 1.0 / 24.0:
		return "just now"
	if d < 1.0:
		return "%dh ago" % int(d * 24.0)
	return "%dd ago" % int(d)


const LANG_COLORS := {
	"JavaScript": Color(0.95, 0.85, 0.2), "TypeScript": Color(0.2, 0.5, 0.95),
	"Python": Color(0.25, 0.55, 0.85), "Rust": Color(0.85, 0.45, 0.25),
	"GDScript": Color(0.35, 0.6, 0.75), "Go": Color(0.0, 0.68, 0.84),
}


func _days_since(iso: String) -> float:
	if iso.is_empty():
		return 999.0
	var t := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	return max(0.0, (Time.get_unix_time_from_system() - t) / 86400.0)


# ---------- city ----------

func _build_city(repos: Array) -> void:
	var by_org := {}
	for r in repos:
		var org: String = r.get("org", "")
		if not by_org.has(org):
			by_org[org] = []
		by_org[org].append(r)

	var ring := 0
	for org in by_org:
		var list: Array = by_org[org]
		var radius := 14.0 + ring * 16.0
		var tint := TURQ if ring == 0 else GOLD
		_district_sign(org, radius, tint, ring)
		for i in list.size():
			var ang := TAU * float(i) / float(list.size()) + ring * 0.4
			var pos := Vector3(cos(ang) * radius, 0, sin(ang) * radius)
			_build_tower(list[i], pos, tint)
		ring += 1
	_build_heart()
	_build_builders()
	_build_desk()


# ---------- effort layer ----------

func _build_effort(repo: Dictionary, pos: Vector3, height: float) -> void:
	var e: Dictionary = repo.get("effort", {})
	if e.is_empty():
		return
	var commits := int(e.get("commits_7d", 0))
	week.commits += commits
	week.merged += int(e.get("prs_merged_7d", 0))
	for b in e.get("builders", {}):
		week.builders[b] = int(week.builders.get(b, 0)) + int(e.builders[b])

	# bricks: this week's commits, laid on the roof one by one as you watch
	var top := pos.y + height + 0.25
	for i in mini(commits, 14):
		var bk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.9 - (i % 2) * 0.3, 0.32, 1.9 - ((i + 1) % 2) * 0.3)
		bk.mesh = bm
		var c := Color(1.0, 0.86, 0.5).lerp(LAVA, float(i) / 14.0)
		bk.material_override = _mat(c, c, 1.4, 0.0)
		var y := top + 0.2 + i * 0.36
		bk.position = Vector3(pos.x, y + 14.0, pos.z)
		bk.rotation.y = i * 0.25
		add_child(bk)
		bricks.append({"node": bk, "y": y, "delay": 1.2 + i * 0.35 + randf() * 0.4})

	# scaffold rings: one per open PR, climbing the tower while the work is unmerged
	for k in mini(int(e.get("prs_open", 0)), 4):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.85
		tm.outer_radius = 1.98
		ring.mesh = tm
		ring.material_override = _mat(TURQ, TURQ, 2.2, 0.0)
		ring.position = pos
		add_child(ring)
		rings.append({"node": ring, "base": pos, "h": height, "phase": k * 1.7})

	# CI weather: green = a calm gold halo, red = a storm that won't stop flickering
	var ci: String = e.get("ci", "")
	if ci == "success":
		var halo := MeshInstance3D.new()
		var hm := TorusMesh.new()
		hm.inner_radius = 0.9
		hm.outer_radius = 1.0
		halo.mesh = hm
		halo.material_override = _mat(GOLD, GOLD, 3.0, 0.0)
		halo.position = Vector3(pos.x, top + 0.6 + mini(commits, 14) * 0.36 + 0.6, pos.z)
		add_child(halo)
		rings.append({"node": halo, "base": null, "phase": 0.0})
	elif ci == "failure":
		var storm := OmniLight3D.new()
		storm.light_color = Color(1, 0.15, 0.2)
		storm.omni_range = 7.0
		storm.position = Vector3(pos.x, top + 2.0, pos.z)
		add_child(storm)
		storms.append({"light": storm, "phase": randf() * 10.0})
		var tag := Label3D.new()
		tag.font = UI_FONT
		tag.text = "✖ CI RED"
		tag.font_size = 40
		tag.pixel_size = 0.01
		tag.outline_size = 10
		tag.modulate = Color(1, 0.3, 0.3)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(pos.x, top + 3.0, pos.z)
		add_child(tag)


func _builder_color(b: String) -> Color:
	if BUILDER_COLORS.has(b):
		return BUILDER_COLORS[b]
	return TURQ  # people are turquoise, like your own orb


func _build_builders() -> void:
	# each builder is a swarm of ink moths flying the circuit of the towers they touched this week
	for b in week.builders:
		var path: Array = []
		for tw in towers:
			var e: Dictionary = tw.repo.get("effort", {})
			if e.get("builders", {}).has(b):
				path.append(tw.top + Vector3(0, 1.5, 0))
		if path.is_empty():
			continue
		if path.size() == 1:  # one tower: circle it
			var c: Vector3 = path[0]
			path = [c + Vector3(2.5, 0, 0), c + Vector3(0, 1, 2.5), c + Vector3(-2.5, 0, 0), c + Vector3(0, -0.5, -2.5)]
		var col := _builder_color(b)
		var n := clampi(1 + int(week.builders[b]) / 3, 1, 7)
		for i in n:
			var m := Node3D.new()
			var body := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.14
			sm.height = 0.28
			body.mesh = sm
			body.material_override = _mat(col, col, 5.0, 0.0)
			m.add_child(body)
			for side in [-1.0, 1.0]:  # wings: two thin ink blades
				var w := MeshInstance3D.new()
				var wm := BoxMesh.new()
				wm.size = Vector3(0.5, 0.02, 0.22)
				w.mesh = wm
				w.position.x = side * 0.3
				w.material_override = _mat(col.darkened(0.3), col, 1.2, 0.0)
				w.set_meta("side", side)
				m.add_child(w)
			var trail := CPUParticles3D.new()
			trail.amount = 24
			trail.lifetime = 0.9
			trail.local_coords = false
			trail.gravity = Vector3(0, -0.3, 0)
			trail.initial_velocity_max = 0.1
			var tmm := SphereMesh.new()
			tmm.radius = 0.04
			tmm.height = 0.08
			tmm.material = _mat(col, col, 3.0, 0.0)
			trail.mesh = tmm
			m.add_child(trail)
			if i == 0:
				var nm := Label3D.new()
				nm.font = UI_FONT
				nm.text = "%s · %d" % [b, int(week.builders[b])]
				nm.font_size = 36
				nm.pixel_size = 0.01
				nm.outline_size = 8
				nm.modulate = col
				nm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				nm.position.y = 0.55
				m.add_child(nm)
			add_child(m)
			moths.append({"node": m, "path": path, "seg": i % path.size(), "t": randf(),
				"speed": 0.25 + randf() * 0.2, "wobble": randf() * TAU})


func _build_desk() -> void:
	# DevDesk's queue as lanterns orbiting the runtime: shape only, never the words
	if not FileAccess.file_exists(DESK_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DESK_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	desk = parsed
	var items: Array = desk.get("items", [])
	for i in items.size():
		var it: Dictionary = items[i]
		var claimed: bool = it.get("state", "") == "claimed"
		var stale := float(it.get("age_h", 0)) > 48.0
		var col := GOLD if claimed else (Color(1, 0.2, 0.15) if stale else Color(0.7, 0.55, 1.0))
		var ln := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.28, 0.42, 0.28) * (1.6 if claimed else 1.0)
		ln.mesh = lm
		ln.material_override = _mat(col, col, 4.0 if claimed else (1.4 if stale else 2.4), 0.0)
		add_child(ln)
		lanterns.append({"node": ln, "r": 4.0 + (i % 5) * 1.3, "ang": TAU * float(i) / float(maxi(items.size(), 1)),
			"h": HEART.y - 2.5 + (i % 7) * 0.8, "speed": 0.05 + (0.25 if claimed else 0.0) + randf() * 0.04,
			"stale": stale})
		if claimed:
			var who := Label3D.new()
			who.font = UI_FONT
			who.text = "%s is on it" % it.get("agent", "an agent")
			who.font_size = 30
			who.pixel_size = 0.01
			who.outline_size = 8
			who.modulate = GOLD
			who.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			who.position.y = 0.6
			ln.add_child(who)
	var desk_sign := Label3D.new()
	desk_sign.font = UI_FONT
	desk_sign.text = "DEVDESK · %d on the desk · %d being worked · %d waiting 2+ days" % [
		int(desk.get("open", 0)), int(desk.get("claimed", 0)), int(desk.get("stale_48h", 0))]
	desk_sign.font_size = 40
	desk_sign.pixel_size = 0.01
	desk_sign.outline_size = 10
	desk_sign.modulate = Color(0.8, 0.7, 1.0)
	desk_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	desk_sign.position = HEART + Vector3(0, -5.2, 0)
	add_child(desk_sign)


func _animate_effort(delta: float, t: float) -> void:
	for bk in bricks:
		if bk.delay > 0.0:
			bk.delay -= delta
			continue
		var n: MeshInstance3D = bk.node
		n.position.y = lerpf(n.position.y, bk.y, clampf(delta * 6.0, 0.0, 1.0))
	for r in rings:
		var n: MeshInstance3D = r.node
		if r.base == null:
			n.rotate_y(delta * 1.2)
			continue
		var base: Vector3 = r.base
		n.position = base + Vector3(0, (0.5 + 0.5 * sin(t * 0.6 + r.phase)) * r.h, 0)
		n.rotation.z = sin(t * 0.8 + r.phase) * 0.12
	for st in storms:
		var l: OmniLight3D = st.light
		var flick := sin(t * 23.0 + st.phase) * sin(t * 7.0 + st.phase * 2.0)
		l.light_energy = 0.4 + (3.5 if not calm_motion and flick > 0.7 else 0.0)
	for m in moths:
		var path: Array = m.path
		m.t += delta * m.speed
		if m.t >= 1.0:
			m.t -= 1.0
			m.seg = (m.seg + 1) % path.size()
		var a: Vector3 = path[m.seg]
		var b: Vector3 = path[(m.seg + 1) % path.size()]
		var mid := (a + b) * 0.5 + Vector3(0, 3.0, 0)  # arc between towers
		var u: float = m.t
		var p := a.lerp(mid, u).lerp(mid.lerp(b, u), u)
		p += Vector3(sin(t * 3.0 + m.wobble), cos(t * 2.3 + m.wobble) * 0.6, cos(t * 2.7 + m.wobble)) * 0.35
		var node: Node3D = m.node
		if node.position.distance_to(p) > 0.01 and absf((p - node.position).normalized().y) < 0.98:
			node.look_at(p, Vector3.UP)
		node.position = p
		for w in node.get_children():
			if w.has_meta("side"):
				w.rotation.z = w.get_meta("side") * sin(t * 26.0 + m.wobble) * 0.9
	for ln in lanterns:
		ln.ang += delta * ln.speed
		var n: MeshInstance3D = ln.node
		n.position = HEART + Vector3(cos(ln.ang) * ln.r, ln.h - HEART.y + sin(t + ln.ang) * 0.3, sin(ln.ang) * ln.r)
		if ln.stale:
			n.visible = true if calm_motion else fmod(t * 1.3 + ln.ang, 2.0) > 0.25
			# n.visible = fmod(t * 1.3 + ln.ang, 2.0) > 0.25


func _build_heart() -> void:
	# the trust engine hangs over the city; every tower is threaded to it
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.4
	sm.height = 2.8
	core.mesh = sm
	core.material_override = _mat(Color(1, 0.95, 0.85), GOLD, 5.0, 0.0)
	core.position = HEART
	add_child(core)
	var hl := OmniLight3D.new()
	hl.light_color = GOLD
	hl.light_energy = 2.5
	hl.omni_range = 26.0
	hl.position = HEART
	add_child(hl)
	var heart_label := Label3D.new()
	heart_label.font = UI_FONT
	heart_label.text = "SIGNAL HUB / visualized repo activity"
	heart_label.font_size = 52
	heart_label.pixel_size = 0.01
	heart_label.outline_size = 12
	heart_label.modulate = GOLD
	heart_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart_label.position = HEART + Vector3(0, 2.4, 0)
	add_child(heart_label)
	for tw in towers:
		var top: Vector3 = tw.top
		var heat: float = tw.heat
		_filament(top, HEART, Color(tw.color, 0.25 + heat * 0.5), 0.2 + heat * 1.6)
		# receipts: light runs from the repo up to the runtime — fresher repos send more, faster
		for k in 1 + int(heat * 3.0):
			var p := MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = 0.12
			pm.height = 0.24
			p.mesh = pm
			p.material_override = _mat(tw.color, tw.color, 6.0, 0.0)
			add_child(p)
			pulses.append({"node": p, "from": top, "to": HEART, "t": randf(), "speed": 0.08 + heat * 0.25})


func _filament(a: Vector3, b: Vector3, color: Color, energy: float) -> void:
	var f := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := a.distance_to(b)
	bm.size = Vector3(0.04, 0.04, len)
	f.mesh = bm
	var m := _mat(color, color, energy, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f.material_override = m
	add_child(f)
	f.position = (a + b) * 0.5
	f.look_at(b, Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)


func _district_sign(org: String, radius: float, tint: Color, ring: int) -> void:
	var l := Label3D.new()
	l.font = UI_FONT
	l.text = org.to_upper()
	l.font_size = 160
	l.modulate = Color(tint, 0.18)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 10 + ring * 3, -radius - 6)
	l.no_depth_test = false
	add_child(l)


func _build_tower(repo: Dictionary, pos: Vector3, tint: Color) -> void:
	var days := _days_since(repo.get("pushed", ""))
	var archived: bool = repo.get("archived", false)
	var height := clampf(2.4 + log(float(repo.get("size", 1)) + 1.0) * 0.35, 2.4, 6.0)
	var heat := clampf(1.0 - days / 21.0, 0.0, 1.0)  # fresh pushes glow hottest
	var color := DIM if archived else tint

	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, height, 2.4)
	col.shape = shape
	col.position.y = height / 2.0
	body.add_child(col)

	# warm stucco studio, sized by the public repo snapshot
	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	core.mesh = box
	core.position.y = height / 2.0
	core.material_override = _mat(Color(0.83, 0.67, 0.43), Color.BLACK, 0.0, 0.0)
	body.add_child(core)

	# glowing edges / floor bands — brighter the fresher the repo
	var bands := 1
	for b in bands:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 0.18, 3.0)
		band.mesh = bm
		band.position.y = height - 0.3 + b * 0.0
		band.material_override = _mat(color, color, 0.3 + heat * 1.2, 0.0)
		body.add_child(band)

	# beacon on top
	var beacon := OmniLight3D.new()
	beacon.light_color = color
	beacon.light_energy = 0.5 + heat * 3.0
	beacon.omni_range = 6.0 + heat * 6.0
	beacon.position.y = height + 0.8
	body.add_child(beacon)

	var full := "%s/%s" % [repo.get("org", ""), repo.get("name", "")]
	var is_self := full == self_repo

	# the repo's name, big enough to read from the street
	var label := Label3D.new()
	label.font = UI_FONT
	label.text = repo.get("name", "?")
	label.font_size = 72
	label.pixel_size = 0.01
	label.outline_size = 14
	label.modulate = color.lightened(0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = height + 1.6
	body.add_child(label)

	# language cap: the roof is painted in the repo's language
	var lang: String = repo.get("lang", "")
	if lang != "":
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(2.6, 0.25, 2.6)
		cap.mesh = cm
		cap.position.y = height + 0.12
		var lc: Color = LANG_COLORS.get(lang, Color(0.8, 0.8, 0.85))
		cap.material_override = _mat(lc, lc, 1.6, 0.0)
		body.add_child(cap)

	# ticker: the tower scrolls its own last commit, facing the street
	var msg: String = repo.get("commit", "")
	if msg == "":
		msg = repo.get("desc", "")
	if msg != "":
		var tk := Label3D.new()
		tk.font = UI_FONT
		tk.font_size = 52
		tk.pixel_size = 0.01
		tk.outline_size = 12
		tk.modulate = Color(1, 0.95, 0.8)
		tk.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		var toward := -pos.normalized() if pos.length() > 0.1 else Vector3.FORWARD
		tk.position = toward * 1.5 + Vector3(0, minf(height * 0.5, 3.0), 0)
		body.add_child(tk)
		tickers.append({"label": tk, "text": "   ▸ " + msg + "   ", "off": randi() % 20})

	if is_self:  # this game is a repo too — and you're standing in it
		var crown := Label3D.new()
		crown.font = UI_FONT
		crown.text = "★ YOU ARE IN THIS REPO ★"
		crown.font_size = 48
		crown.pixel_size = 0.01
		crown.outline_size = 10
		crown.modulate = GOLD
		crown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		crown.position.y = height + 2.6
		body.add_child(crown)
		self_pos = pos

	add_child(body)
	towers.append({"node": body, "repo": repo, "pos": pos, "top": pos + Vector3(0, height + 0.3, 0), "heat": heat, "color": color})
	_build_effort(repo, pos, height)

	# orbs: one per open issue/PR (named, when the data has titles), plus one for showing up
	var items: Array = repo.get("items", [])
	var n := maxi(int(repo.get("issues", 0)), items.size()) + 1
	for k in n:
		var a := TAU * float(k) / float(n)
		var opos := pos + Vector3(cos(a) * 3.0, 1.2 + (k % 3) * 0.9, sin(a) * 3.0)
		var item = items[k - 1] if k > 0 and k - 1 < items.size() else null
		_spawn_orb(opos, LAVA if k > 0 else GOLD, repo, item)


func _spawn_orb(at: Vector3, color: Color, repo: Dictionary, item) -> void:
	var orb := Area3D.new()
	orb.position = at
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.55
	col.shape = s
	orb.add_child(col)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	m.mesh = sm
	m.material_override = _mat(color, color, 4.0, 0.0)
	orb.add_child(m)
	orb.set_meta("repo", repo.get("name", "the strip"))
	if item != null:
		orb.set_meta("item", item)
		var tag := Label3D.new()
		tag.font = UI_FONT
		tag.text = "%s#%d" % ["PR " if item.get("pr", false) else "", int(item.get("n", 0))]
		tag.font_size = 28
		tag.pixel_size = 0.01
		tag.outline_size = 6
		tag.modulate = color.lightened(0.4)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position.y = 0.6
		orb.add_child(tag)
	orb.set_meta("base_y", at.y)
	orb.set_meta("phase", randf() * TAU)
	orb.body_entered.connect(_on_orb.bind(orb))
	add_child(orb)
	orbs.append(orb)
	total_orbs += 1


# ---------- player ----------

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.5, 0)
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.6
	col.shape = s
	player.add_child(col)

	# SOLO: the estate's original road correspondent.
	var portrait := Sprite3D.new()
	portrait.texture = SOLO_TEXTURE
	portrait.pixel_size = 0.0022
	portrait.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	portrait.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	portrait.alpha_scissor_threshold = 0.15
	portrait.shaded = false
	portrait.position.y = 0.85
	player.add_child(portrait)
	var halo := CPUParticles3D.new()
	halo.amount = 6
	halo.lifetime = 1.2
	halo.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	halo.emission_sphere_radius = 0.9
	halo.gravity = Vector3.ZERO
	halo.initial_velocity_min = 0.1
	halo.initial_velocity_max = 0.4
	var hm := SphereMesh.new()
	hm.radius = 0.05
	hm.height = 0.1
	hm.material = _mat(GOLD, GOLD, 4.0, 0.0)
	halo.mesh = hm
	player.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = TURQ
	light.light_energy = 1.5
	light.omni_range = 7.0
	player.add_child(light)
	add_child(player)
	if self_pos != null:  # start at the door of this game's own repo
		var sp: Vector3 = self_pos
		player.position = sp + (-sp.normalized()) * 4.0 + Vector3(0, 1.5, 0)

	cam = Camera3D.new()
	cam.fov = 65
	add_child(cam)
	cam.position = player.position + Vector3(0, 10, 14)
	cam.look_at(player.position)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("mv_left", "mv_right", "mv_fwd", "mv_back")
	if autopilot and not orbs.is_empty():  # `-- --demo`: attract mode, drives to the nearest orb
		var near: Area3D = orbs[0]
		for o in orbs:
			if o.position.distance_to(player.position) < near.position.distance_to(player.position):
				near = o
		var to := near.position - player.position
		input = Vector2(to.x, to.z).normalized()
		if player.get_slide_collision_count() > 0 and Vector2(player.get_real_velocity().x, player.get_real_velocity().z).length() < SPEED * 0.5:
			input = input.rotated(1.3)  # blocked by a tower: slide round it
		if to.y > 0.8 and player.is_on_floor():
			player.velocity.y = JUMP
	var v := player.velocity
	v.x = input.x * SPEED
	v.z = input.y * SPEED
	if player.is_on_floor():
		if Input.is_action_just_pressed("mv_jump"):
			v.y = JUMP
	else:
		v.y -= GRAVITY * delta
	player.velocity = v
	player.move_and_slide()
	if player.position.y < -10:
		player.position = Vector3(0, 2, 0)
		player.velocity = Vector3.ZERO


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for orb in orbs:
		orb.position.y = orb.get_meta("base_y") + sin(t * 2.0 + orb.get_meta("phase")) * 0.25
		orb.rotate_y(delta * 2.0)

	var target := player.position + Vector3(0, 10, 14)
	cam.position = cam.position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	cam.look_at(player.position + Vector3(0, 1, 0))

	fever = lerpf(fever, float(collected) / max(1.0, float(total_orbs)), delta * 1.5)
	if fever_mat:
		fever_mat.set_shader_parameter("fever", 0.0 if calm_motion else fever)
		fever_mat.set_shader_parameter("t", t)
	cam.fov = 65.0 if calm_motion else 65.0 + sin(t * 0.9) * 6.0 * fever
	if not calm_motion:
		cam.rotate_object_local(Vector3.FORWARD, sin(t * 0.7) * 0.06 * fever)
	if dispatch_timer > 0.0:
		dispatch_timer -= delta
		dispatch.modulate.a = clampf(dispatch_timer, 0.0, 1.0)

	_animate_effort(delta, t)
	for pl in pulses:
		pl.t = fmod(pl.t + delta * pl.speed, 1.0)
		pl.node.position = pl.from.lerp(pl.to, pl.t)
	ticker_clock += delta
	if ticker_clock > 0.14:
		ticker_clock = 0.0
		for tk in tickers:
			var txt: String = tk.text
			tk.off = (tk.off + 1) % txt.length()
			tk.label.text = (txt + txt).substr(tk.off, 24)

	if not finished:
		elapsed += delta
	hud_time.text = "%.1fs" % elapsed
	hud_count.text = "ORBS  %d / %d" % [collected, total_orbs]
	_update_card()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_motion"):
		_toggle_motion()
	if event.is_action_pressed("restart_run"):
		get_tree().reload_current_scene()
	if event.is_action_pressed("open_repo") and near_repo != null:
		OS.shell_open(near_repo.get("url", ""))


func _on_orb(body: Node, orb: Area3D) -> void:
	if body != player or not is_instance_valid(orb) or not orbs.has(orb):
		return
	orbs.erase(orb)
	orb.queue_free()
	collected += 1
	if not calm_motion:
		splats.splat(true)
	var repo_name: String = orb.get_meta("repo", "the strip")
	if orb.has_meta("item"):
		var it: Dictionary = orb.get_meta("item")
		_say("Pocketed %s#%d off %s: \"%s\". It's still open out there. Somebody should close it." % [
			"PR " if it.get("pr", false) else "issue ", int(it.get("n", 0)), repo_name, it.get("title", "")])
	else:
		_say(DISPATCHES[randi() % DISPATCHES.size()].replace("{repo}", repo_name))
	if collected >= total_orbs and not finished:
		finished = true
		banner.text = "RUN COMPLETE.  %.1fs\nR TO RIDE AGAIN" % elapsed
		banner.visible = true
		print("=== SOLO RUN COMPLETE in %.1fs ===" % elapsed)


# ---------- HUD ----------

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	hud_title = _label("SOLO / MESH CITY", 28, GOLD)
	hud_title.position = Vector2(20, 14)
	ui.add_child(hud_title)
	hud_count = _label("", 20, TURQ)
	hud_count.position = Vector2(20, 52)
	ui.add_child(hud_count)
	hud_time = _label("", 20, Color(0.85, 0.85, 0.9))
	hud_time.position = Vector2(20, 78)
	ui.add_child(hud_time)
	hud_data = _label("", 13, Color(0.7, 0.72, 0.78))
	hud_data.position = Vector2(20, 104)
	ui.add_child(hud_data)
	hud_effort = _label("", 14, Color(1.0, 0.8, 0.55))
	hud_effort.position = Vector2(20, 124)
	ui.add_child(hud_effort)
	var help := _label("WASD / arrows: move  |  SPACE: jump  |  E: repo  |  M: motion  |  R: restart", 14, Color(1.0, 0.94, 0.80))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(20, -30)
	ui.add_child(help)

	card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.03, 0.88)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -380
	card.offset_right = -20
	card.offset_top = 20
	var vb := VBoxContainer.new()
	card_title = _label("", 22, GOLD)
	card_body = _label("", 15, Color(0.85, 0.88, 0.9))
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_body.custom_minimum_size = Vector2(340, 0)
	vb.add_child(card_title)
	vb.add_child(card_body)
	card.add_child(vb)
	card.visible = false
	ui.add_child(card)

	dispatch = _label("", 18, Color(1, 0.95, 0.85))
	dispatch.anchor_left = 0.5
	dispatch.anchor_right = 0.5
	dispatch.anchor_top = 1.0
	dispatch.anchor_bottom = 1.0
	dispatch.offset_left = -360
	dispatch.offset_right = 360
	dispatch.offset_top = -110
	dispatch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dispatch.autowrap_mode = TextServer.AUTOWRAP_WORD
	ui.add_child(dispatch)

	banner = _label("", 32, GOLD)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.offset_left = -400
	banner.offset_right = 400
	banner.visible = false
	ui.add_child(banner)

	# fever-dream post layer + ink splats: above the world, below the HUD
	var fx := CanvasLayer.new()
	fx.layer = 0
	add_child(fx)
	ui.layer = 1
	var rect := ColorRect.new()
	fever_overlay = rect
	rect.visible = not calm_motion
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = FEVER_SHADER
	fever_mat = ShaderMaterial.new()
	fever_mat.shader = sh
	rect.material = fever_mat
	fx.add_child(rect)
	splats = SplatLayer.new()
	splats.set_anchors_preset(Control.PRESET_FULL_RECT)
	splats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(splats)
	splats.visible = not calm_motion
	motion_button = Button.new()
	motion_button.text = "Motion: calm [M]"
	motion_button.position = Vector2(20, 150)
	motion_button.pressed.connect(_toggle_motion)
	motion_button.add_theme_font_override("font", UI_FONT)
	ui.add_child(motion_button)
	var course_button := Button.new()
	course_button.name = "ProofCourseButton"
	course_button.text = "Solo's Proof Course"
	course_button.add_theme_font_override("font", UI_FONT)
	course_button.position = Vector2(20, 192)
	course_button.custom_minimum_size = Vector2(210, 40)
	course_button.tooltip_text = "Leave this city run and open the recorded flight course."
	course_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://proof_course.tscn"))
	ui.add_child(course_button)
	_say("SOLO, reporting from the repo strip. Collect the signals. Find the stories. Bring back receipts.")


func _update_card() -> void:
	var best = null
	var best_d := INFO_RADIUS
	for t in towers:
		var d := Vector2(player.position.x - t.pos.x, player.position.z - t.pos.z).length()
		if d < best_d:
			best_d = d
			best = t.repo
	near_repo = best
	if best == null:
		card.visible = false
		return
	var days := _days_since(best.get("pushed", ""))
	var fresh := "today" if days < 1.0 else "%d days ago" % int(days)
	card_title.text = "%s / %s" % [best.get("org", ""), best.get("name", "")]
	var lines := [best.get("desc", "")]
	var lang: String = best.get("lang", "")
	lines.append("%s  ·  last push %s" % [lang if lang != "" else "—", fresh])
	var commit: String = best.get("commit", "")
	if commit != "":
		lines.append("last commit: \"%s\" (%s)" % [commit, _ago(best.get("commit_at", best.get("pushed", "")))])
	var ef: Dictionary = best.get("effort", {})
	if not ef.is_empty():
		var bl := []
		for b in ef.get("builders", {}):
			bl.append("%s %d" % [b, int(ef.builders[b])])
		lines.append("this week: %d commits%s · %d PRs merged · CI %s" % [
			int(ef.get("commits_7d", 0)), (" (" + ", ".join(PackedStringArray(bl)) + ")") if not bl.is_empty() else "",
			int(ef.get("prs_merged_7d", 0)), {"success": "✓", "failure": "✖ red"}.get(ef.get("ci", ""), "—")])
	var topics: Array = best.get("topics", [])
	if not topics.is_empty():
		lines.append("#" + "  #".join(PackedStringArray(topics)))
	lines.append("open issues/PRs: %d%s" % [int(best.get("issues", 0)), "   [archived]" if best.get("archived", false) else ""])
	var items: Array = best.get("items", [])
	for i in mini(items.size(), 3):
		lines.append("  · %s#%d %s" % ["PR " if items[i].get("pr", false) else "", int(items[i].get("n", 0)), items[i].get("title", "")])
	if "%s/%s" % [best.get("org", ""), best.get("name", "")] == self_repo:
		lines.append("★ this is the game you're playing")
	lines.append("[E] open on GitHub")
	card_body.text = "\n".join(lines)
	card.visible = true


# ---------- helpers ----------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _mat(albedo: Color, emission: Color, energy: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = 0.35
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

func _say(text: String) -> void:
	dispatch.text = text
	dispatch_timer = 4.0
	dispatch.modulate.a = 1.0


# ---------- gonzo layer (original writing, original art) ----------

const DISPATCHES := [
	"{repo} was leaking light from every floor. Nobody on the strip would admit they'd pushed to it.",
	"Grabbed the orb off {repo}. It screamed in JSON. I screamed back in YAML.",
	"The CI runner at {repo} looked at me like I owed it money. Maybe I did.",
	"{repo} had open issues breeding in the dark. I pocketed one and kept driving.",
	"Somewhere behind {repo} a merge conflict was howling. Best not to look directly at it.",
	"The ink was coming up through the floor now. {repo} didn't seem to mind.",
	"Every tower on this strip runs on coffee and unpaid technical debt. {repo} runs on both, twice.",
	"I asked {repo} for its README. It handed me a prophecy.",
	"The agents at {repo} kept whispering about receipts. I gave them one. It was blank.",
	"{repo}: green checks, red eyes. Nobody sleeps on the strip.",
]

const FEVER_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float fever = 0.0;
uniform float t = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float f = 0.15 + fever;
	// the warp: the floor breathes, the walls melt
	uv.x += sin(uv.y * 9.0 + t * 1.7) * 0.006 * f;
	uv.y += cos(uv.x * 7.0 + t * 1.3) * 0.006 * f;
	// chromatic split: the strip never quite lines up
	float split = 0.0025 + 0.012 * fever;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(split, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(split, 0.0)).b;
	// ink-wash: crush shadows to ink, push highlights to acid
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(0.04, 0.02, 0.02), smoothstep(0.12, 0.0, lum) * 0.8);
	c = mix(c, c * vec3(1.15, 0.85, 1.2), fever * 0.6);
	// paper grain + pen hatching
	float grain = hash(floor(SCREEN_UV * 900.0) + floor(t * 12.0)) - 0.5;
	float hatch = step(0.82, fract((SCREEN_UV.x + SCREEN_UV.y) * 260.0)) * smoothstep(0.25, 0.05, lum);
	c += grain * 0.06;
	c *= 1.0 - hatch * 0.35;
	// vignette closing in as the fever climbs
	float v = smoothstep(0.95 - 0.25 * fever, 0.35, distance(SCREEN_UV, vec2(0.5)));
	c *= mix(0.35, 1.0, v);
	COLOR = vec4(c, 1.0);
}
"""


class SplatLayer extends Control:
	## Procedural ink splats: a gnarled blob, flung droplets, and drip trails.
	var items: Array = []

	func splat(fresh: bool) -> void:
		var vp := get_viewport_rect().size
		if vp.x < 1.0:
			vp = Vector2(1280, 720)
		var edge := randf() < 0.7
		var pos := Vector2(randf() * vp.x, randf() * vp.y)
		if edge:  # splats crowd the margins like a hurried sketchbook
			pos = Vector2([randf() * 0.18, 0.82 + randf() * 0.18][randi() % 2] * vp.x, randf() * vp.y)
		var col := Color(0.04, 0.02, 0.02, 0.85) if randf() < 0.65 else Color(0.72, 0.04, 0.07, 0.8)
		var r := randf_range(26.0, 70.0) * (1.4 if fresh else 1.0)
		var pts := PackedVector2Array()
		var n := 26
		for i in n:
			var a := TAU * float(i) / float(n)
			var rr := r * randf_range(0.55, 1.25)
			if randi() % 5 == 0:
				rr *= randf_range(1.4, 2.2)  # spikes where the pen dug in
			pts.append(pos + Vector2(cos(a), sin(a)) * rr)
		var drops: Array = []
		for i in randi_range(8, 18):
			var a := randf() * TAU
			var d := r * randf_range(1.3, 3.6)
			drops.append([pos + Vector2(cos(a), sin(a)) * d, randf_range(2.0, 9.0)])
		var drips: Array = []
		for i in randi_range(0, 3):
			var x := pos.x + randf_range(-r * 0.6, r * 0.6)
			drips.append([Vector2(x, pos.y), randf_range(r, r * 3.0), randf_range(3.0, 7.0)])
		items.append({"pts": pts, "drops": drops, "drips": drips, "col": col, "life": 6.0 if fresh else -1.0})
		queue_redraw()

	func _process(delta: float) -> void:
		var dirty := false
		for it in items:
			if it.life > 0.0:
				it.life -= delta
				dirty = true
		items = items.filter(func(it): return it.life == -1.0 or it.life > 0.0)
		if dirty:
			queue_redraw()

	func _draw() -> void:
		for it in items:
			var c: Color = it.col
			if it.life > 0.0:
				c.a *= clampf(it.life / 2.0, 0.0, 1.0)
			draw_colored_polygon(it.pts, c)
			for d in it.drops:
				draw_circle(d[0], d[1], c)
			for dr in it.drips:
				draw_line(dr[0], dr[0] + Vector2(0, dr[1]), c, dr[2])
				draw_circle(dr[0] + Vector2(0, dr[1]), dr[2] * 0.9, c)


func _toggle_motion() -> void:
	calm_motion = not calm_motion
	splats.visible = not calm_motion
	fever_overlay.visible = not calm_motion
	motion_button.text = "Motion: calm [M]" if calm_motion else "Motion: gonzo [M]"


# Synthetic state checks only; not a signed or human gameplay receipt.
func _smoke_test() -> void:
	var errors: Array[String] = []
	if towers.is_empty() or total_orbs <= 0:
		errors.append("public repo snapshot did not create a playable world")
	if not SOLO_TEXTURE or SOLO_TEXTURE.get_width() <= 0:
		errors.append("character texture is missing")
	if errors.is_empty():
		var first: Area3D = orbs[0]
		_on_orb(self, first)
		if collected != 0:
			errors.append("non-player collected an orb")
		_on_orb(player, first)
		_on_orb(player, first)
		if collected != 1:
			errors.append("duplicate collision counted twice")
		for orb in orbs.duplicate():
			_on_orb(player, orb)
		if collected != total_orbs or not finished or not banner.visible:
			errors.append("complete run did not reach completion")
		if not calm_motion or fever_overlay.visible or splats.visible:
			errors.append("calm motion must hide distortion and splats by default")
		_toggle_motion()
		if calm_motion or not splats.visible or not fever_overlay.visible:
			errors.append("motion toggle failed")
		_toggle_motion()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		get_tree().quit(1)
		return
	print("SOLO_SMOKE_PASS: texture, world, player-only collection, duplicate guard, completion, calm motion")
	get_tree().quit(0)

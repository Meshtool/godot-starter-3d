extends Node3D
## MESH CITY — the Meshtool estate as a deep-sea field of seat orbs.
## Same visual language as runtime.meshtool.ai / meshtool.ai: near-black sea,
## lava rising, crisp particle orbs, clean type on quiet cards.
##
## Every public repo is an orb. Size = repo size. Brightness = how fresh the last push is.
## Swirl = how busy it was this week. Turquoise = Meshtool, gold = RightOnPar.
## The runtime hangs in the middle. You are your own seat orb: fly to each repo to dock.

const DATA_PATH := "res://data/repos.json"
const DESK_PATH := "res://data/desk.json"

const SEA := Color(0.012, 0.016, 0.024)
const TURQ := Color(0.13, 0.83, 0.93)     # #22d3ee
const GOLD := Color(1.0, 0.76, 0.28)
const VIOLET := Color(0.62, 0.48, 1.0)
const LAVA := Color(1.0, 0.45, 0.16)
const INK := Color(0.93, 0.95, 0.97)
const MUTED := Color(0.55, 0.6, 0.66)
const CARD_BG := Color(0.03, 0.036, 0.046, 0.92)

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


func _ready() -> void:
	_setup_input()
	_setup_world()
	var repos := _load_repos()
	_build_field(repos)
	_build_heart()
	_build_player()
	_load_desk()
	_build_ui()
	ui_live.text = "LIVE  ·  %d REPOS  ·  DATA %s" % [orbs.size(), _ago(data_generated).to_upper()]
	print("=== Mesh City ready: %d repos ===" % orbs.size())


# ---------- world ----------

func _setup_input() -> void:
	var binds := {
		"mv_left": [KEY_A, KEY_LEFT], "mv_right": [KEY_D, KEY_RIGHT],
		"mv_fwd": [KEY_W, KEY_UP], "mv_back": [KEY_S, KEY_DOWN],
		"open_repo": [KEY_E, KEY_ENTER],
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
	lava.amount = 180
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
	var by_org := {}
	for r in repos:
		var org: String = r.get("org", "")
		if not by_org.has(org):
			by_org[org] = []
		by_org[org].append(r)
	var ring := 0
	for org in by_org:
		var list: Array = by_org[org]
		var radius := 13.0 + ring * 14.0
		var tint := TURQ if org == "Meshtool" else GOLD
		for i in list.size():
			var ang := TAU * float(i) / float(list.size()) + ring * 0.35
			var pos := Vector3(cos(ang) * radius, 2.2 + (i % 3) * 0.9, sin(ang) * radius)
			_build_repo_orb(list[i], pos, tint)
		ring += 1


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
	cm.radius = radius * 0.08
	cm.height = radius * 0.16
	core.mesh = cm
	core.material_override = _glow(color.lerp(Color.WHITE, 0.5), 1.5 + brightness * 2.0)
	root.add_child(core)

	var n := amount if amount > 0 else int(140 + radius * 90)
	for layer in 2:  # color cloud + a few white sparks
		var p := CPUParticles3D.new()
		p.amount = (n if layer == 0 else n / 5) * 2
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
		var dm := SphereMesh.new()
		dm.radius = 0.022 if layer == 0 else 0.016
		dm.height = dm.radius * 2.0
		dm.radial_segments = 6
		dm.rings = 3
		var c := color if layer == 0 else Color(1, 0.97, 0.9)
		dm.material = _glow(c, (1.5 + brightness * 3.0) * (1.0 if layer == 0 else 1.6))
		p.mesh = dm
		root.add_child(p)

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
	cam = Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.position = player.position + Vector3(0, 8, 16)
	cam.look_at(player.position)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("mv_left", "mv_right", "mv_fwd", "mv_back")
	if autopilot and not finished:
		for ob in orbs:
			if not ob.visited:
				var to: Vector3 = ob.pos - player.position
				input = Vector2(to.x, to.z).normalized()
				player.position.y = lerpf(player.position.y, ob.pos.y, delta * 2.0)
				break
	player.position += Vector3(input.x, 0, input.y) * SPEED * delta
	var flat := Vector2(player.position.x, player.position.z)
	if flat.length() > 48.0:
		flat = flat.normalized() * 48.0
		player.position.x = flat.x
		player.position.z = flat.y


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
	if not best.visited:
		best.visited = true
		docked += 1
		var l: OmniLight3D = best.light
		l.light_energy *= 2.2
		ui_count.text = "Docked  %d / %d" % [docked, orbs.size()]
		if docked >= orbs.size() and not finished:
			finished = true
			done_card.visible = true
			print("=== ALL DOCKED ===")
	_fill_card(best.repo)
	card.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_repo") and near != null:
		OS.shell_open(near.repo.get("url", ""))


# ---------- UI: quiet cards, like the sites ----------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var brand := _label("meshtool", 22, INK)
	brand.position = Vector2(24, 18)
	ui.add_child(brand)
	var sub := _label("/  mesh city", 22, MUTED)
	sub.position = Vector2(128, 18)
	ui.add_child(sub)
	ui_live = _kicker("", TURQ)
	ui_live.position = Vector2(24, 52)
	ui.add_child(ui_live)

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
		dv.add_child(_kicker("DEVDESK  ·  THE DESK RIGHT NOW", VIOLET))
		dv.add_child(_label("%d on the desk" % int(desk.get("open", 0)), 20, INK))
		dv.add_child(_label("%d being worked  ·  %d waiting 2+ days" % [
			int(desk.get("claimed", 0)), int(desk.get("stale_48h", 0))], 14, MUTED))
		dc.add_child(dv)
		ui.add_child(dc)

	var hint := _label("WASD  fly      E  open on GitHub", 13, MUTED)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -160
	hint.offset_right = 160
	hint.offset_top = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(hint)

	done_card = _card(Color(GOLD, 0.5))
	done_card.set_anchors_preset(Control.PRESET_CENTER)
	done_card.offset_left = -220
	done_card.offset_right = 220
	var dvb := VBoxContainer.new()
	dvb.add_child(_kicker("ESTATE", GOLD))
	dvb.add_child(_label("Every repo docked.", 28, INK))
	done_card.add_child(dvb)
	done_card.visible = false
	ui.add_child(done_card)


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
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _kicker(text: String, color: Color) -> Label:
	var l := _label(text, 12, color)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
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

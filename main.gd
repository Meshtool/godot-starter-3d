extends Node3D
## MESH CITY · GONZO RUN — a fever-dream drive down the repo strip.
## Ink splatter, acid neon, and a fever that climbs with every orb.
## Each public repo is a tower: height = size, glow = how recently it was pushed,
## orbs = open issues/PRs (+1 per repo). Collect every orb to sync the estate.
## Walk up to a tower to read its card; press E to open the repo.

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
var orbs: Array = []     # Area3D
var total_orbs := 0
var collected := 0
var elapsed := 0.0
var finished := false
var near_repo = null
var autopilot := "--demo" in OS.get_cmdline_user_args()

var hud_title: Label
var hud_count: Label
var hud_time: Label
var card: PanelContainer
var card_title: Label
var card_body: Label
var banner: Label
var dispatch: Label
var dispatch_timer := 0.0
var fever_mat: ShaderMaterial
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
	print("=== Mesh City ready: %d towers, %d orbs ===" % [towers.size(), total_orbs])


# ---------- setup ----------

func _setup_input() -> void:
	var binds := {
		"mv_left": [KEY_A, KEY_LEFT], "mv_right": [KEY_D, KEY_RIGHT],
		"mv_fwd": [KEY_W, KEY_UP], "mv_back": [KEY_S, KEY_DOWN],
		"mv_jump": [KEY_SPACE], "open_repo": [KEY_E, KEY_ENTER],
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
	env.background_color = Color(0.06, 0.0, 0.05)  # desert night, bruised purple
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.16, 0.2)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.04, 0.12)
	env.fog_density = 0.018
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_color = Color(0.7, 0.85, 1.0)
	sun.light_energy = 0.35
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
	mesh.material_override = _mat(Color(0.28, 0.12, 0.06), Color.BLACK, 0.0, 0.0)  # baked desert hardpan
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
			line.material_override = _mat(ACID, ACID, 0.6, 0.0)
			add_child(line)


func _build_lava() -> void:
	# warm embers drifting up out of the deep — the estate's lava lamp
	var p := CPUParticles3D.new()
	p.amount = 260
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
	return parsed.get("repos", [])


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


func _district_sign(org: String, radius: float, tint: Color, ring: int) -> void:
	var l := Label3D.new()
	l.text = org.to_upper()
	l.font_size = 160
	l.modulate = Color(tint, 0.18)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 22 + ring * 6, -radius - 6)
	l.no_depth_test = false
	add_child(l)


func _build_tower(repo: Dictionary, pos: Vector3, tint: Color) -> void:
	var days := _days_since(repo.get("pushed", ""))
	var archived: bool = repo.get("archived", false)
	var height := 2.5 + log(float(repo.get("size", 1)) + 1.0) * 2.2
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

	# iron-submarine core
	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	core.mesh = box
	core.position.y = height / 2.0
	core.material_override = _mat(Color(0.05, 0.05, 0.06), Color.BLACK, 0.0, 0.85)
	body.add_child(core)

	# glowing edges / floor bands — brighter the fresher the repo
	var bands := int(height / 1.2)
	for b in bands:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.5, 0.08, 2.5)
		band.mesh = bm
		band.position.y = 0.6 + b * 1.2
		band.material_override = _mat(color, color, 0.4 + heat * 3.5, 0.0)
		body.add_child(band)

	# beacon on top
	var beacon := OmniLight3D.new()
	beacon.light_color = color
	beacon.light_energy = 0.5 + heat * 3.0
	beacon.omni_range = 6.0 + heat * 6.0
	beacon.position.y = height + 0.8
	body.add_child(beacon)

	var label := Label3D.new()
	label.text = repo.get("name", "?")
	label.font_size = 48
	label.outline_size = 10
	label.modulate = color.lightened(0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = height + 1.4
	body.add_child(label)

	add_child(body)
	towers.append({"node": body, "repo": repo, "pos": pos})

	# orbs: one per open issue/PR, plus one for showing up
	var n := int(repo.get("issues", 0)) + 1
	for k in n:
		var a := TAU * float(k) / float(n)
		var opos := pos + Vector3(cos(a) * 3.0, 1.2 + (k % 3) * 0.9, sin(a) * 3.0)
		_spawn_orb(opos, LAVA if k > 0 else GOLD)


func _spawn_orb(at: Vector3, color: Color) -> void:
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

	# the estate orb: your orb is you
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	core.mesh = sm
	core.material_override = _mat(TURQ, TURQ, 2.5, 0.0)
	player.add_child(core)
	var halo := CPUParticles3D.new()
	halo.amount = 40
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
		fever_mat.set_shader_parameter("fever", fever)
		fever_mat.set_shader_parameter("t", t)
	cam.fov = 65.0 + sin(t * 0.9) * 6.0 * fever
	cam.rotate_object_local(Vector3.FORWARD, sin(t * 0.7) * 0.06 * fever)
	if dispatch_timer > 0.0:
		dispatch_timer -= delta
		dispatch.modulate.a = clampf(dispatch_timer, 0.0, 1.0)

	if not finished:
		elapsed += delta
	hud_time.text = "%.1fs" % elapsed
	hud_count.text = "ORBS  %d / %d" % [collected, total_orbs]
	_update_card()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_repo") and near_repo != null:
		OS.shell_open(near_repo.get("url", ""))


func _on_orb(body: Node, orb: Area3D) -> void:
	if body != player or not is_instance_valid(orb):
		return
	orbs.erase(orb)
	orb.queue_free()
	collected += 1
	splats.splat(true)
	var repo_name := "the strip"
	var best_d := 1e9
	for tw in towers:
		var d: float = tw.pos.distance_to(orb.position)
		if d < best_d:
			best_d = d
			repo_name = tw.repo.get("name", repo_name)
	_say(DISPATCHES[randi() % DISPATCHES.size()].replace("{repo}", repo_name))
	if collected >= total_orbs and not finished:
		finished = true
		banner.text = "ESTATE SYNCED. THE FEVER BROKE.  %.1fs" % elapsed
		banner.visible = true
		print("=== ESTATE SYNCED in %.1fs ===" % elapsed)


# ---------- HUD ----------

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	hud_title = _label("MESH CITY · GONZO RUN", 28, GOLD)
	hud_title.position = Vector2(20, 14)
	ui.add_child(hud_title)
	hud_count = _label("", 20, TURQ)
	hud_count.position = Vector2(20, 52)
	ui.add_child(hud_count)
	hud_time = _label("", 20, Color(0.85, 0.85, 0.9))
	hud_time.position = Vector2(20, 78)
	ui.add_child(hud_time)
	var help := _label("WASD move · SPACE jump · E open repo", 14, Color(0.6, 0.65, 0.7))
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

	banner = _label("", 44, GOLD)
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
	for i in 5:
		splats.splat(false)  # the page is never clean
	_say("Dispatch #1: Rolled onto the repo strip at dawn. The towers were humming. Something in the build pipeline was watching me.")


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
	lines.append("open issues/PRs: %d%s" % [int(best.get("issues", 0)), "   [archived]" if best.get("archived", false) else ""])
	lines.append("[E] open on GitHub")
	card_body.text = "\n".join(lines)
	card.visible = true


# ---------- helpers ----------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
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

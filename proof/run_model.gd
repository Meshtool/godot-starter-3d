extends RefCounted
## Deterministic local replay. This never authenticates a player or issues a receipt.

const SCHEMA := "mesh-city.run.v1"
const RULES := "dock-fixed-v1"
const HZ := 60
const MAX_TICKS := 108000 # 30 minutes of simulation, bounded before replay.
const MAX_BYTES := 4000000
const STEP := 167
const DIAGONAL_STEP := 118
const LIMIT := 48000

var world: Array = []
var position := Vector2i(0, 6000)
var ticks := 0
var visits: Array = []
var inputs: Array = []

func _init(points: Array = []) -> void:
	world = points.duplicate(true)

func complete() -> bool:
	return not world.is_empty() and visits.size() == world.size()

func step(x: int, z: int, record := true) -> void:
	if complete() or ticks >= MAX_TICKS:
		return
	var distance := DIAGONAL_STEP if x != 0 and z != 0 else STEP
	position.x = clampi(position.x + x * distance, -LIMIT, LIMIT)
	position.y = clampi(position.y + z * distance, -LIMIT, LIMIT)
	ticks += 1
	if record:
		inputs.append([x, z])
	for point in world:
		if point.id in visits:
			continue
		var dx := position.x - int(point.x)
		var dz := position.y - int(point.z)
		var radius := int(point.radius)
		if dx * dx + dz * dz <= radius * radius:
			visits.append(point.id)

func result() -> Dictionary:
	return {"ticks": ticks, "time_ms": ticks * 1000 / HZ,
		"docked": visits.duplicate(), "total": world.size(),
		"position_mm": [position.x, position.y], "complete": complete()}

func document(build_id: String, lane: String) -> Dictionary:
	var doc := {"schema": SCHEMA, "rules": RULES, "build": build_id,
		"world": digest(world), "lane": lane, "inputs": inputs.duplicate(true),
		"result": result()}
	doc["checksum"] = digest(doc)
	return doc

static func digest(value: Variant) -> String:
	return "sha256:" + JSON.stringify(canonical(value)).sha256_text()

static func canonical(value: Variant) -> Variant:
	# Godot parses JSON numbers as floats; preserve the integer wire contract.
	if value is Array:
		var array := []
		for item in value:
			array.append(canonical(item))
		return array
	if value is Dictionary:
		var object := {}
		for key in value:
			object[key] = canonical(value[key])
		return object
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value) and abs(value) < 9007199254740992:
		return int(value)
	return value

static func verify(doc: Variant, points: Array, build_id: String) -> Dictionary:
	if not doc is Dictionary:
		return failure("Run file must be an object.")
	var keys := ["schema", "rules", "build", "world", "lane", "inputs", "result", "checksum"]
	if doc.size() != keys.size():
		return failure("Unexpected run fields.")
	for key in keys:
		if not doc.has(key):
			return failure("Missing run field: " + key)
	if doc.schema != SCHEMA or doc.rules != RULES:
		return failure("Unsupported run rules.")
	if build_id.is_empty() or doc.build != build_id or doc.world != digest(points):
		return failure("This run belongs to a different build or repo snapshot.")
	if doc.lane not in ["human", "demo"]:
		return failure("Unknown declared lane.")
	if not doc.result is Dictionary or doc.result.size() != 6:
		return failure("Invalid result shape.")
	for key in ["ticks", "time_ms", "docked", "total", "position_mm", "complete"]:
		if not doc.result.has(key):
			return failure("Missing result field.")
	for key in ["ticks", "time_ms", "total"]:
		var value: Variant = doc.result[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return failure("Invalid result number.")
		if float(value) != floor(float(value)) or value < 0 or value > MAX_TICKS * 1000:
			return failure("Invalid result number.")
	if not doc.result.complete is bool or not doc.result.docked is Array or doc.result.docked.size() != points.size():
		return failure("Invalid checkpoint result.")
	for id in doc.result.docked:
		if not id is String or id.length() > 300:
			return failure("Invalid checkpoint ID.")
	if not doc.result.position_mm is Array or doc.result.position_mm.size() != 2:
		return failure("Invalid result position.")
	for coordinate in doc.result.position_mm:
		if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)):
			return failure("Invalid result position.")
		if float(coordinate) != floor(float(coordinate)) or abs(coordinate) > LIMIT:
			return failure("Invalid result position.")
	if not doc.inputs is Array or doc.inputs.is_empty() or doc.inputs.size() > MAX_TICKS:
		return failure("Run length is invalid.")
	for movement in doc.inputs:
		if not movement is Array or movement.size() != 2:
			return failure("Invalid movement sample.")
		for axis in movement:
			if typeof(axis) not in [TYPE_INT, TYPE_FLOAT]:
				return failure("Movement must be an integer from -1 to 1.")
			if not is_finite(float(axis)) or float(axis) != floor(float(axis)) or abs(float(axis)) > 1.0:
				return failure("Movement must be an integer from -1 to 1.")
	var body: Dictionary = doc.duplicate(true)
	body.erase("checksum")
	if doc.checksum != digest(body):
		return failure("Run checksum changed.")
	var replay = load("res://proof/run_model.gd").new(points)
	for movement in doc.inputs:
		if replay.complete():
			return failure("Run contains inputs after the finish.")
		replay.step(int(movement[0]), int(movement[1]), false)
	if not replay.complete():
		return failure("Run did not dock every repo.")
	if digest(doc.result) != digest(replay.result()):
		return failure("Replayed result differs from the recorded result.")
	return {"ok": true, "status": "local_replay_match", "runtime_verified": false,
		"message": "Local replay matched. No Runtime signature issued."}

static func failure(message: String) -> Dictionary:
	return {"ok": false, "status": "rejected", "runtime_verified": false, "message": message}

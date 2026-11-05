extends Node3D

@export var move_speed := 5.0
@export var spin_speed := 3.0
const GRAVITY := 98.0

var player: CharacterBody3D
var score_label: Label
var win_label: Label
var score := 0
var coins: Array = []

func _ready():
	print("=== Godot Starter 3D ready ===")

	# UI layer (score + win labels)
	var ui := CanvasLayer.new()
	add_child(ui)

	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.position = Vector2(10, 10)
	ui.add_child(score_label)

	win_label = Label.new()
	win_label.text = ""
	win_label.position = Vector2(10, 40)
	ui.add_child(win_label)

	# World container
	var world := Node3D.new()
	add_child(world)

	# Floor to walk on
	var floor := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	floor_col.shape = BoxShape3D.new()
	floor_col.shape.size = Vector3(24, 1, 24)
	floor.add_child(floor_col)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.mesh.size = Vector3(24, 1, 24)
	floor.add_child(floor_mesh)
	world.add_child(floor)

	# Player (moves with WASD / arrow keys)
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.5, 0)
	var p_col := CollisionShape3D.new()
	p_col.shape = CapsuleShape3D.new()
	p_col.shape.radius = 0.4
	p_col.shape.height = 1.8
	player.add_child(p_col)
	var p_mesh := MeshInstance3D.new()
	p_mesh.mesh = BoxMesh.new()
	p_mesh.mesh.size = Vector3(0.8, 1.8, 0.8)
	player.add_child(p_mesh)

	# Camera follows the player (parented to player)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 7)
	cam.rotation_degrees = Vector3(-20, 0, 0)
	player.add_child(cam)

	world.add_child(player)

	# 3 spinning coins to collect
	var positions = [Vector3(-3, 1, 0), Vector3(0, 1, 2), Vector3(3, 1, -2)]
	for pos in positions:
		var coin := Area3D.new()
		coin.position = pos
		var c_col := CollisionShape3D.new()
		c_col.shape = SphereShape3D.new()
		c_col.shape.radius = 0.4
		coin.add_child(c_col)
		var c_mesh := MeshInstance3D.new()
		c_mesh.mesh = SphereMesh.new()
		c_mesh.mesh.radius = 0.4
		coin.add_child(c_mesh)
		coin.body_entered.connect(_on_coin_collected.bind(coin))
		world.add_child(coin)
		coins.append(coin)

	print("Player, floor, %d coins created" % coins.size())

func _process(delta):
	# Spin coins
	for coin in coins:
		coin.rotate_y(spin_speed * delta)
	# Keep score label up to date
	score_label.text = "Score: %d" % score

func _physics_process(delta):
	# Player movement: WASD / arrow keys
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var velocity := player.velocity
	velocity.x = input_dir.x * move_speed
	velocity.z = input_dir.y * move_speed
	velocity.y -= GRAVITY * delta
	player.velocity = velocity
	player.move_and_slide()

func _on_coin_collected(coin):
	coin.queue_free()
	coins.erase(coin)
	score += 1
	print("Coin collected! Score: %d" % score)
	if score >= 3:
		win_label.text = "You win!"
		print("=== YOU WIN! ===")
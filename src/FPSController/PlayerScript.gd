extends CharacterBody3D
## Made by Yni, licensed under CC0
class_name PlayerScript

const SPEED = 4.5
const JUMP_VELOCITY = 4

## Max health
@export var health: Array[float] = [100]
## Current health
@export var current_health: Array[float] = [100]
## Sprint toggle
@export var sprint_enabled: bool = false
## Move sounds toggle
@export var move_sounds_enabled: bool = false
## Walk sounds
@export var footstep_sounds: Array[String]
## Sprint sounds
@export var sprint_sounds: Array[String]
## Inventory toggle
@export var enable_inventory: bool = false
## Movement toggle (camera can be still moved through, even if this property is disabled)
@export var can_move: bool = true
## Current item in hand
@export var using_item: String = ""
## Keycards. Unlike SCP games, these keycards can open only certain doors, not other.
## There is no leveling system.
@export var keycards: Array[int]

@onready var ray = $PlayerHead/PlayerRecoil/RayCast3D
@onready var walk_sounds = $WalkSounds
@onready var interact_sound = $InteractSound

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var is_sprinting: bool = false
var is_walking: bool = false
## Enables or disables ALL motion (including camera rotate)
var motion_enabled = true
var mouse_sensitivity: float = 0.05

func _ready() -> void:
	ray.add_exception(self)

## Mouse rotation
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion && motion_enabled:
		rotate_y(-event.relative.x * mouse_sensitivity * 0.05)
		$PlayerHead.rotate_x(-event.relative.y * mouse_sensitivity * 0.05)
		
		var player_rotation = $PlayerHead.rotation_degrees
		player_rotation.x = clamp($PlayerHead.rotation_degrees.x, -85, 85)
		$PlayerHead.rotation_degrees = player_rotation

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction && can_move && motion_enabled:
		if Input.is_action_pressed("move_sprint"):
			velocity.x = direction.x * SPEED * 2
			velocity.z = direction.z * SPEED * 2
		else:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	if ray.is_colliding():
		if Input.is_action_just_pressed("interact"):
			var collided_with = ray.get_collider()
			if collided_with is InteractableStatic:
				collided_with.call("interact", self)
	
	move_and_slide()

## Animation-based footstep system.
func footstep_animate():
	if move_sounds_enabled:
		if is_walking:
			call("play_footstep_sound", false)
		if is_sprinting:
			call("play_footstep_sound", true)

## Make footstep sounds audible to all.
func play_footstep_sound(sprinting: bool):
	if sprinting:
		walk_sounds.stream = load(sprint_sounds[rng.randi_range(0, sprint_sounds.size() - 1)])
		walk_sounds.play()
	else:
		walk_sounds.stream = load(footstep_sounds[rng.randi_range(0, footstep_sounds.size() - 1)])
		walk_sounds.play()

## Health manager.
func health_manage(amount: float, type_of_health: int, deplete_reason: String):
	if type_of_health >= current_health.size():
		return
	if current_health[type_of_health] + amount <= health[type_of_health]:
		current_health[type_of_health] += amount
	else:
		current_health[type_of_health] == health[type_of_health]
	if current_health[type_of_health] <= 0:
		pass

##s Applies shader to the player
func apply_shader(res: String):
	for node in get_node("PlayerHead/PlayerRecoil/PlayerCamera").get_children():
		if node is MeshInstance3D:
			node.visible = false
	if get_node_or_null("PlayerHead/PlayerRecoil/PlayerCamera" + res) != null && !res.is_empty():
		get_node("PlayerHead/PlayerRecoil/PlayerCamera" + res).visible = true

@icon("res://Scripts/ElevatorSystem/elevator_node.svg")
extends Node3D
class_name ElevatorSystem

enum LastMove {UP, DOWN}
var last_move: LastMove = LastMove.UP
@export var floors : Array[ElevatorFloor]
@export var elevator_doors : PackedStringArray
@export var speed: float = 2
@export var is_moving: bool = false
@export var open_door_sounds : PackedStringArray
@export var close_door_sounds : PackedStringArray
@export var objects_to_teleport : Array
@export var current_floor : int
@export var target_floor : int
@export var waypoints : Array[Array]
var counter : int = 0
var pass_floor : bool = false
var default_rotation: Vector3

# Called when the node enters the scene tree for the first time.
func _ready():
	default_rotation = rotation
	if !is_moving:
		if !elevator_doors.is_empty():
			get_tree().root.get_node("Main/" + elevator_doors[current_floor]).door_open()
		door_open()

 # Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if waypoints != null:
		if is_moving && waypoints.size() > 0:
			global_position = global_position.move_toward(waypoints[counter][0], speed * delta)
			global_rotation = global_rotation.move_toward(waypoints[counter][1] + default_rotation, speed * delta)
			for i in range(objects_to_teleport.size()):
				var node: Node3D = get_node(objects_to_teleport[i])
				node.global_position = node.global_position.move_toward(waypoints[counter][0], speed * delta)
				# remember, floating numbers needs IsEqualApprox, Yni!
			if global_position.is_equal_approx(waypoints[counter][0]):
				if (counter < waypoints.size() - 1):
					counter += 1
				else:
					counter = 0
					waypoints.clear()
					if pass_floor:
						if multiplayer.is_server():
							if last_move == LastMove.DOWN:
								if (current_floor < target_floor - 1):
									elevator_move(true, false)
								else:
									elevator_move(false, false)
							elif last_move == LastMove.UP:
								if (current_floor > target_floor + 1):
									elevator_move(true, false)
								else:
									elevator_move(false, false)
					else:
						is_moving = false
						get_node("Move").stop()
						call("open_dest_doors")
						# rpc("open_dest_doors")

# Open the door
func door_open():
	var rng = RandomNumberGenerator.new()
	$AnimationPlayer.play("door_open")
	set_physics_process(false)
	if !open_door_sounds.is_empty():
		$DoorSound.stream = load(open_door_sounds[rng.randi_range(0, open_door_sounds.size() - 1)])
		$DoorSound.play()
# Closes the door
func door_close():
	var rng = RandomNumberGenerator.new()
	$AnimationPlayer.play("door_open", -1, -1, true)
	$AnimationPlayer.connect("animation_finished", _on_animation_finished)
	if !close_door_sounds.is_empty():
		$DoorSound.stream = load(close_door_sounds[rng.randi_range(0, close_door_sounds.size() - 1)])
		$DoorSound.play()

## Moves elevator (network method)
#@rpc("any_peer", "call_local")
func call_elevator(floor):
	if is_moving || floor == current_floor:
		return
	target_floor = floor
	if floors.size() == 1 || abs(target_floor - current_floor) == 1:
		elevator_move(false, true)
	else:
		elevator_move(true, true)
func elevator_move(p_pass_floor: bool, first : bool):
	pass_floor = p_pass_floor
	if first:
		if !elevator_doors.is_empty():
			get_tree().root.get_node("Main/" + elevator_doors[current_floor]).door_close()
		door_close()
	var floor: int
	if (target_floor < current_floor):
		last_move = LastMove.UP
		floor = current_floor - 1
		#check if upper point of current floor exist
		if (floors[current_floor].up_helper_point != ""):
			waypoints.append([get_node(floors[current_floor].up_helper_point).global_position, get_node(floors[current_floor].up_helper_point).global_rotation])
		#check if lower point of next floor exist
		if (floors[floor].down_helper_point != ""):
			waypoints.append([get_node(floors[floor].down_helper_point).global_position, get_node(floors[floor].down_helper_point).global_rotation])
		waypoints.append([get_node(floors[floor].destination_point).global_position, get_node(floors[floor].destination_point).global_rotation])
		current_floor = floor
	elif (target_floor > current_floor):
		last_move = LastMove.DOWN
		floor = current_floor + 1
		#check if lower point of current floor exist
		if (floors[current_floor].down_helper_point != ""):
			waypoints.append([get_node(floors[current_floor].down_helper_point).global_position, get_node(floors[current_floor].down_helper_point).global_rotation])
		#check if upper point of next floor exist
		if (floors[floor].up_helper_point != ""):
			waypoints.append([get_node(floors[floor].up_helper_point).global_position, get_node(floors[floor].up_helper_point).global_rotation])
		waypoints.append([get_node(floors[floor].destination_point).global_position, get_node(floors[floor].destination_point).global_rotation])
		current_floor = floor
	is_moving = true
	$Move.play()
## Opens destination doors.
# @rpc("any_peer", "call_local")
func open_dest_doors():
	if !elevator_doors.is_empty():
		get_tree().root.get_node("Main/" + elevator_doors[current_floor]).door_open()
	door_open()

func interact_up(player):
	var dir : int = current_floor - 1
	if current_floor >= 0 && !is_moving:
		call("call_elevator", dir) #move the elevator up.

func interact_down(player):
	var dir : int = current_floor + 1
	if current_floor < floors.size() && !is_moving:
		call("call_elevator", dir) #move the elevator down.

func on_player_area_body_entered(body):
	if body is CharacterBody3D:
		call("add_object", body.get_path())

func on_player_area_body_exited(body):
	if body is CharacterBody3D:
		call("remove_object", body.get_path())

@rpc("any_peer", "call_local")
func add_object(name):
	objects_to_teleport.append(name)


@rpc("any_peer", "call_local")
func remove_object(name):
	objects_to_teleport.erase(name)


func _on_animation_finished(anim_name):
	$AnimationPlayer.disconnect("animation_finished", _on_animation_finished)
	set_physics_process(true)

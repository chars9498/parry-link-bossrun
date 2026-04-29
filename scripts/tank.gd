extends CharacterBody2D
class_name Tank

signal parry_attempted

@export var speed := 210.0
@export var max_hp := 120

var hp := max_hp
var parry_window := false
var perfect_window := false
var invincible_time := 0.0

func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = move * speed
	move_and_slide()
	if invincible_time > 0.0:
		invincible_time -= delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		emit_signal("parry_attempted")

func open_parry_window(total: float, perfect: float) -> void:
	parry_window = true
	perfect_window = true
	await get_tree().create_timer(perfect).timeout
	perfect_window = false
	await get_tree().create_timer(max(total - perfect, 0.01)).timeout
	parry_window = false

func get_parry_result() -> int:
	if perfect_window:
		return ParryTypes.Result.PERFECT
	if parry_window:
		return ParryTypes.Result.NORMAL
	return ParryTypes.Result.FAIL

func set_invincible(duration: float) -> void:
	invincible_time = max(invincible_time, duration)

func take_damage(amount: int) -> bool:
	if invincible_time > 0.0:
		return false
	hp = max(hp - amount, 0)
	return true

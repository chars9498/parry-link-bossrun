extends CharacterBody2D
class_name Tank

signal parry_attempted

@export var speed: float = 210.0
@export var max_hp: int = 120

var hp: int = max_hp
var parry_window: bool = false
var perfect_window: bool = false
var parry_cooldown: float = 0.0
var parry_active_timer: float = 0.0
var invincible_time: float = 0.0

func _physics_process(delta: float) -> void:
	var move: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = move * speed
	move_and_slide()
	if invincible_time > 0.0:
		invincible_time -= delta
	if parry_cooldown > 0.0:
		parry_cooldown -= delta
	if parry_active_timer > 0.0:
		parry_active_timer -= delta
	if parry_active_timer <= 0.0:
		parry_window = false
		perfect_window = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if parry_cooldown > 0.0:
			return
		parry_active_timer = 0.16
		parry_cooldown = 0.32
		emit_signal("parry_attempted")

func open_parry_window(total: float, perfect: float) -> void:
	parry_window = true
	perfect_window = true
	await get_tree().create_timer(perfect).timeout
	perfect_window = false
	await get_tree().create_timer(max(total - perfect, 0.01)).timeout
	parry_window = false

func get_parry_result() -> int:
	if not parry_window:
		return ParryTypes.Result.FAIL
	if perfect_window:
		return ParryTypes.Result.PERFECT
	return ParryTypes.Result.NORMAL

func set_invincible(duration: float) -> void:
	invincible_time = max(invincible_time, duration)

func take_damage(amount: int) -> bool:
	if invincible_time > 0.0:
		return false
	hp = max(hp - amount, 0)
	return true

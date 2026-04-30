extends CharacterBody2D

signal attack_warning(window: float)
signal attack_resolved(was_parried: bool)

@export var target_path: NodePath = "../Tank"
@export var jump_power := 200.0

var _parried_this_cycle := false

@onready var _tank: CharacterBody2D = get_node(target_path)
@onready var _timer: Timer = $AttackTimer

func _ready() -> void:
	_timer.timeout.connect(_do_jump_attack)

func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
	move_and_slide()

func _do_jump_attack() -> void:
	_parried_this_cycle = false
	emit_signal("attack_warning", 0.28)
	await get_tree().create_timer(0.45).timeout
	var direction := (_tank.global_position - global_position).normalized()
	velocity = direction * jump_power
	await get_tree().create_timer(0.32).timeout
	emit_signal("attack_resolved", _parried_this_cycle)

func register_parry() -> void:
	_parried_this_cycle = true

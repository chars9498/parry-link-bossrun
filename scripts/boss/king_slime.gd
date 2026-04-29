extends CharacterBody2D
class_name KingSlime

signal attack_telegraph(parry_total: float, parry_perfect: float, pattern_name: String)
signal attack_landed(base_damage: int)

@export var max_hp := 1400
var hp := max_hp

var _tank: Tank
var _patterns := ["박치기", "점프", "점액", "왕관"]
var _index := 0
var _parried := false
@onready var timer: Timer = $PatternTimer

func setup(tank: Tank) -> void:
	_tank = tank

func _ready() -> void:
	timer.timeout.connect(_run_next_pattern)

func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 350 * delta)
	move_and_slide()

func _run_next_pattern() -> void:
	if _tank == null or hp <= 0:
		return
	_parried = false
	var p := _patterns[_index % _patterns.size()]
	_index += 1
	match p:
		"박치기":
			emit_signal("attack_telegraph", 0.35, 0.12, "몸통 박치기")
			await get_tree().create_timer(0.45).timeout
			velocity = (_tank.global_position - global_position).normalized() * 280
			await get_tree().create_timer(0.28).timeout
			_resolve_hit(16)
		"점프":
			emit_signal("attack_telegraph", 0.4, 0.13, "점프 내려찍기")
			await get_tree().create_timer(0.55).timeout
			global_position = global_position.lerp(_tank.global_position, 0.55)
			_resolve_hit(20)
		"점액":
			emit_signal("attack_telegraph", 0.45, 0.14, "점액 뱉기")
			await get_tree().create_timer(0.52).timeout
			_resolve_hit(13)
		"왕관":
			emit_signal("attack_telegraph", 0.32, 0.08, "왕관 내려찍기")
			await get_tree().create_timer(0.38).timeout
			_resolve_hit(28)

func register_parry() -> void:
	_parried = true

func apply_damage(amount: int) -> void:
	hp = max(hp - amount, 0)

func _resolve_hit(damage: int) -> void:
	if not _parried:
		emit_signal("attack_landed", damage)

extends CharacterBody2D
class_name KingSlime

enum BossState { IDLE, TELEGRAPH, ATTACK, RECOVER }
enum Pattern { CHARGE, SLAM, SPIT, CROWN }

signal attack_telegraph(parry_total: float, parry_perfect: float, pattern_name: String)
signal attack_landed(base_damage: int)

@export var max_hp: int = 1400
var hp: int = max_hp

var _tank: Tank
var _state: int = BossState.IDLE
var _pattern_index: int = 0
var _parried: bool = false
var _hit_applied: bool = false
var _attack_dir: Vector2 = Vector2.RIGHT
var _projectile_pos: Vector2 = Vector2.ZERO
var _projectile_vel: Vector2 = Vector2.ZERO
var _projectile_active: bool = false

@onready var timer: Timer = $PatternTimer
@onready var body: Polygon2D = $BossBody
@onready var crown: Polygon2D = $Crown

func setup(tank: Tank) -> void:
	_tank = tank

func _ready() -> void:
	timer.timeout.connect(_start_pattern)

func _physics_process(delta: float) -> void:
	if _state == BossState.ATTACK and _current_pattern() == Pattern.CHARGE:
		move_and_slide()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
	if _projectile_active:
		_projectile_pos += _projectile_vel * delta
		if _projectile_pos.distance_to(_tank.global_position) <= 18.0 and not _parried:
			_apply_hit_once(14)
			_projectile_active = false
		if _projectile_pos.distance_to(global_position) > 700.0:
			_projectile_active = false
	queue_redraw()

func _draw() -> void:
	if _state == BossState.TELEGRAPH:
		match _current_pattern():
			Pattern.SLAM:
				draw_circle(_tank.global_position - global_position, 58.0, Color(0.8, 0.3, 1.0, 0.25))
			Pattern.CROWN:
				draw_arc(Vector2.ZERO, 80.0, -0.6, 0.6, 24, Color(1, 0.5, 0.15, 0.65), 6.0)
	if _projectile_active:
		draw_circle(_projectile_pos - global_position, 10.0, Color(0.4, 1.0, 0.55, 0.75))

func _start_pattern() -> void:
	if _tank == null or hp <= 0:
		return
	_parried = false
	_hit_applied = false
	_state = BossState.TELEGRAPH
	var p: String = ["박치기", "점프", "점액", "왕관"][_current_pattern()]
	match _current_pattern():
		Pattern.CHARGE:
			await _telegraph(0.7, 0.22, "몸통 박치기")
			_attack_dir = (_tank.global_position - global_position).normalized()
			_state = BossState.ATTACK
			velocity = _attack_dir * 340.0
			await get_tree().create_timer(0.35).timeout
			if not _parried and global_position.distance_to(_tank.global_position) <= 26.0:
				_apply_hit_once(18)
			_state = BossState.RECOVER
			await get_tree().create_timer(0.35).timeout
		Pattern.SLAM:
			await _telegraph(0.95, 0.24, "점프 내려찍기")
			_state = BossState.ATTACK
			await get_tree().create_timer(0.15).timeout
			if not _parried and global_position.distance_to(_tank.global_position) <= 60.0:
				_apply_hit_once(22)
			_state = BossState.RECOVER
			await get_tree().create_timer(0.45).timeout
		Pattern.SPIT:
			await _telegraph(0.55, 0.16, "점액 뱉기")
			_state = BossState.ATTACK
			_projectile_active = true
			_projectile_pos = global_position
			_projectile_vel = (_tank.global_position - global_position).normalized() * 170.0
			await get_tree().create_timer(1.2).timeout
			_projectile_active = false
			_state = BossState.RECOVER
			await get_tree().create_timer(0.28).timeout
		Pattern.CROWN:
			await _telegraph(0.85, 0.18, "왕관 내려찍기")
			_state = BossState.ATTACK
			var dir_to_tank: Vector2 = (_tank.global_position - global_position).normalized()
			var in_range: bool = global_position.distance_to(_tank.global_position) <= 88.0
			var front_dot: float = _attack_dir.dot(dir_to_tank)
			if not _parried and in_range and front_dot >= 0.55:
				_apply_hit_once(30)
			_state = BossState.RECOVER
			await get_tree().create_timer(0.4).timeout
	_state = BossState.IDLE
	_pattern_index += 1

func _telegraph(total: float, perfect: float, name: String) -> void:
	body.modulate = Color(1.0, 1.0, 1.0, 0.95)
	crown.modulate = Color(1.0, 0.9, 0.4, 1.0)
	emit_signal("attack_telegraph", total, perfect, name)
	await get_tree().create_timer(total).timeout
	body.modulate = Color(0.35, 0.85, 0.55, 0.85)
	crown.modulate = Color(1, 0.8, 0.2, 1)

func register_parry() -> void:
	_parried = true
	_hit_applied = true

func apply_damage(amount: int) -> void:
	hp = max(hp - amount, 0)

func _apply_hit_once(damage: int) -> void:
	if _hit_applied:
		return
	_hit_applied = true
	emit_signal("attack_landed", damage)

func _current_pattern() -> int:
	return _pattern_index % 4

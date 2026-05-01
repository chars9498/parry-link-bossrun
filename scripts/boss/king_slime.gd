extends CharacterBody2D
class_name KingSlime

enum BossState { IDLE, TELEGRAPH, ATTACK, RECOVER }
enum Pattern { CHARGE, SLAM, SPIT, CROWN }

signal attack_telegraph(parry_total: float, parry_perfect: float, pattern_name: String)
signal attack_landed(base_damage: int)

@export var max_hp: int = 1400
@export var debug_draw_hitboxes: bool = false
@export var debug_log_hit_checks: bool = false
@export var tank_hurt_radius: float = 20.0
@export var spit_hit_radius: float = 12.0
@export var charge_hit_radius: float = 36.0
@export var slam_radius: float = 58.0
@export var crown_range: float = 90.0
@export var crown_angle_deg: float = 65.0
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
var _slam_target: Vector2 = Vector2.ZERO

var _strike_flash_t: float = 0.0

var _telegraph_type: int = -1
var _telegraph_t: float = 0.0
var _telegraph_total: float = 1.0
var _hitbox_active: bool = false
var _hitbox_active_t: float = 0.0
var _hitbox_active_total: float = 0.12

@onready var timer: Timer = $PatternTimer
@onready var body: Polygon2D = $BossBody
@onready var crown: Polygon2D = $Crown

func setup(tank: Tank) -> void:
	_tank = tank

func _ready() -> void:
	timer.timeout.connect(_start_pattern)

func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	if _projectile_active:
		_projectile_pos += _projectile_vel * delta
		var spit_distance: float = _projectile_pos.distance_to(_tank.global_position)
		var spit_threshold: float = spit_hit_radius + tank_hurt_radius
		var spit_overlap: bool = spit_distance <= spit_threshold
		if spit_overlap and not _parried:
			_log_hit_check("SPIT", spit_distance, tank_hurt_radius, spit_hit_radius, spit_threshold, true)
			_apply_hit_once(14)
			_projectile_active = false
		elif debug_log_hit_checks and _hitbox_active and int(Time.get_ticks_msec()) % 100 < 16:
			_log_hit_check("SPIT", spit_distance, tank_hurt_radius, spit_hit_radius, spit_threshold, false)
		if _projectile_pos.distance_to(global_position) > 700.0:
			_projectile_active = false
	if _strike_flash_t > 0.0:
		_strike_flash_t -= delta
	if _telegraph_type >= 0:
		_telegraph_t += delta
	if _hitbox_active:
		_hitbox_active_t += delta
		if _hitbox_active_t >= _hitbox_active_total:
			_hitbox_active = false
	queue_redraw()

func _draw() -> void:
	_draw_telegraph()
	if _projectile_active:
		draw_circle(_projectile_pos - global_position, 10.0, Color(0.4, 1.0, 0.55, 0.75))
		draw_circle(_projectile_pos - global_position, spit_hit_radius, Color(0.4, 1.0, 0.55, 0.18))
	if _strike_flash_t > 0.0:
		draw_circle(Vector2.ZERO, 48.0, Color(1.0, 0.95, 0.5, 0.25))
	if debug_draw_hitboxes:
		_draw_debug_hitboxes()

func _draw_telegraph() -> void:
	if _telegraph_type < 0:
		return
	var progress: float = clamp(_telegraph_t / max(_telegraph_total, 0.01), 0.0, 1.0)
	var warn_color: Color = Color(1.0, 0.75, 0.2, 0.24)
	if progress >= 0.78:
		warn_color = Color(1.0, 0.2, 0.2, 0.35 if int(progress * 16.0) % 2 == 0 else 0.18)
	if _hitbox_active:
		warn_color = Color(1.0, 1.0, 1.0, 0.45)
	match _telegraph_type:
		Pattern.CHARGE:
			draw_circle(Vector2.ZERO, charge_hit_radius, warn_color)
		Pattern.SLAM:
			draw_circle(_slam_target - global_position, slam_radius, warn_color)
		Pattern.SPIT:
			draw_circle(_projectile_pos - global_position if _projectile_active else Vector2.ZERO, spit_hit_radius, warn_color)
		Pattern.CROWN:
			var half_angle: float = deg_to_rad(crown_angle_deg * 0.5)
			draw_arc(Vector2.ZERO, crown_range, -half_angle, half_angle, 24, warn_color, 7.0)

func _draw_debug_hitboxes() -> void:
	draw_circle(_tank.global_position - global_position, tank_hurt_radius, Color(0.25, 0.9, 1.0, 0.28))
	if _state == BossState.ATTACK and _current_pattern() == Pattern.CHARGE:
		draw_circle(Vector2.ZERO, charge_hit_radius, Color(1.0, 0.2, 0.2, 0.25))
	if _state == BossState.ATTACK and _current_pattern() == Pattern.SLAM:
		draw_circle(Vector2.ZERO, slam_radius, Color(0.8, 0.3, 1.0, 0.24))
	if _state == BossState.ATTACK and _current_pattern() == Pattern.CROWN:
		var half_angle: float = deg_to_rad(crown_angle_deg * 0.5)
		draw_arc(Vector2.ZERO, crown_range, -half_angle, half_angle, 24, Color(1, 0.2, 0.1, 0.35), 8.0)
	if _projectile_active:
		draw_circle(_projectile_pos - global_position, spit_hit_radius, Color(0.2, 1.0, 0.6, 0.22))

func _start_pattern() -> void:
	if _tank == null or hp <= 0:
		return
	_parried = false
	_hit_applied = false
	_state = BossState.TELEGRAPH
	match _current_pattern():
		Pattern.CHARGE:
			await _pattern_charge()
		Pattern.SLAM:
			await _pattern_slam()
		Pattern.SPIT:
			await _pattern_spit()
		Pattern.CROWN:
			await _pattern_crown()
	_telegraph_type = -1
	_state = BossState.IDLE
	_pattern_index += 1

func _pattern_charge() -> void:
	_attack_dir = (_tank.global_position - global_position).normalized()
	await _telegraph(0.56, 0.18, "몸통 박치기")
	_state = BossState.ATTACK
	var dash_start: Vector2 = global_position
	var dash_target: Vector2 = dash_start + _attack_dir * 160.0
	var dash_duration: float = 0.40
	var elapsed: float = 0.0
	while elapsed < dash_duration:
		var t: float = elapsed / dash_duration
		global_position = dash_start.lerp(dash_target, t)
		body.scale = Vector2(1.06 + t * 0.08, 0.94 - t * 0.08)
		if t >= 0.72 and not _hitbox_active:
			_enable_hitbox_window(0.12)
		var charge_distance: float = global_position.distance_to(_tank.global_position)
		var charge_threshold: float = charge_hit_radius + tank_hurt_radius
		var charge_overlap: bool = charge_distance <= charge_threshold
		if _hitbox_active and not _parried and not _hit_applied and charge_overlap:
			_log_hit_check("CHARGE", charge_distance, tank_hurt_radius, charge_hit_radius, charge_threshold, true)
			_apply_hit_once(18)
		elif debug_log_hit_checks and _hitbox_active:
			_log_hit_check("CHARGE", charge_distance, tank_hurt_radius, charge_hit_radius, charge_threshold, false)
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	global_position = dash_target
	body.scale = Vector2.ONE
	_state = BossState.RECOVER
	await get_tree().create_timer(0.35).timeout

func _pattern_slam() -> void:
	_slam_target = _tank.global_position
	await _telegraph(0.82, 0.22, "점프 내려찍기")
	_state = BossState.ATTACK
	var jump_start: Vector2 = global_position
	var jump_duration: float = 0.62
	var elapsed: float = 0.0
	while elapsed < jump_duration:
		var t: float = elapsed / jump_duration
		var arc: float = sin(t * PI)
		global_position = jump_start.lerp(_slam_target, t)
		body.position.y = -arc * 24.0
		body.scale = Vector2(1.0 + arc * 0.1, 1.0 - arc * 0.1)
		if t >= 0.88 and not _hitbox_active:
			_enable_hitbox_window(0.10)
		var slam_distance: float = global_position.distance_to(_tank.global_position)
		var slam_threshold: float = slam_radius + tank_hurt_radius * 0.5
		var slam_overlap: bool = slam_distance <= slam_threshold
		if _hitbox_active and not _parried and not _hit_applied and slam_overlap:
			_log_hit_check("SLAM", slam_distance, tank_hurt_radius, slam_radius, slam_threshold, true)
			_apply_hit_once(22)
		elif debug_log_hit_checks and _hitbox_active:
			_log_hit_check("SLAM", slam_distance, tank_hurt_radius, slam_radius, slam_threshold, false)
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	global_position = _slam_target
	body.position = Vector2.ZERO
	body.scale = Vector2.ONE
	_strike_flash_t = 0.12
	_state = BossState.RECOVER
	await get_tree().create_timer(0.45).timeout

func _pattern_spit() -> void:
	await _telegraph(0.55, 0.16, "점액 뱉기")
	_state = BossState.ATTACK
	_enable_hitbox_window(0.12)
	_projectile_active = true
	_projectile_pos = global_position
	_projectile_vel = (_tank.global_position - global_position).normalized() * 170.0
	await get_tree().create_timer(1.2).timeout
	_projectile_active = false
	_state = BossState.RECOVER
	await get_tree().create_timer(0.28).timeout

func _pattern_crown() -> void:
	_attack_dir = (_tank.global_position - global_position).normalized()
	await _telegraph(0.72, 0.18, "왕관 내려찍기")
	crown.modulate = Color(1.0, 1.0, 0.65, 1.0)
	await get_tree().create_timer(0.14).timeout
	_state = BossState.ATTACK
	_enable_hitbox_window(0.11)
	_strike_flash_t = 0.16
	var dir_to_tank: Vector2 = (_tank.global_position - global_position).normalized()
	var crown_distance: float = global_position.distance_to(_tank.global_position)
	var crown_threshold: float = crown_range + tank_hurt_radius * 0.35
	var half_angle_rad: float = deg_to_rad(crown_angle_deg * 0.5)
	var crown_dot_threshold: float = cos(half_angle_rad)
	var front_dot: float = _attack_dir.dot(dir_to_tank)
	var in_range: bool = crown_distance <= crown_threshold
	var in_angle: bool = front_dot >= crown_dot_threshold
	if _hitbox_active and not _parried and not _hit_applied and in_range and in_angle:
		_log_hit_check("CROWN", crown_distance, tank_hurt_radius, crown_range, crown_threshold, true)
		_apply_hit_once(30)
	elif debug_log_hit_checks and _hitbox_active:
		_log_hit_check("CROWN", crown_distance, tank_hurt_radius, crown_range, crown_threshold, false)
	await get_tree().create_timer(0.08).timeout
	crown.modulate = Color(1, 0.8, 0.2, 1)
	_state = BossState.RECOVER
	await get_tree().create_timer(0.4).timeout

func _enable_hitbox_window(duration: float) -> void:
	_hitbox_active = true
	_hitbox_active_t = 0.0
	_hitbox_active_total = duration

func _telegraph(total: float, perfect: float, name: String) -> void:
	_telegraph_type = _current_pattern()
	_telegraph_t = 0.0
	_telegraph_total = total
	body.modulate = Color(1.0, 1.0, 1.0, 0.95)
	crown.modulate = Color(1.0, 0.9, 0.4, 1.0)
	emit_signal("attack_telegraph", total, perfect, name)
	await get_tree().create_timer(total).timeout
	body.modulate = Color(0.35, 0.85, 0.55, 0.85)
	crown.modulate = Color(1, 0.8, 0.2, 1)

func register_parry() -> void:
	_parried = true
	_hit_applied = true
	_strike_flash_t = 0.10
	if debug_log_hit_checks:
		print_debug("[KingSlime][PARRY] parry_active=true state=%s pattern=%d" % [_state, _current_pattern()])

func apply_damage(amount: int) -> void:
	hp = max(hp - amount, 0)

func _apply_hit_once(damage: int) -> void:
	if _hit_applied:
		return
	_hit_applied = true
	emit_signal("attack_landed", damage)

func _current_pattern() -> int:
	return _pattern_index % 4

func _log_hit_check(attack_type: String, distance_to_tank: float, tank_radius: float, attack_radius: float, threshold: float, did_hit: bool) -> void:
	if not debug_log_hit_checks:
		return
	var tank_parry_active: bool = _tank != null and _tank.parry_active_timer > 0.0
	print_debug("[KingSlime][%s] dist=%.2f tank_hurt=%.2f attack_radius=%.2f threshold=%.2f result=%s parry_active=%s" % [
		attack_type,
		distance_to_tank,
		tank_radius,
		attack_radius,
		threshold,
		"HIT" if did_hit else "MISS",
		str(tank_parry_active)
	])

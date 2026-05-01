extends CharacterBody2D
class_name KingSlime

enum BossState { IDLE, TELEGRAPH, ATTACK, RECOVER }
enum Pattern { CHARGE, SLAM, SPIT, CROWN }

signal attack_telegraph(parry_total: float, parry_perfect: float, pattern_name: String)
signal attack_landed(base_damage: int)

@export var max_hp: int = 1400
@export var debug_draw_hitboxes: bool = false
@export var debug_log_hit_checks: bool = false
@export var tank_hurt_radius: float = 22.0
@export var tank_parry_radius: float = 34.0
@export var spit_hit_radius: float = 18.0
@export var spit_parry_radius: float = 28.0
@export var charge_hit_radius: float = 38.0
@export var charge_parry_radius: float = 52.0
@export var slam_radius: float = 60.0
@export var slam_parry_radius: float = 76.0
@export var crown_range: float = 90.0
@export var crown_parry_range: float = 110.0
@export var crown_angle_deg: float = 65.0
@export var parry_pre_grace: float = 0.12
@export var parry_post_grace: float = 0.12
@export var spit_lifetime: float = 3.6
@export var spit_max_distance: float = 2100.0
@export var spit_speed: float = 175.0
@export var dash_distance: float = 320.0
@export var dash_duration: float = 0.62
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
var _parry_grace_active: bool = false
var _slam_air_arc: float = 0.0
var _slam_warn_t: float = 0.0
var _slam_ring_flash: float = 0.0

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
		var spit_parry_threshold: float = spit_parry_radius + tank_parry_radius
		var spit_parry_overlap: bool = spit_distance <= spit_parry_threshold
		var spit_parry_success: bool = _can_parry_now() and spit_parry_overlap
		if spit_parry_success and not _parried:
			_log_hit_check("SPIT", spit_distance, spit_threshold, spit_parry_threshold, true, false, "global/global")
			register_parry()
			_projectile_active = false
		elif spit_overlap and not _parried:
			_log_hit_check("SPIT", spit_distance, spit_threshold, spit_parry_threshold, false, true, "global/global")
			_apply_hit_once(14)
			_projectile_active = false
		elif debug_log_hit_checks and int(Time.get_ticks_msec()) % 100 < 16:
			_log_hit_check("SPIT", spit_distance, spit_threshold, spit_parry_threshold, false, false, "global/global")
		if _projectile_pos.distance_to(global_position) > spit_max_distance:
			_projectile_active = false
	if _strike_flash_t > 0.0:
		_strike_flash_t -= delta
	if _telegraph_type >= 0:
		_telegraph_t += delta
	if _hitbox_active:
		_hitbox_active_t += delta
		if _hitbox_active_t >= _hitbox_active_total:
			_hitbox_active = false
	if _slam_warn_t > 0.0:
		_slam_warn_t -= delta
	if _slam_ring_flash > 0.0:
		_slam_ring_flash -= delta
	queue_redraw()

func _draw() -> void:
	_draw_telegraph()
	if _projectile_active:
		draw_circle(_projectile_pos - global_position, 10.0, Color(0.4, 1.0, 0.55, 0.75))
		draw_circle(_projectile_pos - global_position, spit_hit_radius, Color(0.4, 1.0, 0.55, 0.18))
	if _strike_flash_t > 0.0:
		draw_circle(Vector2.ZERO, 48.0, Color(1.0, 0.95, 0.5, 0.25))
	_draw_slam_visuals()
	if debug_draw_hitboxes:
		_draw_debug_hitboxes()

func _draw_slam_visuals() -> void:
	if _state == BossState.ATTACK and _current_pattern() == Pattern.SLAM:
		var shadow_scale: float = lerp(0.45, 1.0, 1.0 - _slam_air_arc)
		var shadow_alpha: float = lerp(0.18, 0.34, 1.0 - _slam_air_arc)
		draw_circle(Vector2.ZERO, slam_radius * shadow_scale, Color(0.08, 0.1, 0.12, shadow_alpha))
		var blink: float = 0.22 if _slam_warn_t > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0 else 0.0
		var warn_alpha: float = 0.18 + blink
		draw_circle(_slam_target - global_position, slam_radius, Color(1.0, 0.3, 0.2, warn_alpha))
		draw_arc(_slam_target - global_position, slam_radius + 8.0, 0.0, TAU, 40, Color(1.0, 0.95, 0.45, warn_alpha + 0.12), 3.0)
	if _slam_ring_flash > 0.0:
		var flash_r: float = slam_radius + (1.0 - _slam_ring_flash / 0.22) * 26.0
		draw_arc(Vector2.ZERO, flash_r, 0.0, TAU, 44, Color(1.0, 1.0, 1.0, _slam_ring_flash), 6.0)

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
	draw_circle(_tank.global_position - global_position, tank_parry_radius, Color(0.3, 0.45, 1.0, 0.22))
	if _state == BossState.ATTACK and _current_pattern() == Pattern.CHARGE:
		draw_circle(Vector2.ZERO, charge_hit_radius, Color(1.0, 0.2, 0.2, 0.25))
		draw_circle(Vector2.ZERO, charge_parry_radius, Color(1.0, 1.0, 0.4, 0.18))
	if _state == BossState.ATTACK and _current_pattern() == Pattern.SLAM:
		draw_circle(Vector2.ZERO, slam_radius, Color(0.8, 0.3, 1.0, 0.24))
		draw_circle(Vector2.ZERO, slam_parry_radius, Color(1.0, 1.0, 0.4, 0.18))
	if _state == BossState.ATTACK and _current_pattern() == Pattern.CROWN:
		var half_angle: float = deg_to_rad(crown_angle_deg * 0.5)
		draw_arc(Vector2.ZERO, crown_range, -half_angle, half_angle, 24, Color(1, 0.2, 0.1, 0.35), 8.0)
		draw_arc(Vector2.ZERO, crown_parry_range, -half_angle, half_angle, 24, Color(1, 1, 1, 0.24), 6.0)
	if _projectile_active:
		draw_circle(_projectile_pos - global_position, spit_hit_radius, Color(0.2, 1.0, 0.6, 0.22))
		draw_circle(_projectile_pos - global_position, spit_parry_radius, Color(1.0, 1.0, 0.3, 0.16))

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
	await _open_parry_grace_window(parry_pre_grace)
	_state = BossState.ATTACK
	var dash_start: Vector2 = global_position
	var dash_target: Vector2 = dash_start + _attack_dir * dash_distance
	var elapsed: float = 0.0
	while elapsed < dash_duration:
		var t: float = elapsed / dash_duration
		global_position = dash_start.lerp(dash_target, t)
		body.scale = Vector2(1.08 + t * 0.18, 0.92 - t * 0.12)
		if t >= 0.72 and not _hitbox_active:
			_enable_hitbox_window(0.12)
		var charge_distance: float = global_position.distance_to(_tank.global_position)
		var charge_threshold: float = charge_hit_radius + tank_hurt_radius
		var charge_parry_threshold: float = charge_parry_radius + tank_parry_radius
		var charge_overlap: bool = charge_distance <= charge_threshold
		var charge_parry_overlap: bool = charge_distance <= charge_parry_threshold
		if _can_parry_now() and charge_parry_overlap and not _parried:
			_log_hit_check("CHARGE", charge_distance, charge_threshold, charge_parry_threshold, true, false, "global/global")
			register_parry()
		elif _hitbox_active and not _parried and not _hit_applied and charge_overlap:
			_log_hit_check("CHARGE", charge_distance, charge_threshold, charge_parry_threshold, false, true, "global/global")
			_apply_hit_once(18)
		elif debug_log_hit_checks and _hitbox_active:
			_log_hit_check("CHARGE", charge_distance, charge_threshold, charge_parry_threshold, false, false, "global/global")
		if _can_parry_now() and int(Time.get_ticks_msec() / 70) % 2 == 0:
			_strike_flash_t = max(_strike_flash_t, 0.03)
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	global_position = dash_target
	_parry_grace_active = false
	body.scale = Vector2.ONE
	_state = BossState.RECOVER
	await get_tree().create_timer(0.35).timeout

func _pattern_slam() -> void:
	_slam_target = _tank.global_position
	await _telegraph(0.82, 0.22, "점프 내려찍기")
	await _open_parry_grace_window(0.18)
	_state = BossState.ATTACK
	var jump_start: Vector2 = global_position
	var jump_duration: float = 0.62
	var elapsed: float = 0.0
	while elapsed < jump_duration:
		var t: float = elapsed / jump_duration
		var arc: float = sin(t * PI)
		_slam_air_arc = arc
		global_position = jump_start.lerp(_slam_target, t)
		body.position.y = -arc * 42.0
		body.scale = Vector2(1.0 + arc * 0.24, 1.0 - arc * 0.16)
		if t >= 0.74:
			_slam_warn_t = 0.16
		if t >= 0.88 and not _hitbox_active:
			_enable_hitbox_window(0.10)
		var slam_distance: float = global_position.distance_to(_tank.global_position)
		var slam_threshold: float = slam_radius + tank_hurt_radius * 0.5
		var slam_parry_threshold: float = slam_parry_radius + tank_parry_radius * 0.5
		var slam_overlap: bool = slam_distance <= slam_threshold
		var slam_parry_overlap: bool = slam_distance <= slam_parry_threshold
		if _can_parry_now() and slam_parry_overlap and not _parried:
			_log_hit_check("SLAM", slam_distance, slam_threshold, slam_parry_threshold, true, false, "global/global")
			register_parry()
		elif _hitbox_active and not _parried and not _hit_applied and slam_overlap:
			_log_hit_check("SLAM", slam_distance, slam_threshold, slam_parry_threshold, false, true, "global/global")
			_apply_hit_once(22)
		elif debug_log_hit_checks and _hitbox_active:
			_log_hit_check("SLAM", slam_distance, slam_threshold, slam_parry_threshold, false, false, "global/global")
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	global_position = _slam_target
	body.position = Vector2.ZERO
	body.scale = Vector2.ONE
	_slam_air_arc = 0.0
	_slam_ring_flash = 0.22
	_strike_flash_t = 0.12
	_parry_grace_active = false
	_state = BossState.RECOVER
	await get_tree().create_timer(0.45).timeout

func _pattern_spit() -> void:
	await _telegraph(0.55, 0.16, "점액 뱉기")
	await _open_parry_grace_window(parry_pre_grace)
	_state = BossState.ATTACK
	_enable_hitbox_window(0.12)
	_projectile_active = true
	_projectile_pos = global_position
	_projectile_vel = (_tank.global_position - global_position).normalized() * spit_speed
	await get_tree().create_timer(spit_lifetime).timeout
	_projectile_active = false
	_parry_grace_active = false
	_state = BossState.RECOVER
	await get_tree().create_timer(0.28).timeout

func _pattern_crown() -> void:
	_attack_dir = (_tank.global_position - global_position).normalized()
	await _telegraph(0.72, 0.18, "왕관 내려찍기")
	crown.modulate = Color(1.0, 1.0, 0.65, 1.0)
	await _open_parry_grace_window(0.15)
	await get_tree().create_timer(0.14).timeout
	_state = BossState.ATTACK
	_enable_hitbox_window(0.11)
	_strike_flash_t = 0.16
	var dir_to_tank: Vector2 = (_tank.global_position - global_position).normalized()
	var crown_distance: float = global_position.distance_to(_tank.global_position)
	var crown_threshold: float = crown_range + tank_hurt_radius * 0.35
	var crown_parry_threshold: float = crown_parry_range + tank_parry_radius * 0.35
	var half_angle_rad: float = deg_to_rad(crown_angle_deg * 0.5)
	var crown_dot_threshold: float = cos(half_angle_rad)
	var front_dot: float = _attack_dir.dot(dir_to_tank)
	var in_range: bool = crown_distance <= crown_threshold
	var in_parry_range: bool = crown_distance <= crown_parry_threshold
	var in_angle: bool = front_dot >= crown_dot_threshold
	if _can_parry_now() and in_parry_range and in_angle and not _parried:
		_log_hit_check("CROWN", crown_distance, crown_threshold, crown_parry_threshold, true, false, "global/global")
		register_parry()
	elif _hitbox_active and not _parried and not _hit_applied and in_range and in_angle:
		_log_hit_check("CROWN", crown_distance, crown_threshold, crown_parry_threshold, false, true, "global/global")
		_apply_hit_once(30)
	elif debug_log_hit_checks and _hitbox_active:
		_log_hit_check("CROWN", crown_distance, crown_threshold, crown_parry_threshold, false, false, "global/global")
	await get_tree().create_timer(0.08).timeout
	crown.modulate = Color(1, 0.8, 0.2, 1)
	_parry_grace_active = false
	_state = BossState.RECOVER
	await get_tree().create_timer(0.4).timeout

func _enable_hitbox_window(duration: float) -> void:
	_hitbox_active = true
	_hitbox_active_t = 0.0
	_hitbox_active_total = duration
	_parry_grace_active = true
	_close_parry_grace_later(duration + parry_post_grace)

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

func _can_parry_now() -> bool:
	return _tank != null and _tank.parry_active_timer > 0.0 and (_parry_grace_active or _hitbox_active)

func _open_parry_grace_window(pre_grace: float) -> void:
	_parry_grace_active = true
	await get_tree().create_timer(pre_grace).timeout

func _close_parry_grace_later(delay: float) -> void:
	await get_tree().create_timer(max(delay, 0.01)).timeout
	_parry_grace_active = false

func _log_hit_check(attack_type: String, distance_to_tank: float, damage_threshold: float, parry_threshold: float, parry_success: bool, damage_success: bool, position_basis: String) -> void:
	if not debug_log_hit_checks:
		return
	var tank_parry_active: bool = _tank != null and _tank.parry_active_timer > 0.0
	print_debug("[KingSlime][%s] dist=%.2f damage_th=%.2f parry_th=%.2f tank_parry_active=%s parry_success=%s damage_success=%s basis=%s" % [
		attack_type,
		distance_to_tank,
		damage_threshold,
		parry_threshold,
		str(tank_parry_active),
		str(parry_success),
		str(damage_success),
		position_basis
	])

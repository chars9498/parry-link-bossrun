extends CharacterBody2D
class_name Dealer

signal link_skill_fired(skill_name: String, damage: int, perfect: bool)
signal basic_attack_fired(damage: int)

enum Role { ARCHER, MAGE, ROGUE }

@export var max_hp: int = 100
@export var follow_speed: float = 260.0
@export var follow_distance: float = 30.0

var hp: int = max_hp
var role: int = Role.ARCHER
var stunned: bool = false
var revive_gauge: float = 0.0
var _tank: Tank
var _boss: CharacterBody2D
@onready var _basic_timer: Timer = $BasicAttackTimer

func setup(tank: Tank, boss: CharacterBody2D) -> void:
	_tank = tank
	_boss = boss

func _physics_process(_delta: float) -> void:
	if _tank == null:
		return
	var dir: Vector2 = _tank.global_position - global_position
	var target: Vector2 = _tank.global_position - dir.normalized() * follow_distance
	velocity = (target - global_position) * 5.5
	if velocity.length() > follow_speed:
		velocity = velocity.normalized() * follow_speed
	move_and_slide()

func _on_basic_attack_timer_timeout() -> void:
	if stunned or _boss == null:
		return
	emit_signal("basic_attack_fired", basic_damage())

func cycle_role() -> void:
	role = (role + 1) % 3
	_update_color()

func set_role(new_role: int) -> void:
	role = new_role
	_update_color()

func get_role_name() -> String:
	var names: Array[String] = ["궁수", "마법사", "도적"]
	return names[role]

func on_tank_hit(damage: int) -> void:
	hp = max(hp - damage, 0)
	if hp == 0:
		stunned = true

func on_parry_while_stunned(amount: float) -> void:
	if not stunned:
		return
	revive_gauge = min(revive_gauge + amount, 100.0)
	if revive_gauge >= 100.0:
		stunned = false
		hp = int(max_hp * 0.5)
		revive_gauge = 0.0

func fire_link_skill(perfect: bool, berserker_bonus: float) -> Dictionary:
	if stunned:
		return {"name":"기절", "damage":0, "perfect":false}

	var base_table: Dictionary = {Role.ARCHER: 28, Role.MAGE: 34, Role.ROGUE: 24}
	var names_table: Dictionary = {Role.ARCHER: "관통 화살", Role.MAGE: "화염 폭발", Role.ROGUE: "그림자 찌르기"}
	var base_damage: int = int(base_table.get(role, 24))
	var skill_name: String = String(names_table.get(role, "관통 화살"))
	var perfect_bonus: float = 0.6 if perfect else 0.0
	var multiplier: float = 1.0 + berserker_bonus + perfect_bonus
	var damage: int = int(round(base_damage * multiplier))

	emit_signal("link_skill_fired", skill_name, damage, perfect)
	return {"name": skill_name, "damage": damage, "perfect": perfect}

func trigger_link_skill(perfect: bool, berserker_bonus: float) -> Dictionary:
	return fire_link_skill(perfect, berserker_bonus)

func basic_damage() -> int:
	var table: Dictionary = {Role.ARCHER: 8, Role.MAGE: 10, Role.ROGUE: 7}
	return int(table.get(role, 7))

func _update_color() -> void:
	var colors: Array[Color] = [Color(1, 0.7, 0.4), Color(0.7, 0.5, 1), Color(1, 1, 0.5)]
	$DealerSprite.color = colors[role]

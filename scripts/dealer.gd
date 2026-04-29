extends CharacterBody2D
class_name Dealer

enum Role { ARCHER, MAGE, ROGUE }

signal basic_attack_fired(damage: int)
signal link_skill_fired(name: String, damage: int, empowered: bool)

@export var max_hp := 100
@export var follow_speed := 260.0
@export var follow_distance := 30.0

var hp := max_hp
var role := Role.ARCHER
var stunned := false
var revive_gauge := 0.0
var _tank: Tank
var _boss: CharacterBody2D
@onready var _basic_timer: Timer = $BasicAttackTimer

func setup(tank: Tank, boss: CharacterBody2D) -> void:
	_tank = tank
	_boss = boss

func _physics_process(_delta: float) -> void:
	if _tank == null:
		return
	var dir := (_tank.global_position - global_position)
	var target := _tank.global_position - dir.normalized() * follow_distance
	velocity = (target - global_position) * 5.5
	if velocity.length() > follow_speed:
		velocity = velocity.normalized() * follow_speed
	move_and_slide()

func _on_basic_attack_timer_timeout() -> void:
	if stunned or _boss == null:
		return
	emit_signal("basic_attack_fired", _basic_damage())

func cycle_role() -> void:
	role = (role + 1) % 3
	_update_color()

func set_role(new_role: int) -> void:
	role = new_role
	_update_color()

func get_role_name() -> String:
	return ["궁수", "마법사", "도적"][role]

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

func trigger_link_skill(perfect: bool, berserker_bonus: float) -> Dictionary:
	if stunned:
		return {"name":"기절", "damage":0, "empowered":false}
	var base: int = {Role.ARCHER: 28, Role.MAGE: 34, Role.ROGUE: 24}[role]
	var mult := 1.0 + berserker_bonus + (0.6 if perfect else 0.0)
	var dmg := int(round(base * mult))
	var names := {Role.ARCHER:"관통 화살", Role.MAGE:"화염 폭발", Role.ROGUE:"그림자 찌르기"}
	emit_signal("link_skill_fired", names[role], dmg, perfect)
	return {"name":names[role], "damage":dmg, "empowered":perfect}

func _basic_damage() -> int:
	return {Role.ARCHER:8, Role.MAGE:10, Role.ROGUE:7}[role]

func _update_color() -> void:
	$DealerSprite.color = [Color(1,0.7,0.4), Color(0.7,0.5,1), Color(1,1,0.5)][role]

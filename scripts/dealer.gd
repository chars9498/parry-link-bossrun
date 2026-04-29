extends CharacterBody2D
class_name Dealer

signal link_skill_fired(skill_name: String, damage: int, perfect: bool)
signal basic_attack_fired(damage: int)

enum Role { ARCHER, MAGE, ROGUE }

var role: int = Role.ARCHER
var hp: int = 100
var max_hp: int = 100
var stunned: bool = false
var revive_gauge: float = 0.0
var target: Node2D = null

@export var follow_speed: float = 260.0
@export var follow_distance: float = 30.0

func setup(tank_target: Node2D, _boss: CharacterBody2D) -> void:
	target = tank_target

func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var offset: Vector2 = target.global_position - global_position
	if offset.length() <= 0.001:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var follow_position: Vector2 = target.global_position - offset.normalized() * follow_distance
	velocity = (follow_position - global_position) * 5.5
	if velocity.length() > follow_speed:
		velocity = velocity.normalized() * follow_speed
	move_and_slide()

func _on_basic_attack_timer_timeout() -> void:
	if stunned:
		return
	emit_signal("basic_attack_fired", basic_damage())

func set_role(new_role: int) -> void:
	role = new_role
	if role < 0:
		role = 0
	if role > 2:
		role = 2
	_update_color()

func cycle_role() -> void:
	set_role((role + 1) % 3)

func take_shared_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	if hp == 0:
		stunned = true

func add_revive_progress(amount: float) -> void:
	if not stunned:
		return
	revive_gauge = min(revive_gauge + amount, 100.0)
	if revive_gauge >= 100.0:
		revive_gauge = 0.0
		stunned = false
		hp = int(max_hp * 0.5)

func fire_link_skill(perfect: bool, berserker_bonus: float) -> Dictionary:
	if stunned:
		return {"name": "기절", "damage": 0, "perfect": false}

	var name_table: Dictionary = {
		Role.ARCHER: "관통 화살",
		Role.MAGE: "화염 폭발",
		Role.ROGUE: "그림자 찌르기"
	}
	var link_damage_table: Dictionary = {
		Role.ARCHER: 28,
		Role.MAGE: 34,
		Role.ROGUE: 24
	}

	var skill_name: String = String(name_table.get(role, "관통 화살"))
	var base_damage: int = int(link_damage_table.get(role, 24))
	var perfect_bonus: float = 0.0
	if perfect:
		perfect_bonus = 0.6
	var multiplier: float = 1.0 + berserker_bonus + perfect_bonus
	var final_damage: int = int(round(float(base_damage) * multiplier))

	emit_signal("link_skill_fired", skill_name, final_damage, perfect)
	return {"name": skill_name, "damage": final_damage, "perfect": perfect}

func trigger_link_skill(perfect: bool, berserker_bonus: float) -> Dictionary:
	return fire_link_skill(perfect, berserker_bonus)

func basic_damage() -> int:
	var basic_table: Dictionary = {
		Role.ARCHER: 8,
		Role.MAGE: 10,
		Role.ROGUE: 7
	}
	return int(basic_table.get(role, 7))

func get_role_name() -> String:
	var role_name_table: Dictionary = {
		Role.ARCHER: "궁수",
		Role.MAGE: "마법사",
		Role.ROGUE: "도적"
	}
	return String(role_name_table.get(role, "궁수"))

func _update_color() -> void:
	var color_table: Dictionary = {
		Role.ARCHER: Color(1.0, 0.7, 0.4),
		Role.MAGE: Color(0.7, 0.5, 1.0),
		Role.ROGUE: Color(1.0, 1.0, 0.5)
	}
	$DealerSprite.color = Color(color_table.get(role, Color(1.0, 0.7, 0.4)))
	if has_node("WeaponIcon"):
		var w: Polygon2D = $WeaponIcon
		if role == Role.ARCHER:
			w.color = Color(0.9, 0.85, 0.4)
			w.polygon = PackedVector2Array(-2,-6, 2,-6, 2,6, -2,6)
		elif role == Role.MAGE:
			w.color = Color(0.6, 0.8, 1.0)
			w.polygon = PackedVector2Array(-2,-6, 2,-6, 2,2, 5,5, -5,5, -2,2)
		else:
			w.color = Color(0.7, 0.9, 0.7)
			w.polygon = PackedVector2Array(-1,-5, 1,-5, 4,4, -4,4)

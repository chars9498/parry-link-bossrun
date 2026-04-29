extends Node2D

@onready var tank: Tank = $World/Tank
@onready var dealer: Dealer = $World/Dealer
@onready var boss: KingSlime = $World/KingSlime

@onready var tank_hp_label: Label = $UI/HUD/TankHP
@onready var dealer_hp_label: Label = $UI/HUD/DealerHP
@onready var dealer_state_label: Label = $UI/HUD/DealerState
@onready var boss_hp_label: Label = $UI/HUD/BossHP
@onready var dealer_role_label: Label = $UI/HUD/DealerRole
@onready var berserker_label: Label = $UI/HUD/Berserker
@onready var feedback_label: Label = $UI/HUD/Feedback
@onready var choose_panel: Panel = $UI/RoleSelect

var current_pattern: String = ""

func _ready() -> void:
	dealer.setup(tank, boss)
	boss.setup(tank)
	tank.parry_attempted.connect(_on_parry_attempted)
	boss.attack_telegraph.connect(_on_attack_telegraph)
	boss.attack_landed.connect(_on_attack_landed)
	dealer.basic_attack_fired.connect(_on_dealer_basic_attack)
	dealer.link_skill_fired.connect(_on_link_skill_fired)
	_update_ui("딜러를 선택하세요")
	get_tree().paused = true

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_select") and get_tree().paused == false:
		dealer.cycle_role()
		_update_ui("딜러 변경")

func _on_role_button_pressed(role_index: int) -> void:
	dealer.set_role(role_index)
	choose_panel.visible = false
	get_tree().paused = false
	_update_ui("전투 시작")

func _on_attack_telegraph(total: float, perfect: float, name: String) -> void:
	current_pattern = name
	tank.open_parry_window(total, perfect)
	_update_ui("%s 예고" % name)

func _on_parry_attempted() -> void:
	var result: int = tank.get_parry_result()
	if result == ParryTypes.Result.FAIL:
		_update_ui("패링 실패")
		return
	boss.register_parry()
	tank.set_invincible(0.45)
	var bonus: float = _berserker_bonus()
	var is_perfect: bool = result == ParryTypes.Result.PERFECT
	var link: Dictionary = dealer.fire_link_skill(is_perfect, bonus)
	if dealer.stunned:
		dealer.add_revive_progress(35.0)
	if is_perfect:
		tank.set_invincible(0.7)
		feedback_label.text = "완벽 패링! %s 강화" % String(link.get("name", "링크 스킬"))
	else:
		feedback_label.text = "패링 성공! %s" % String(link.get("name", "링크 스킬"))
	_update_ui(feedback_label.text)

func _on_attack_landed(damage: int) -> void:
	if tank.take_damage(damage):
		dealer.take_shared_damage(damage)
	_update_ui("%s 피격" % current_pattern)

func _on_dealer_basic_attack(damage: int) -> void:
	boss.apply_damage(damage)
	_update_ui("딜러 평타 %d" % damage)

func _on_link_skill_fired(_skill_name: String, damage: int, _perfect: bool) -> void:
	boss.apply_damage(damage)

func _berserker_bonus() -> float:
	var ratio: float = float(tank.hp) / float(tank.max_hp)
	if ratio <= 0.10:
		return 1.20
	if ratio <= 0.30:
		return 0.70
	if ratio <= 0.50:
		return 0.35
	if ratio <= 0.70:
		return 0.15
	return 0.0

func _update_ui(msg: String) -> void:
	tank_hp_label.text = "탱커 HP: %d/%d" % [tank.hp, tank.max_hp]
	dealer_hp_label.text = "딜러 HP: %d/%d" % [dealer.hp, dealer.max_hp]
	dealer_state_label.text = "딜러 상태: %s | 부활 %.0f%%" % [("기절" if dealer.stunned else "전투"), dealer.revive_gauge]
	boss_hp_label.text = "보스 HP: %d/%d" % [boss.hp, boss.max_hp]
	dealer_role_label.text = "현재 딜러: %s" % dealer.get_role_name()
	berserker_label.text = "버서커 보너스: +%d%%" % int(_berserker_bonus() * 100.0)
	feedback_label.text = msg
	if tank.hp <= 0:
		feedback_label.text = "전투 실패"
		get_tree().paused = true

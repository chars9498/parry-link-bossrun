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
@onready var role_buttons: Array[Button] = [
	$UI/RoleSelect/RoleVBox/Archer,
	$UI/RoleSelect/RoleVBox/Mage,
	$UI/RoleSelect/RoleVBox/Rogue
]

var current_pattern: String = ""
var combat_started: bool = false
var selected_role_index: int = 0

func _ready() -> void:
	dealer.setup(tank, boss)
	boss.setup(tank)
	tank.parry_attempted.connect(_on_parry_attempted)
	boss.attack_telegraph.connect(_on_attack_telegraph)
	boss.attack_landed.connect(_on_attack_landed)
	dealer.basic_attack_fired.connect(_on_dealer_basic_attack)
	dealer.link_skill_fired.connect(_on_link_skill_fired)

	choose_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	for button in role_buttons:
		button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	selected_role_index = 0
	role_buttons[selected_role_index].grab_focus()
	_update_ui("딜러를 선택하세요")
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if combat_started:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_on_role_button_pressed(selected_role_index)
		get_viewport().set_input_as_handled()

func _move_selection(direction: int) -> void:
	selected_role_index = (selected_role_index + direction + role_buttons.size()) % role_buttons.size()
	role_buttons[selected_role_index].grab_focus()

func _process(_delta: float) -> void:
	if combat_started and Input.is_action_just_pressed("ui_select"):
		dealer.cycle_role()
		_update_ui("딜러 변경")

func _on_role_button_pressed(role_index: int) -> void:
	selected_role_index = role_index
	dealer.set_role(role_index)
	choose_panel.visible = false
	combat_started = true
	get_tree().paused = false
	_update_ui("전투 시작")

func _on_attack_telegraph(total: float, perfect: float, name: String) -> void:
	if not combat_started:
		return
	current_pattern = name
	tank.open_parry_window(total, perfect)
	_update_ui("%s 예고" % name)

func _on_parry_attempted() -> void:
	if not combat_started:
		return
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
	if not combat_started:
		return
	if tank.take_damage(damage):
		dealer.take_shared_damage(damage)
	_update_ui("%s 피격" % current_pattern)

func _on_dealer_basic_attack(damage: int) -> void:
	if not combat_started:
		return
	boss.apply_damage(damage)
	_update_ui("딜러 평타 %d" % damage)

func _on_link_skill_fired(_skill_name: String, damage: int, _perfect: bool) -> void:
	if not combat_started:
		return
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
	dealer_state_label.text = "딜러 상태: %s | 부활 %.0f%%" % [(("기절") if dealer.stunned else "전투"), dealer.revive_gauge]
	boss_hp_label.text = "보스 HP: %d/%d" % [boss.hp, boss.max_hp]
	dealer_role_label.text = "현재 딜러: %s" % dealer.get_role_name()
	berserker_label.text = "버서커 보너스: +%d%%" % int(_berserker_bonus() * 100.0)
	feedback_label.text = msg
	if tank.hp <= 0:
		feedback_label.text = "전투 실패"
		get_tree().paused = true

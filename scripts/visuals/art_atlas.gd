extends Node2D
class_name ArtAtlasDirector

const TANK_ART_PATH: String = "res://assets/art/tank_reference.png"
const DEALER_ART_PATH: String = "res://assets/art/dealer_reference.png"
const SLIME_ART_PATH: String = "res://assets/art/king_slime_reference.png"
const VFX_ART_PATH: String = "res://assets/art/vfx_reference.png"
const PROPS_ART_PATH: String = "res://assets/art/props_reference.png"
const TILESET_ART_PATH: String = "res://assets/art/tileset_reference.png"
const TANK_ANIM_PATH: String = "res://assets/art/tank_anim_sheet.png"
const ARCHER_ANIM_PATH: String = "res://assets/art/archer_anim_sheet.png"
const SLIME_ANIM_PATH: String = "res://assets/art/king_slime_anim_sheet.png"

const TANK_COLS: int = 8
const TANK_ROWS: int = 8
const ARCHER_COLS: int = 8
const ARCHER_ROWS: int = 6
const SLIME_COLS: int = 6
const SLIME_ROWS: int = 4

@export var debug_show_full_atlas: bool = false
@export var tank_visual_multiplier: float = 2.8
@export var dealer_visual_multiplier: float = 0.8
@export var tank_cell_w: int = 0
@export var tank_cell_h: int = 0
@export var archer_cell_w: int = 0
@export var archer_cell_h: int = 0
@export var slime_cell_w: int = 0
@export var slime_cell_h: int = 0
@export var simplify_anim_to_first_frame: bool = true

var _tank_tex: Texture2D
var _dealer_tex: Texture2D
var _slime_tex: Texture2D
var _vfx_tex: Texture2D
var _props_tex: Texture2D
var _tiles_tex: Texture2D
var _tank_anim_tex: Texture2D
var _archer_anim_tex: Texture2D
var _slime_anim_tex: Texture2D

var _tank_cell: Vector2 = Vector2.ZERO
var _dealer_cell: Vector2 = Vector2.ZERO
var _slime_cell: Vector2 = Vector2.ZERO

@onready var _world: Node2D = get_parent().get_node("World") as Node2D
@onready var _tank: Node2D = _world.get_node("Tank") as Node2D
@onready var _dealer: Dealer = _world.get_node("Dealer") as Dealer
@onready var _boss: Node2D = _world.get_node("KingSlime") as Node2D
@onready var _decor: Node2D = _world.get_node("Decor") as Node2D

var _tank_sprite: Sprite2D
var _dealer_sprite: Sprite2D
var _boss_sprite: Sprite2D
var _parry_fx: Sprite2D
var _tank_anim_state: String = "idle"
var _archer_anim_state: String = "idle"
var _slime_anim_state: String = "idle"
var _tank_anim_t: float = 0.0
var _archer_anim_t: float = 0.0
var _slime_anim_t: float = 0.0
var _tank_frame: int = 0
var _archer_frame: int = 0
var _slime_frame: int = 0

func _ready() -> void:
	_tank_tex = _load_texture(TANK_ART_PATH, "Tank")
	_dealer_tex = _load_texture(DEALER_ART_PATH, "Dealer")
	_slime_tex = _load_texture(SLIME_ART_PATH, "KingSlime")
	_vfx_tex = _load_texture(VFX_ART_PATH, "VFX")
	_props_tex = _load_texture(PROPS_ART_PATH, "Props")
	_tiles_tex = _load_texture(TILESET_ART_PATH, "Tileset")
	_tank_anim_tex = _load_texture(TANK_ANIM_PATH, "TankAnim")
	_archer_anim_tex = _load_texture(ARCHER_ANIM_PATH, "ArcherAnim")
	_slime_anim_tex = _load_texture(SLIME_ANIM_PATH, "SlimeAnim")
	_log_anim_sheet_sizes()
	_compute_cells()
	_apply_environment_art()
	_apply_character_art()
	_connect_feedback()

func _process(delta: float) -> void:
	_update_dealer_role_region()
	_update_boss_region()
	_update_animation_states(delta)

func _load_texture(path: String, label: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_error("[ArtAtlas] Missing texture file for %s: %s" % [label, path])
		return null
	var res: Resource = load(path)
	if res == null or not (res is Texture2D):
		push_error("[ArtAtlas] Failed to load Texture2D for %s: %s" % [label, path])
		return null
	var tex: Texture2D = res as Texture2D
	var tex_size: Vector2 = tex.get_size()
	print("[ArtAtlas] Loaded %s %s size=%s" % [label, path, tex_size])
	return tex

func _compute_cells() -> void:
	if _tank_tex != null:
		var s: Vector2 = _tank_tex.get_size()
		_tank_cell = Vector2(max(s.x / 4.0, 1.0), max(s.y / 2.0, 1.0))
		print("[ArtAtlas] tank cell=", _tank_cell)
	if _dealer_tex != null:
		var ds: Vector2 = _dealer_tex.get_size()
		_dealer_cell = Vector2(max(ds.x / 4.0, 1.0), max(ds.y / 3.0, 1.0))
		print("[ArtAtlas] dealer cell=", _dealer_cell)
	if _slime_tex != null:
		var ss: Vector2 = _slime_tex.get_size()
		_slime_cell = Vector2(max(ss.x / 2.0, 1.0), max(ss.y / 3.0, 1.0))
		print("[ArtAtlas] slime cell=", _slime_cell, " (2 cols x 3 rows)")

func _apply_environment_art() -> void:
	if _tiles_tex != null and _world.get_node_or_null("ArenaTileSprite") == null:
		var floor: Sprite2D = Sprite2D.new()
		floor.name = "ArenaTileSprite"
		floor.texture = _tiles_tex
		floor.region_enabled = not debug_show_full_atlas
		if floor.region_enabled:
			floor.region_rect = _safe_region_rect(_tiles_tex, Rect2(Vector2.ZERO, Vector2(256, 256)))
		floor.centered = true
		floor.position = Vector2(480, 270)
		floor.scale = Vector2(3.75, 2.1)
		floor.z_index = -20
		floor.visible = true
		floor.modulate = Color(1, 1, 1, 1)
		_world.add_child(floor)
		_world.move_child(floor, 0)
	if _props_tex != null:
		for child in _decor.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		var points: Array[Vector2] = [Vector2(110, 120), Vector2(850, 120), Vector2(140, 470), Vector2(820, 470), Vector2(700, 410), Vector2(510, 470)]
		for i in range(points.size()):
			var prop: Sprite2D = Sprite2D.new()
			prop.texture = _props_tex
			prop.region_enabled = not debug_show_full_atlas
			if prop.region_enabled:
				prop.region_rect = _safe_region_rect(_props_tex, Rect2(Vector2(32 * (i % 3), 32 * int(i / 3)), Vector2(32, 32)))
			prop.position = points[i]
			prop.scale = Vector2(1.4, 1.4)
			prop.z_index = -2
			prop.visible = true
			prop.modulate = Color(1, 1, 1, 1)
			_decor.add_child(prop)

func _apply_character_art() -> void:
	_tank_sprite = _ensure_sprite(_tank, "ArtTankSprite")
	_dealer_sprite = _ensure_sprite(_dealer, "DealerArt")
	_boss_sprite = _ensure_sprite(_boss, "BossArt")
	_parry_fx = _ensure_sprite(_tank, "ParryFX")
	_parry_fx.visible = false
	_parry_fx.z_index = 8

	_apply_tank_texture(_tank_sprite, _tank_tex, Rect2(Vector2.ZERO, _tank_cell), _uniform_scale_for_target(_tank_cell, 160.0), 32)
	_apply_actor_texture(_dealer_sprite, _dealer_tex, _dealer_cell, Rect2(Vector2.ZERO, _dealer_cell), _uniform_scale_for_target(_dealer_cell, 76.0), 30, "Dealer")
	_apply_actor_texture(_boss_sprite, _slime_tex, _slime_cell, Rect2(Vector2.ZERO, _slime_cell), _uniform_scale_for_target(_slime_cell, 160.0), 25, "Boss")
	_add_shadow(_tank, "TankShadow", Vector2(40, 16), 27)
	_add_shadow(_dealer, "DealerShadow", Vector2(34, 14), 26)
	_add_shadow(_boss, "BossShadow", Vector2(66, 24), 24)
	_add_rim(_tank, _tank_sprite, "TankRim", 31)
	_add_rim(_dealer, _dealer_sprite, "DealerRim", 29)

	if _vfx_tex != null:
		_parry_fx.texture = _vfx_tex
		_parry_fx.region_enabled = true
		_parry_fx.region_rect = _safe_region_rect(_vfx_tex, Rect2(Vector2.ZERO, Vector2(32, 32)))
		_parry_fx.scale = Vector2(1.6, 1.6)
		_parry_fx.visible = false
		_parry_fx.modulate = Color(1, 1, 1, 1)

func _apply_tank_texture(sp: Sprite2D, tex: Texture2D, first_rect: Rect2, base_scale: Vector2, z: int) -> void:
	if tex == null:
		print("[ArtAtlas] TANK texture null -> keep fallback polygons")
		_show_fallback("Tank")
		return
	sp.texture = _tank_anim_tex if _tank_anim_tex != null else tex
	sp.region_enabled = not debug_show_full_atlas
	if sp.region_enabled:
		var active_tex: Texture2D = sp.texture
		var base_rect: Rect2 = _safe_region_rect(active_tex, Rect2(first_rect.position, _cell_size_for(active_tex, TANK_COLS, TANK_ROWS, tank_cell_w, tank_cell_h)))
		var tight_rect: Rect2 = _tight_alpha_rect(active_tex, base_rect, 2)
		sp.region_rect = tight_rect
		if not _region_has_visible_pixels(active_tex, sp.region_rect):
			push_warning("[ArtAtlas] TANK region empty: %s" % [sp.region_rect])
			_show_fallback("Tank")
			return
	sp.visible = true
	sp.offset = Vector2(0, -14)
	var final_scale: Vector2 = base_scale * tank_visual_multiplier
	sp.scale = final_scale
	sp.z_index = z
	sp.modulate = Color(1, 1, 1, 1)
	print("[ArtAtlas] TANK texture size=", tex.get_size())
	print("[ArtAtlas] TANK region=", sp.region_rect)
	print("[ArtAtlas] TANK base_scale=", base_scale)
	print("[ArtAtlas] TANK visual_multiplier=", tank_visual_multiplier)
	print("[ArtAtlas] TANK final_scale=", final_scale)
	print("[ArtAtlas] TANK sprite.scale after assignment=", sp.scale, " name=", sp.name)
	_hide_actor_fallback("Tank")

func _apply_actor_texture(sp: Sprite2D, tex: Texture2D, cell: Vector2, first_rect: Rect2, scale_xy: Vector2, z: int, label: String) -> void:
	if tex == null:
		print("[ArtAtlas] %s texture null -> keep fallback polygons" % label)
		_show_fallback(label)
		return
	if label == "Dealer" and _dealer.role == Dealer.Role.ARCHER and _archer_anim_tex != null:
		sp.texture = _archer_anim_tex
	elif label == "Boss" and _slime_anim_tex != null:
		sp.texture = _slime_anim_tex
	else:
		sp.texture = tex
	sp.region_enabled = not debug_show_full_atlas
	if sp.region_enabled:
		var active_tex: Texture2D = sp.texture
		var base_size: Vector2 = _cell_size_for(active_tex, ARCHER_COLS if label == "Dealer" else SLIME_COLS if label == "Boss" else TANK_COLS, ARCHER_ROWS if label == "Dealer" else SLIME_ROWS if label == "Boss" else TANK_ROWS, archer_cell_w if label == "Dealer" else slime_cell_w if label == "Boss" else tank_cell_w, archer_cell_h if label == "Dealer" else slime_cell_h if label == "Boss" else tank_cell_h)
		var base_rect: Rect2 = _safe_region_rect(active_tex, Rect2(first_rect.position, base_size))
		var tight_rect: Rect2 = _tight_alpha_rect(active_tex, base_rect, 2)
		if label == "Tank":
			sp.region_rect = tight_rect
		elif label == "Dealer":
			sp.region_rect = _blend_rect(base_rect, tight_rect, 0.55)
		else:
			sp.region_rect = base_rect
		if not _region_has_visible_pixels(active_tex, sp.region_rect):
			push_warning("[ArtAtlas] %s region seems empty: %s. Keeping fallback polygons." % [label, sp.region_rect])
			_show_fallback(label)
			return
	sp.visible = true
	sp.scale = scale_xy
	if label == "Tank":
		sp.offset = Vector2(0, -7)
	elif label == "Dealer":
		sp.offset = Vector2(2, -5)
	else:
		sp.offset = Vector2(0, -6)
	sp.z_index = z
	sp.modulate = Color(1, 1, 1, 1)
	var src_size: Vector2 = sp.region_rect.size if sp.region_enabled else tex.get_size()
	var display_size: Vector2 = Vector2(src_size.x * sp.scale.x, src_size.y * sp.scale.y)
	print("[ArtAtlas] %s sprite visible=%s scale=%s z=%s modulate=%s region_enabled=%s region=%s approx_display=%s" % [label, sp.visible, sp.scale, sp.z_index, sp.modulate, sp.region_enabled, sp.region_rect, display_size])
	if label == "Dealer":
		print("[ArtAtlas] DEALER final_scale=", sp.scale)
	elif label == "Boss":
		print("[ArtAtlas] SLIME final_scale=", sp.scale)
	_hide_actor_fallback(label)

func _connect_feedback() -> void:
	var tank_script: Tank = _tank as Tank
	if tank_script != null:
		tank_script.parry_attempted.connect(_on_tank_parry_attempted)
	if _dealer != null:
		_dealer.basic_attack_fired.connect(_on_dealer_basic_anim)
		_dealer.link_skill_fired.connect(_on_dealer_link_anim)
	var slime: KingSlime = _boss as KingSlime
	if slime != null:
		slime.attack_telegraph.connect(_on_slime_telegraph_anim)

func _on_tank_parry_attempted() -> void:
	if _vfx_tex == null:
		return
	var tank_script: Tank = _tank as Tank
	if tank_script == null:
		return
	var result: int = tank_script.get_parry_result()
	_parry_fx.visible = true
	if result == ParryTypes.Result.PERFECT:
		_parry_fx.region_rect = _safe_region_rect(_vfx_tex, Rect2(Vector2(32, 0), Vector2(32, 32)))
		_parry_fx.scale = Vector2(2.1, 2.1)
	else:
		_parry_fx.region_rect = _safe_region_rect(_vfx_tex, Rect2(Vector2(0, 0), Vector2(32, 32)))
		_parry_fx.scale = Vector2(1.6, 1.6)
	await get_tree().create_timer(0.12).timeout
	_parry_fx.visible = false

func _on_dealer_basic_anim(_damage: int) -> void:
	_archer_anim_state = "basic"
	_archer_anim_t = 0.0

func _on_dealer_link_anim(_name: String, _damage: int, _perfect: bool) -> void:
	_archer_anim_state = "link"
	_archer_anim_t = 0.0

func _on_slime_telegraph_anim(_total: float, _perfect: float, name: String) -> void:
	if name.find("박치기") >= 0:
		_slime_anim_state = "dash"
	elif name.find("점프") >= 0:
		_slime_anim_state = "jump"
	elif name.find("점액") >= 0:
		_slime_anim_state = "spit"
	elif name.find("왕관") >= 0:
		_slime_anim_state = "crown"
	_slime_anim_t = 0.0

func _update_animation_states(delta: float) -> void:
	_update_tank_anim(delta)
	_update_archer_anim(delta)
	_update_slime_anim(delta)

func _update_tank_anim(delta: float) -> void:
	if _tank_sprite == null or _tank_sprite.texture == null or _tank_anim_tex == null:
		return
	var tank_obj: Tank = _tank as Tank
	if tank_obj == null:
		return
	if tank_obj.parry_active_timer > 0.0:
		_tank_anim_state = "parry"
	elif tank_obj.velocity.length() > 8.0:
		_tank_anim_state = "walk"
	else:
		_tank_anim_state = "idle"
	_tank_anim_t += delta
	if _tank_anim_t >= 0.09:
		_tank_anim_t = 0.0
		if not simplify_anim_to_first_frame:
			_tank_frame = (_tank_frame + 1) % 4
	else:
		_tank_frame = 0
	var row: int = 0
	if _tank_anim_state == "walk":
		row = 1
	elif _tank_anim_state == "parry":
		row = 2
	_set_sheet_frame(_tank_sprite, _tank_anim_tex, TANK_COLS, TANK_ROWS, _tank_frame, row)

func _update_archer_anim(delta: float) -> void:
	if _dealer_sprite == null or _dealer_sprite.texture == null:
		return
	if _dealer.role != Dealer.Role.ARCHER or _archer_anim_tex == null:
		return
	if _archer_anim_state == "basic" or _archer_anim_state == "link":
		_archer_anim_t += delta
		if _archer_anim_t > 0.35:
			_archer_anim_state = "idle"
	elif _dealer.velocity.length() > 8.0:
		_archer_anim_state = "walk"
	else:
		_archer_anim_state = "idle"
	_archer_anim_t += delta
	if _archer_anim_t >= 0.1:
		_archer_anim_t = 0.0
		if not simplify_anim_to_first_frame:
			_archer_frame = (_archer_frame + 1) % 4
	else:
		_archer_frame = 0
	var row: int = 0
	if _archer_anim_state == "walk":
		row = 1
	elif _archer_anim_state == "basic":
		row = 2
	elif _archer_anim_state == "link":
		row = 3
	_set_sheet_frame(_dealer_sprite, _archer_anim_tex, ARCHER_COLS, ARCHER_ROWS, _archer_frame, row)

func _update_slime_anim(delta: float) -> void:
	if _boss_sprite == null or _boss_sprite.texture == null or _slime_anim_tex == null:
		return
	var slime: KingSlime = _boss as KingSlime
	if slime == null:
		return
	if slime.velocity.length() <= 5.0 and _slime_anim_t > 0.5:
		_slime_anim_state = "idle"
	_slime_anim_t += delta
	if _slime_anim_t >= 0.11:
		_slime_anim_t = 0.0
		if not simplify_anim_to_first_frame:
			_slime_frame = (_slime_frame + 1) % 4
	else:
		_slime_frame = 0
	var row: int = 0
	if _slime_anim_state == "dash":
		row = 1
	elif _slime_anim_state == "jump":
		row = 2
	elif _slime_anim_state == "spit" or _slime_anim_state == "crown":
		row = 3
	_set_sheet_frame(_boss_sprite, _slime_anim_tex, SLIME_COLS, SLIME_ROWS, _slime_frame, row)

func _log_anim_sheet_sizes() -> void:
	if _tank_anim_tex != null:
		print("[ArtAtlas] TANK_ANIM texture_width=", int(_tank_anim_tex.get_size().x), " texture_height=", int(_tank_anim_tex.get_size().y))
	if _archer_anim_tex != null:
		print("[ArtAtlas] ARCHER_ANIM texture_width=", int(_archer_anim_tex.get_size().x), " texture_height=", int(_archer_anim_tex.get_size().y))
	if _slime_anim_tex != null:
		print("[ArtAtlas] SLIME_ANIM texture_width=", int(_slime_anim_tex.get_size().x), " texture_height=", int(_slime_anim_tex.get_size().y))

func _cell_size_for(tex: Texture2D, cols: int, rows: int, override_w: int, override_h: int) -> Vector2:
	var size: Vector2 = tex.get_size()
	var cw: float = size.x / float(max(cols, 1))
	var ch: float = size.y / float(max(rows, 1))
	if override_w > 0:
		cw = float(override_w)
	if override_h > 0:
		ch = float(override_h)
	return Vector2(max(cw, 1.0), max(ch, 1.0))

func _set_sheet_frame(sp: Sprite2D, tex: Texture2D, cols: int, rows: int, col: int, row: int) -> void:
	if cols <= 0 or rows <= 0:
		return
	var cell: Vector2 = _cell_size_for(tex, cols, rows, tank_cell_w if tex == _tank_anim_tex else archer_cell_w if tex == _archer_anim_tex else slime_cell_w if tex == _slime_anim_tex else 0, tank_cell_h if tex == _tank_anim_tex else archer_cell_h if tex == _archer_anim_tex else slime_cell_h if tex == _slime_anim_tex else 0)
	var cw: float = cell.x
	var ch: float = cell.y
	sp.region_enabled = true
	sp.region_rect = _safe_region_rect(tex, Rect2(Vector2(cw * float(col), ch * float(row)), Vector2(cw, ch)))
	print("[ArtAtlas] frame tex=", tex.resource_path, " cell_w=", cw, " cell_h=", ch, " region=", sp.region_rect)

func _update_dealer_role_region() -> void:
	if _dealer_tex == null or _dealer_sprite == null or not _dealer_sprite.region_enabled:
		return
	var y_offset: float = 0.0
	if _dealer.role == Dealer.Role.MAGE:
		y_offset = _dealer_cell.y
	elif _dealer.role == Dealer.Role.ROGUE:
		y_offset = _dealer_cell.y * 2.0
	var rect: Rect2 = Rect2(Vector2(0, y_offset), _dealer_cell)
	_dealer_sprite.region_rect = _safe_region_rect(_dealer_tex, rect)
	print("[ArtAtlas] dealer role=%s region=%s" % [_dealer.role, _dealer_sprite.region_rect])

func _update_boss_region() -> void:
	if _slime_tex == null or _boss_sprite == null or not _boss_sprite.region_enabled:
		return
	var slime: KingSlime = _boss as KingSlime
	if slime == null:
		return
	var frame_col: int = 0
	if slime.velocity.length() > 250.0:
		frame_col = 1
	var frame_row: int = 0
	var body: Node = slime.get_node("BossBody")
	if body is CanvasItem and not (body as CanvasItem).visible:
		frame_row = 1
	var rect: Rect2 = Rect2(Vector2(_slime_cell.x * float(frame_col), _slime_cell.y * float(frame_row)), _slime_cell)
	_boss_sprite.region_rect = _safe_region_rect(_slime_tex, rect)

func _count_non_empty_cells(tex: Texture2D, cols: int, rows: int) -> int:
	var img: Image = tex.get_image()
	if img == null:
		return 0
	var cell_w: int = max(int(img.get_width() / cols), 1)
	var cell_h: int = max(int(img.get_height() / rows), 1)
	var count: int = 0
	for y in range(rows):
		for x in range(cols):
			var rect: Rect2 = Rect2(Vector2(float(x * cell_w), float(y * cell_h)), Vector2(float(cell_w), float(cell_h)))
			if _region_has_visible_pixels(tex, rect):
				count += 1
	return count

func _tight_alpha_rect(tex: Texture2D, rect: Rect2, padding: int) -> Rect2:
	var img: Image = tex.get_image()
	if img == null:
		return rect
	var safe: Rect2 = _safe_region_rect(tex, rect)
	var sx: int = int(safe.position.x)
	var sy: int = int(safe.position.y)
	var ex: int = int(safe.position.x + safe.size.x)
	var ey: int = int(safe.position.y + safe.size.y)
	var min_x: int = ex
	var min_y: int = ey
	var max_x: int = sx
	var max_y: int = sy
	var found: bool = false
	for py in range(sy, ey):
		for px in range(sx, ex):
			if img.get_pixel(px, py).a > 0.06:
				found = true
				min_x = min(min_x, px)
				min_y = min(min_y, py)
				max_x = max(max_x, px)
				max_y = max(max_y, py)
	if not found:
		return safe
	var p: int = max(padding, 0)
	var rx: float = float(max(min_x - p, sx))
	var ry: float = float(max(min_y - p, sy))
	var rw: float = float(min(max_x + p + 1, ex) - int(rx))
	var rh: float = float(min(max_y + p + 1, ey) - int(ry))
	return _safe_region_rect(tex, Rect2(Vector2(rx, ry), Vector2(rw, rh)))

func _blend_rect(a: Rect2, b: Rect2, t: float) -> Rect2:
	var clamped_t: float = clamp(t, 0.0, 1.0)
	var pos: Vector2 = a.position.lerp(b.position, clamped_t)
	var size: Vector2 = a.size.lerp(b.size, clamped_t)
	return Rect2(pos, size)

func _region_has_visible_pixels(tex: Texture2D, rect: Rect2) -> bool:
	var img: Image = tex.get_image()
	if img == null:
		return false
	var safe: Rect2 = _safe_region_rect(tex, rect)
	var start_x: int = int(safe.position.x)
	var start_y: int = int(safe.position.y)
	var end_x: int = int(safe.position.x + safe.size.x)
	var end_y: int = int(safe.position.y + safe.size.y)
	var step_x: int = max(int(safe.size.x / 8.0), 1)
	var step_y: int = max(int(safe.size.y / 8.0), 1)
	for py in range(start_y, end_y, step_y):
		for px in range(start_x, end_x, step_x):
			if img.get_pixel(px, py).a > 0.05:
				return true
	return false

func _safe_region_rect(tex: Texture2D, wanted: Rect2) -> Rect2:
	var tex_size: Vector2 = tex.get_size()
	var px: float = clamp(wanted.position.x, 0.0, max(tex_size.x - 1.0, 0.0))
	var py: float = clamp(wanted.position.y, 0.0, max(tex_size.y - 1.0, 0.0))
	var max_w: float = max(tex_size.x - px, 1.0)
	var max_h: float = max(tex_size.y - py, 1.0)
	var w: float = min(max(wanted.size.x, 1.0), max_w)
	var h: float = min(max(wanted.size.y, 1.0), max_h)
	return Rect2(Vector2(px, py), Vector2(w, h))


func _uniform_scale_for_target(cell: Vector2, target_pixels: float) -> Vector2:
	var base: float = max(cell.y, 1.0)
	var s: float = target_pixels / base
	return Vector2(s, s)
func _add_rim(parent: Node2D, source: Sprite2D, name: String, z: int) -> void:
	if source == null or source.texture == null:
		return
	var rim: Sprite2D
	var existing: Node = parent.get_node_or_null(name)
	if existing != null and existing is Sprite2D:
		rim = existing as Sprite2D
	else:
		rim = Sprite2D.new()
		rim.name = name
		parent.add_child(rim)
	rim.texture = source.texture
	rim.region_enabled = source.region_enabled
	rim.region_rect = source.region_rect
	rim.scale = source.scale * 1.06
	rim.offset = source.offset + Vector2(0, 1)
	rim.modulate = Color(0.1, 0.1, 0.1, 0.45)
	rim.z_index = z
	rim.visible = source.visible

func _add_shadow(parent: Node2D, name: String, radii: Vector2, z: int) -> void:
	var existing: Node = parent.get_node_or_null(name)
	if existing != null and existing is Polygon2D:
		(existing as Polygon2D).visible = true
		return
	var sh: Polygon2D = Polygon2D.new()
	sh.name = name
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var ang: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(ang) * radii.x, sin(ang) * radii.y))
	sh.polygon = pts
	sh.color = Color(0.0, 0.0, 0.0, 0.52)
	sh.position = Vector2(0, 12)
	sh.z_index = z
	parent.add_child(sh)

func _ensure_sprite(parent: Node, node_name: String) -> Sprite2D:
	var existing: Node = parent.get_node_or_null(node_name)
	if existing != null and existing is Sprite2D:
		return existing as Sprite2D
	var sp: Sprite2D = Sprite2D.new()
	sp.name = node_name
	sp.centered = true
	parent.add_child(sp)
	return sp

func _show_fallback(label: String) -> void:
	if label == "Tank":
		_show_polygon_node(_tank, "TankBody")
		_show_polygon_node(_tank, "Head")
		_show_polygon_node(_tank, "Shield")
	elif label == "Dealer":
		_show_polygon_node(_dealer, "DealerSprite")
		_show_polygon_node(_dealer, "WeaponIcon")
	elif label == "Boss":
		_show_polygon_node(_boss, "BossBody")
		_show_polygon_node(_boss, "EyeL")
		_show_polygon_node(_boss, "EyeR")
		_show_polygon_node(_boss, "Crown")

func _hide_actor_fallback(label: String) -> void:
	if label == "Tank":
		_hide_polygon_node(_tank, "TankBody")
		_hide_polygon_node(_tank, "Head")
		_hide_polygon_node(_tank, "Shield")
	elif label == "Dealer":
		_hide_polygon_node(_dealer, "DealerSprite")
		_hide_polygon_node(_dealer, "WeaponIcon")
	elif label == "Boss":
		_hide_polygon_node(_boss, "BossBody")
		_hide_polygon_node(_boss, "EyeL")
		_hide_polygon_node(_boss, "EyeR")
		_hide_polygon_node(_boss, "Crown")

func _hide_polygon_node(parent: Node, node_name: String) -> void:
	var n: Node = parent.get_node_or_null(node_name)
	if n != null and n is CanvasItem:
		(n as CanvasItem).visible = false

func _show_polygon_node(parent: Node, node_name: String) -> void:
	var n: Node = parent.get_node_or_null(node_name)
	if n != null and n is CanvasItem:
		(n as CanvasItem).visible = true

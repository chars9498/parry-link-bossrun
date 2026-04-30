extends Node2D
class_name ArtAtlasDirector

const TANK_ART_PATH: String = "res://assets/art/tank_reference.png"
const DEALER_ART_PATH: String = "res://assets/art/dealer_reference.png"
const SLIME_ART_PATH: String = "res://assets/art/king_slime_reference.png"
const VFX_ART_PATH: String = "res://assets/art/vfx_reference.png"
const PROPS_ART_PATH: String = "res://assets/art/props_reference.png"
const TILESET_ART_PATH: String = "res://assets/art/tileset_reference.png"

const CELL: Vector2 = Vector2(32, 32)

var _tank_tex: Texture2D
var _dealer_tex: Texture2D
var _slime_tex: Texture2D
var _vfx_tex: Texture2D
var _props_tex: Texture2D
var _tiles_tex: Texture2D

@onready var _world: Node2D = get_parent().get_node("World") as Node2D
@onready var _tank: Node2D = _world.get_node("Tank") as Node2D
@onready var _dealer: Dealer = _world.get_node("Dealer") as Dealer
@onready var _boss: Node2D = _world.get_node("KingSlime") as Node2D
@onready var _decor: Node2D = _world.get_node("Decor") as Node2D

var _tank_sprite: Sprite2D
var _dealer_sprite: Sprite2D
var _boss_sprite: Sprite2D
var _parry_fx: Sprite2D

func _ready() -> void:
	_tank_tex = _load_texture(TANK_ART_PATH, "Tank")
	_dealer_tex = _load_texture(DEALER_ART_PATH, "Dealer")
	_slime_tex = _load_texture(SLIME_ART_PATH, "KingSlime")
	_vfx_tex = _load_texture(VFX_ART_PATH, "VFX")
	_props_tex = _load_texture(PROPS_ART_PATH, "Props")
	_tiles_tex = _load_texture(TILESET_ART_PATH, "Tileset")
	_apply_environment_art()
	_apply_character_art()
	_connect_feedback()

func _process(_delta: float) -> void:
	_update_dealer_role_region()
	_update_boss_region()

func _load_texture(path: String, label: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_error("[ArtAtlas] Missing texture file for %s: %s" % [label, path])
		return null
	var res: Resource = load(path)
	if res == null:
		push_error("[ArtAtlas] Failed to load texture for %s: %s" % [label, path])
		return null
	if not (res is Texture2D):
		push_error("[ArtAtlas] Loaded resource is not Texture2D for %s: %s" % [label, path])
		return null
	var tex: Texture2D = res as Texture2D
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		push_error("[ArtAtlas] Invalid texture size for %s: %s" % [label, path])
		return null
	print("[ArtAtlas] Loaded %s texture: %s (%sx%s)" % [label, path, int(tex_size.x), int(tex_size.y)])
	return tex

func _apply_environment_art() -> void:
	if _tiles_tex != null and _world.get_node_or_null("ArenaTileSprite") == null:
		var floor: Sprite2D = Sprite2D.new()
		floor.name = "ArenaTileSprite"
		floor.texture = _tiles_tex
		floor.region_enabled = true
		floor.region_rect = _safe_region_rect(_tiles_tex, Rect2(Vector2.ZERO, Vector2(256, 256)))
		floor.centered = true
		floor.position = Vector2(480, 270)
		floor.scale = Vector2(3.75, 2.1)
		floor.z_index = -20
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
			prop.region_enabled = true
			var wanted: Rect2 = Rect2(Vector2(32 * (i % 3), 32 * int(i / 3)), CELL)
			prop.region_rect = _safe_region_rect(_props_tex, wanted)
			prop.position = points[i]
			prop.scale = Vector2(1.4, 1.4)
			prop.z_index = -2
			_decor.add_child(prop)

func _apply_character_art() -> void:
	_tank_sprite = _ensure_sprite(_tank, "TankArt")
	_dealer_sprite = _ensure_sprite(_dealer, "DealerArt")
	_boss_sprite = _ensure_sprite(_boss, "BossArt")
	_parry_fx = _ensure_sprite(_tank, "ParryFX")
	_parry_fx.visible = false
	_parry_fx.z_index = 5

	if _tank_tex != null:
		_tank_sprite.texture = _tank_tex
		_tank_sprite.region_enabled = true
		_tank_sprite.region_rect = _safe_region_rect(_tank_tex, Rect2(Vector2.ZERO, CELL))
		_tank_sprite.scale = Vector2(1.6, 1.6)
		_hide_polygon_node(_tank, "TankBody")
		_hide_polygon_node(_tank, "Head")
		_hide_polygon_node(_tank, "Shield")
	if _dealer_tex != null:
		_dealer_sprite.texture = _dealer_tex
		_dealer_sprite.region_enabled = true
		_dealer_sprite.scale = Vector2(1.4, 1.4)
		_update_dealer_role_region()
		_hide_polygon_node(_dealer, "DealerSprite")
		_hide_polygon_node(_dealer, "WeaponIcon")
	if _slime_tex != null:
		_boss_sprite.texture = _slime_tex
		_boss_sprite.region_enabled = true
		_boss_sprite.region_rect = _safe_region_rect(_slime_tex, Rect2(Vector2.ZERO, Vector2(64, 64)))
		_boss_sprite.scale = Vector2(1.8, 1.8)
		_hide_polygon_node(_boss, "BossBody")
		_hide_polygon_node(_boss, "EyeL")
		_hide_polygon_node(_boss, "EyeR")
		_hide_polygon_node(_boss, "Crown")
	if _vfx_tex != null:
		_parry_fx.texture = _vfx_tex
		_parry_fx.region_enabled = true
		_parry_fx.region_rect = _safe_region_rect(_vfx_tex, Rect2(Vector2.ZERO, CELL))
		_parry_fx.scale = Vector2(1.6, 1.6)

func _connect_feedback() -> void:
	var tank_script: Tank = _tank as Tank
	if tank_script != null:
		tank_script.parry_attempted.connect(_on_tank_parry_attempted)

func _on_tank_parry_attempted() -> void:
	if _vfx_tex == null:
		return
	var tank_script: Tank = _tank as Tank
	if tank_script == null:
		return
	var result: int = tank_script.get_parry_result()
	_parry_fx.visible = true
	if result == ParryTypes.Result.PERFECT:
		_parry_fx.region_rect = _safe_region_rect(_vfx_tex, Rect2(Vector2(32, 0), CELL))
		_parry_fx.scale = Vector2(2.1, 2.1)
	else:
		_parry_fx.region_rect = _safe_region_rect(_vfx_tex, Rect2(Vector2(0, 0), CELL))
		_parry_fx.scale = Vector2(1.6, 1.6)
	await get_tree().create_timer(0.12).timeout
	_parry_fx.visible = false

func _update_dealer_role_region() -> void:
	if _dealer_tex == null or _dealer_sprite == null:
		return
	var rect: Rect2 = Rect2(Vector2(0, 0), CELL)
	if _dealer.role == Dealer.Role.ARCHER:
		rect.position = Vector2(0, 0)
	elif _dealer.role == Dealer.Role.MAGE:
		rect.position = Vector2(32, 0)
	else:
		rect.position = Vector2(64, 0)
	_dealer_sprite.region_rect = _safe_region_rect(_dealer_tex, rect)

func _update_boss_region() -> void:
	if _slime_tex == null or _boss_sprite == null:
		return
	var slime: KingSlime = _boss as KingSlime
	if slime == null:
		return
	var speed_len: float = slime.velocity.length()
	var body: Node = slime.get_node("BossBody")
	if body is CanvasItem and not (body as CanvasItem).visible:
		_boss_sprite.region_rect = _safe_region_rect(_slime_tex, Rect2(Vector2(128, 0), Vector2(64, 64)))
		return
	if speed_len > 250.0:
		_boss_sprite.region_rect = _safe_region_rect(_slime_tex, Rect2(Vector2(64, 0), Vector2(64, 64)))
		return
	_boss_sprite.region_rect = _safe_region_rect(_slime_tex, Rect2(Vector2(0, 0), Vector2(64, 64)))

func _safe_region_rect(tex: Texture2D, wanted: Rect2) -> Rect2:
	var tex_size: Vector2 = tex.get_size()
	var px: float = clamp(wanted.position.x, 0.0, max(tex_size.x - 1.0, 0.0))
	var py: float = clamp(wanted.position.y, 0.0, max(tex_size.y - 1.0, 0.0))
	var max_w: float = max(tex_size.x - px, 1.0)
	var max_h: float = max(tex_size.y - py, 1.0)
	var w: float = min(wanted.size.x, max_w)
	var h: float = min(wanted.size.y, max_h)
	return Rect2(Vector2(px, py), Vector2(w, h))

func _ensure_sprite(parent: Node, node_name: String) -> Sprite2D:
	var existing: Node = parent.get_node_or_null(node_name)
	if existing != null and existing is Sprite2D:
		return existing as Sprite2D
	var sp: Sprite2D = Sprite2D.new()
	sp.name = node_name
	sp.centered = true
	parent.add_child(sp)
	return sp

func _hide_polygon_node(parent: Node, node_name: String) -> void:
	var n: Node = parent.get_node_or_null(node_name)
	if n != null and n is CanvasItem:
		(n as CanvasItem).visible = false

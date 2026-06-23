extends Node2D
## World view: renders LPC farm sprites (terrain + fruit trees + crops + farm
## buildings). Handles camera pan/zoom and tap-to-place.
## Art: Liberated Pixel Cup (LPC) — see CREDITS files in assets/. CC-BY-SA / CC-BY.

const TILE := 64
const MAP_SEED := 20240621

const ATLAS_FILES := {
	"terrain": "res://assets/lpc_terrain/terrain.png",
	"trees": "res://assets/lpc_trees/lpc-fruit-trees/fruit-trees.png",
	"crops": "res://assets/lpc_crops/crops-v2/crops.png",
	"barn": "res://assets/lpc_farm/lpc-farm/barn.png",
}

# Source rects [x, y, w, h] within their atlas.
const GRASS := [320, 288, 32, 32]
const DIRT := [32, 160, 32, 32]
const APPLE := [0, 2688, 96, 128]
const PEAR := [288, 2688, 96, 128]
const CROP_A := [576, 224, 32, 32]   # red tomato plant
const CROP_B := [576, 288, 32, 32]   # leafy green plant

# Each building = one sprite from an atlas, scaled to display height `h`.
const BLD := {
	"town_hall":   {"atlas": "barn", "r": [498, 790, 126, 188], "h": 120},  # thatched cabin
	"lumber_camp": {"atlas": "barn", "r": [356, 800, 132, 178], "h": 110},  # slate cabin
	"warehouse":   {"atlas": "barn", "r": [184, 748, 66, 174], "h": 122},   # thatched silo
	"quarry":      {"atlas": "barn", "r": [0, 748, 58, 172], "h": 120},     # stone silo
	"water_pump":  {"atlas": "barn", "r": [201, 921, 35, 44], "h": 50},     # water tank
	"orchard":     {"atlas": "trees", "r": [288, 2688, 96, 128], "h": 104}, # pear tree
	"mine":        {"atlas": "barn", "r": [64, 748, 58, 174], "h": 118},    # brown silo
	"apiary":      {"atlas": "barn", "r": [256, 994, 34, 60], "h": 56},     # beehive skep
	"house":       {"atlas": "barn", "r": [192, 1056, 44, 78], "h": 76},    # small shed
}

const DECO := [APPLE, APPLE, PEAR]
const FOG := Color("c2cdd9")
const Villager := preload("res://scripts/Villager.gd")
const NUM_VILLAGERS := 7

@onready var cam: Camera2D = $Camera
@onready var hud := $HUD

const VSCALE := 2.1

var _font: Font
var _atlas := {}
var _cloud: Texture2D
var _cloud2: Texture2D
var _villagers := []
var _emotes := {}
var _dragging := false
var _moved := false
var _press_pos := Vector2.ZERO
var _zoom := 1.0
var _hover := Vector2i(-1, -1)


func _ready() -> void:
	_font = ThemeDB.fallback_font
	for k in ATLAS_FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_FILES[k]))
		_atlas[k] = ImageTexture.create_from_image(img)
	_cloud = _make_cloud(Color("f0f5fa"))
	_cloud2 = _make_cloud(Color("d6e0ea"))

	cam.position = Vector2(GameState.GRID_W * TILE, GameState.GRID_H * TILE) * 0.5
	cam.zoom = Vector2(_zoom, _zoom)
	GameState.buildings_changed.connect(queue_redraw)
	GameState.queue_changed.connect(queue_redraw)

	get_tree().set_auto_accept_quit(false)

	_emotes = _make_emotes()
	for i in range(NUM_VILLAGERS):
		var v = Villager.new()
		v.init_villager(self)
		_villagers.append(v)

	var t := Timer.new()
	t.wait_time = 15.0
	t.autostart = true
	t.timeout.connect(SaveManager.save_game)
	add_child(t)

	var args := OS.get_cmdline_user_args()
	if "shot" in args or "menu" in args:
		await get_tree().create_timer(1.0).timeout
		if "menu" in args:
			hud.open_build_menu(8, 8)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.save_png(ProjectSettings.globalize_path("res://assets/shot.png"))
		get_tree().quit()


func _process(delta: float) -> void:
	var wp := get_global_mouse_position()
	_hover = Vector2i(int(floor(wp.x / TILE)), int(floor(wp.y / TILE)))
	for v in _villagers:
		v.update(delta)
	_match_chats()
	queue_redraw()


## Pair up idle villagers who happen to be standing near each other for a chat.
func _match_chats() -> void:
	for i in range(_villagers.size()):
		var a = _villagers[i]
		if a.state != "idle" or a.busy:
			continue
		for j in range(i + 1, _villagers.size()):
			var b = _villagers[j]
			if b.state != "idle" or b.busy:
				continue
			if a.pos.distance_to(b.pos) < TILE * 1.7:
				var dur := randf_range(3.5, 6.0)
				a.begin_talk(b.pos.x, dur)
				b.begin_talk(a.pos.x, dur)
				break


func _rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


func _blit(atlas: String, src: Array, dest: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(_atlas[atlas], dest, _rect(src), tint)


func _make_cloud(tint: Color) -> Texture2D:
	var s := 80
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s, s) * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x, y).distance_to(c) / (s * 0.5)
			var a := 1.0 - smoothstep(0.45, 1.0, d)
			if a > 0.01:
				var col := tint
				col.a = a
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _visible_range() -> Array:
	var half := get_viewport_rect().size / (2.0 * _zoom)
	var tl := cam.position - half
	var br := cam.position + half
	return [
		maxi(-3, int(floor(tl.x / TILE)) - 1),
		maxi(-3, int(floor(tl.y / TILE)) - 1),
		mini(GameState.GRID_W + 3, int(floor(br.x / TILE)) + 1),
		mini(GameState.GRID_H + 3, int(floor(br.y / TILE)) + 1),
	]


func _draw() -> void:
	var r := _visible_range()
	var gx0: int = r[0]
	var gy0: int = r[1]
	var gx1: int = r[2]
	var gy1: int = r[3]

	# --- Terrain (grass) on owned land ---
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			if GameState.is_owned(gx, gy):
				_blit("terrain", GRASS, Rect2(gx * TILE, gy * TILE, TILE + 1, TILE + 1))

	# --- Clouds over unexplored (non-owned) land ---
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			if not GameState.is_owned(gx, gy):
				_draw_cloud(gx, gy)

	# --- Trees + buildings + villagers, drawn back-to-front by feet Y ---
	var items := []
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			if not GameState.is_owned(gx, gy) or GameState.building_at(gx, gy) != null:
				continue
			var d := _deco_at(gx, gy)
			if d.size() > 0:
				items.append({"y": float((gy + 1) * TILE), "kind": "deco", "gx": gx, "gy": gy, "src": d})
	for b in GameState.buildings:
		items.append({"y": float((int(b["gy"]) + 1) * TILE), "kind": "building", "b": b})
	for v in _villagers:
		items.append({"y": v.pos.y, "kind": "villager", "v": v})
	items.sort_custom(func(p, q): return p["y"] < q["y"])

	var now := Time.get_unix_time_from_system()
	for it in items:
		match it["kind"]:
			"deco":
				_blit_sprite("trees", it["src"], it["gx"], it["gy"], 100.0, Color.WHITE)
			"building":
				_draw_building(it["b"], now)
			"villager":
				_draw_villager(it["v"])

	# --- Hover highlight (on top) ---
	if _hover.x >= gx0 and _hover.y >= gy0 and _hover.x <= gx1 and _hover.y <= gy1:
		var hr := Rect2(_hover.x * TILE, _hover.y * TILE, TILE, TILE)
		var col: Color
		if not GameState.is_owned(_hover.x, _hover.y):
			col = Color(0.5, 0.8, 1.0, 0.28)  # expandable cloud
		elif GameState.building_at(_hover.x, _hover.y) != null:
			col = Color(0.9, 0.95, 1.0, 0.16)
		else:
			col = Color(1, 0.9, 0.4, 0.16)
		draw_rect(hr, col, true)
		draw_rect(hr.grow(-2), Color(1, 1, 1, 0.5), false, 2.0)


func _draw_cloud(gx: int, gy: int) -> void:
	draw_rect(Rect2(gx * TILE - 1, gy * TILE - 1, TILE + 2, TILE + 2), FOG)
	var hsh := _hash(gx, gy)
	var off := Vector2((hsh % 14) - 7, ((hsh / 14) % 14) - 7)
	var size := TILE * 1.55 + float(hsh % 22)
	var tex := _cloud if (hsh % 2 == 0) else _cloud2
	var pos := Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5) + off - Vector2(size, size) * 0.5
	draw_texture_rect(tex, Rect2(pos, Vector2(size, size)), false)


## Scale a sprite to display height `disp_h`, anchored bottom-center on the cell.
func _blit_sprite(atlas: String, src: Array, gx: int, gy: int, disp_h: float, tint: Color) -> void:
	var sc: float = disp_h / float(src[3])
	var dw: float = float(src[2]) * sc
	var x: float = gx * TILE + (TILE - dw) * 0.5
	var y: float = gy * TILE + TILE - disp_h
	_blit(atlas, src, Rect2(x, y, dw, disp_h), tint)


func _depth_sort(a: Dictionary, b: Dictionary) -> bool:
	if a["gy"] == b["gy"]:
		return a["gx"] < b["gx"]
	return a["gy"] < b["gy"]


func _draw_building(b: Dictionary, now: float) -> void:
	var gx: int = b["gx"]
	var gy: int = b["gy"]
	var constructing: bool = b["constructing"]
	var tint := Color(0.5, 0.55, 0.62) if constructing else Color.WHITE
	var origin := Vector2(gx * TILE, gy * TILE)

	if b["type"] == "farm":
		_blit("terrain", DIRT, Rect2(origin.x, origin.y, TILE + 1, TILE + 1), tint)
		var crops := [CROP_B, CROP_A, CROP_A, CROP_B]
		var spots := [Vector2(5, 4), Vector2(33, 6), Vector2(5, 33), Vector2(33, 34)]
		for i in range(4):
			_blit("crops", crops[i], Rect2(origin + spots[i], Vector2(26, 26)), tint)
	else:
		var def: Dictionary = BLD[b["type"]]
		_blit_sprite(def["atlas"], def["r"], gx, gy, float(def["h"]), tint)

	if constructing:
		for px in range(0, 4):
			var lx := origin.x + 8 + px * 16
			draw_line(Vector2(lx, origin.y + 6), Vector2(lx, origin.y + TILE - 6), Color("c9a36a"), 2.0)
		var remain: float = max(0.0, b["build_finish_at"] - now)
		_label(origin + Vector2(TILE * 0.5 - 14, TILE * 0.5), "%ds" % int(ceil(remain)), 18, Color("ffe762"))
	else:
		_badge(origin + Vector2(3, 3), "Lv%d" % b["level"])


func _badge(pos: Vector2, text: String) -> void:
	var sz := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_rect(Rect2(pos, sz + Vector2(8, 4)), Color(0.07, 0.07, 0.11, 0.82), true)
	draw_string(_font, pos + Vector2(4, sz.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _label(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# Deterministic decorations -------------------------------------------------
func _hash(x: int, y: int) -> int:
	var n := (x * 73856093) ^ (y * 19349663) ^ MAP_SEED
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n)


func _deco_at(gx: int, gy: int) -> Array:
	var cx := int(GameState.GRID_W / 2)
	var cy := int(GameState.GRID_H / 2)
	if abs(gx - cx) <= 1 and abs(gy - cy) <= 1:
		return []
	if _hash(gx, gy) % 100 < 9:
		return DECO[_hash(gx + 3, gy + 11) % DECO.size()]
	return []


# Input --------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(_zoom * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(_zoom / 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_moved = false
				_press_pos = event.position
			else:
				_dragging = false
				if not _moved:
					_handle_tap(get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		if event.position.distance_to(_press_pos) > 8.0:
			_moved = true
		cam.position -= event.relative / _zoom


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, 0.5, 2.5)
	cam.zoom = Vector2(_zoom, _zoom)


func _handle_tap(world_pos: Vector2) -> void:
	var gx := int(floor(world_pos.x / TILE))
	var gy := int(floor(world_pos.y / TILE))
	if gx < 0 or gy < 0 or gx >= GameState.GRID_W or gy >= GameState.GRID_H:
		return
	if not GameState.is_owned(gx, gy):
		hud.open_expand_dialog()
		return
	var b = GameState.building_at(gx, gy)
	if b == null:
		hud.open_build_menu(gx, gy)
	else:
		hud.open_building_panel(b)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		SaveManager.save_game()

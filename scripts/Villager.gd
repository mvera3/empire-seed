extends RefCounted
## A small pixel villager with a daily routine: wander, idle, whistle, sit,
## nap, rest under trees, and chat when two meet. Drawn by Main (for depth
## sorting) — this object holds state + procedurally generated pose frames.

const TILE := 64

const OUT := Color("241a12")
const SKINS := [Color("f1c27d"), Color("e0ac69"), Color("c68642"), Color("ffdbac")]
const HAIRS := [Color("3a2a1a"), Color("6b4423"), Color("d9a066"), Color("222034"), Color("8a5a2b")]
const SHIRTS := [Color("b13e53"), Color("3b7dd9"), Color("5a8f3a"), Color("d9a066"), Color("8a5fb0"), Color("d96f3a")]
const PANTS := [Color("3a3f5a"), Color("5a3a22"), Color("2c3e50"), Color("4a4a4a")]

var main                       # Main node (for tree/occupancy queries)
var pos := Vector2.ZERO        # feet position (world)
var tex: Texture2D
var emote := ""                # "", "music", "talk", "zzz"
var state := "wander"
var busy := false              # talking (don't auto-retarget)

var _speed := 26.0
var _t := 0.0                  # state timer
var _target := Vector2.ZERO
var _anim := 0.0
var _facing := 1               # 1 right, -1 left
var _emote_t := 0.0
var _rest := ""                # pending rest behavior on arrival
var _fr := {}                  # facing -> {idle, walk:[a,b], sit, lie}

var _skin: Color
var _hair: Color
var _shirt: Color
var _pant: Color


func init_villager(m) -> void:
	main = m
	_skin = SKINS.pick_random()
	_hair = HAIRS.pick_random()
	_shirt = SHIRTS.pick_random()
	_pant = PANTS.pick_random()
	_speed = randf_range(18.0, 32.0)
	_gen_frames()
	var t := GameState.random_owned_point()
	pos = _tile_center(t)
	tex = _fr["r"]["idle"]
	_enter_wander()


func _fkey() -> String:
	return "r" if _facing >= 0 else "l"


func _tile_center(t: Vector2i) -> Vector2:
	return Vector2((t.x + 0.5) * TILE, (t.y + 0.72) * TILE)


# --- Behaviour ------------------------------------------------------------
func update(delta: float) -> void:
	_t -= delta
	match state:
		"wander":
			_do_wander(delta)
		"talk":
			tex = _fr[_fkey()]["idle"]
			_emote_t -= delta
			if _emote_t <= 0.0:
				emote = "talk" if emote == "" else ""
				_emote_t = 0.7
			if _t <= 0.0:
				busy = false
				_enter_wander()
		_:  # idle / whistle / sit / lie : hold a pose until timer ends
			if _t <= 0.0:
				_enter_wander()


func _enter_wander() -> void:
	state = "wander"
	emote = ""
	_rest = ""
	# sometimes head to a tree to rest in its shade
	if randf() < 0.28:
		var tt: Vector2i = main.random_tree_tile()
		if tt.x >= 0:
			_target = _tile_center(Vector2i(tt.x, tt.y + 1))
			_rest = "sit"
			return
	_target = _pick_target()


func _pick_target() -> Vector2:
	for i in range(14):
		var t := GameState.random_owned_point()
		if GameState.building_at(t.x, t.y) == null:
			return _tile_center(t)
	return pos


func _do_wander(delta: float) -> void:
	var to := _target - pos
	if to.length() < 5.0:
		_arrive()
		return
	var dir := to.normalized()
	var npos := pos + dir * _speed * delta
	var ng := Vector2i(int(floor(npos.x / TILE)), int(floor(npos.y / TILE)))
	if not GameState.is_owned(ng.x, ng.y) or GameState.building_at(ng.x, ng.y) != null:
		_enter_wander()  # blocked by a building / clouds — pick a new path
		return
	pos = npos
	_facing = -1 if dir.x < 0.0 else 1
	_anim += delta * 7.0
	tex = _fr[_fkey()]["walk"][int(_anim) % 2]


func _arrive() -> void:
	if _rest == "sit":
		_start("sit", randf_range(3.0, 6.0), "")
		return
	var r := randf()
	if r < 0.30:
		_start("idle", randf_range(2.0, 4.0), "")
	elif r < 0.52:
		_start("whistle", randf_range(2.5, 4.5), "music")
	elif r < 0.70:
		_start("sit", randf_range(3.0, 6.0), "")
	elif r < 0.82:
		_start("lie", randf_range(4.0, 8.0), "zzz")
	else:
		_enter_wander()


func _start(s: String, dur: float, em: String) -> void:
	state = s
	_t = dur
	emote = em
	var f: Dictionary = _fr[_fkey()]
	if s == "sit":
		tex = f["sit"]
	elif s == "lie":
		tex = f["lie"]
	else:
		tex = f["idle"]


## Called by Main to start a chat with a partner.
func begin_talk(partner_x: float, dur: float) -> void:
	state = "talk"
	busy = true
	_t = dur
	emote = "talk"
	_emote_t = 0.7
	_facing = 1 if partner_x >= pos.x else -1
	tex = _fr[_fkey()]["idle"]


# --- Sprite generation ----------------------------------------------------
func _gen_frames() -> void:
	var idle := _compose("idle")
	var w1 := _compose("walk1")
	var w2 := _compose("walk2")
	var sit := _compose("sit")
	var lie := _compose("lie")
	_fr["r"] = {"idle": _tex(idle), "walk": [_tex(w1), _tex(w2)], "sit": _tex(sit), "lie": _tex(lie)}
	_fr["l"] = {"idle": _tex(_flip(idle)), "walk": [_tex(_flip(w1)), _tex(_flip(w2))],
		"sit": _tex(_flip(sit)), "lie": _tex(_flip(lie))}


func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _flip(img: Image) -> Image:
	var d := img.duplicate()
	d.flip_x()
	return d


func _compose(pose: String) -> Image:
	var img := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if pose == "lie":
		# horizontal sleeping figure near the ground
		_rect(img, 2, 16, 3, 1, _hair)
		_rect(img, 2, 17, 3, 3, _skin)
		_rect(img, 5, 17, 7, 3, _shirt)
		_rect(img, 12, 18, 3, 2, _pant)
		_outline(img, OUT)
		return img

	# upright figures (idle / walk / sit)
	var top := 0
	if pose == "sit":
		top = 3
	_rect(img, 4, 3 + top, 8, 2, _hair)
	_rect(img, 5, 2 + top, 6, 2, _hair)
	_rect(img, 5, 5 + top, 6, 4, _skin)
	img.set_pixel(6, 7 + top, OUT)
	img.set_pixel(9, 7 + top, OUT)
	_rect(img, 4, 9 + top, 8, 7, _shirt)
	_rect(img, 3, 9 + top, 1, 5, _shirt)
	_rect(img, 12, 9 + top, 1, 5, _shirt)
	img.set_pixel(3, 14 + top, _skin)
	img.set_pixel(12, 14 + top, _skin)

	if pose == "sit":
		# folded legs out in front
		_rect(img, 4, 19, 8, 2, _pant)
		_rect(img, 4, 21, 2, 1, OUT)
		_rect(img, 10, 21, 2, 1, OUT)
	else:
		var lyl := 16
		var lyr := 16
		var lhl := 6
		var lhr := 6
		if pose == "walk1":
			lyr = 17
			lhr = 5
		elif pose == "walk2":
			lyl = 17
			lhl = 5
		_rect(img, 5, lyl, 2, lhl, _pant)
		_rect(img, 9, lyr, 2, lhr, _pant)
		_rect(img, 5, lyl + lhl - 1, 2, 1, OUT)
		_rect(img, 9, lyr + lhr - 1, 2, 1, OUT)

	_outline(img, OUT)
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for i in range(w):
		for j in range(h):
			if x + i >= 0 and x + i < 16 and y + j >= 0 and y + j < 24:
				img.set_pixel(x + i, y + j, c)


func _outline(img: Image, c: Color) -> void:
	var src := img.duplicate()
	for y in range(24):
		for x in range(16):
			if src.get_pixel(x, y).a > 0.5:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < 16 and ny >= 0 and ny < 24 and src.get_pixel(nx, ny).a > 0.5:
					near = true
					break
			if near:
				img.set_pixel(x, y, c)

extends Node
## Local save/load to user:// (the source of truth) + offline accrual on load.
## Autoload; loaded after GameState.

const PATH := "user://empire_seed_save.json"


func _ready() -> void:
	load_game()


func save_game() -> void:
	GameState.last_played_at = Time.get_unix_time_from_system()
	var data := {
		"version": 3,
		"resources": GameState.resources,
		"gold": GameState.gold,
		"buildings": GameState.buildings,
		"queue_indices": _queue_indices(),
		"owned_radius": GameState.owned_radius,
		"last_played_at": GameState.last_played_at,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func _queue_indices() -> Array:
	var idx := []
	for q in GameState.queue:
		idx.append(GameState.buildings.find(q))
	return idx


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		GameState.new_game()
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		GameState.new_game()
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		GameState.new_game()
		return
	if int(data.get("version", 1)) < 3:
		# world layout changed (bigger map + territory) — start fresh
		GameState.new_game()
		return

	GameState.resources = data.get("resources", {})
	for r in GameState.RESOURCES:
		if not GameState.resources.has(r):
			GameState.resources[r] = 0.0
		else:
			GameState.resources[r] = float(GameState.resources[r])
	GameState.gold = float(data.get("gold", 0))

	GameState.buildings = data.get("buildings", [])
	for b in GameState.buildings:
		b["gx"] = int(b["gx"])
		b["gy"] = int(b["gy"])
		b["level"] = int(b["level"])
		b["target_level"] = int(b.get("target_level", b["level"]))
		b["constructing"] = bool(b["constructing"])
		b["build_finish_at"] = float(b.get("build_finish_at", 0.0))

	GameState.queue = []
	for i in data.get("queue_indices", []):
		var ii := int(i)
		if ii >= 0 and ii < GameState.buildings.size():
			GameState.queue.append(GameState.buildings[ii])

	GameState.owned_radius = int(data.get("owned_radius", GameState.START_RADIUS))
	GameState._recompute_caps()

	var last := float(data.get("last_played_at", Time.get_unix_time_from_system()))
	var elapsed := Time.get_unix_time_from_system() - last
	var report := GameState.apply_offline(elapsed)
	GameState.last_played_at = Time.get_unix_time_from_system()

	GameState.resources_changed.emit()
	GameState.buildings_changed.emit()
	GameState.queue_changed.emit()

	GameState.set_meta("offline_report", report)
	GameState.set_meta("offline_seconds", clampf(elapsed, 0.0, GameState.MAX_OFFLINE_SECONDS))


# Manual export/import helpers (spec section 11 fallback) -------------------
func export_string() -> String:
	save_game()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return Marshalls.utf8_to_base64(s)


func import_string(code: String) -> bool:
	var s := Marshalls.base64_to_utf8(code)
	if s == "":
		return false
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(s)
	f.close()
	load_game()
	return true

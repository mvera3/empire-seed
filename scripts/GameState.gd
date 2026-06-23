extends Node
## Empire Seed — central game state & economy logic (autoload singleton).
## Phase 1: Tier-1 resources, buildings, build queue, production, offline accrual.

signal resources_changed
signal buildings_changed
signal queue_changed
signal message(text)

# --- Master palette (subset of the locked 16-bit palette) ---
const RESOURCES := ["wood", "stone", "food", "water"]

const RES_INFO := {
	"wood":  {"name": "Wood",  "color": Color("8f563b")},
	"stone": {"name": "Stone", "color": Color("9badb7")},
	"food":  {"name": "Food",  "color": Color("6abe30")},
	"water": {"name": "Water", "color": Color("5fcde4")},
}

# Building definitions. base_rate is per second at level 1; production = base_rate * level.
const DEFS := {
	"town_hall": {
		"name": "Town Hall", "produces": "", "base_rate": 0.0,
		"color": Color("d9a066"), "build_time": 6.0,
		"base_cost": {"wood": 200, "stone": 150}, "buildable": false,
	},
	"lumber_camp": {
		"name": "Lumber Camp", "produces": "wood", "base_rate": 0.6,
		"color": Color("8f563b"), "build_time": 5.0,
		"base_cost": {"wood": 50}, "buildable": true,
	},
	"quarry": {
		"name": "Quarry", "produces": "stone", "base_rate": 0.5,
		"color": Color("9badb7"), "build_time": 6.0,
		"base_cost": {"wood": 50, "stone": 20}, "buildable": true,
	},
	"farm": {
		"name": "Farm", "produces": "food", "base_rate": 0.7,
		"color": Color("6abe30"), "build_time": 5.0,
		"base_cost": {"wood": 40, "food": 10}, "buildable": true,
	},
	"water_pump": {
		"name": "Water Pump", "produces": "water", "base_rate": 0.7,
		"color": Color("5fcde4"), "build_time": 5.0,
		"base_cost": {"wood": 40, "stone": 20}, "buildable": true,
	},
	"warehouse": {
		"name": "Warehouse", "produces": "", "base_rate": 0.0,
		"color": Color("847e87"), "build_time": 7.0,
		"base_cost": {"wood": 80, "stone": 60}, "buildable": true,
	},
	"orchard": {
		"name": "Orchard", "produces": "food", "base_rate": 1.0,
		"color": Color("6abe30"), "build_time": 8.0,
		"base_cost": {"wood": 120, "water": 40}, "buildable": true,
	},
	"apiary": {
		"name": "Apiary", "produces": "food", "base_rate": 0.5,
		"color": Color("ffcd75"), "build_time": 6.0,
		"base_cost": {"wood": 60, "food": 20}, "buildable": true,
	},
	"mine": {
		"name": "Mine", "produces": "stone", "base_rate": 0.9,
		"color": Color("9badb7"), "build_time": 9.0,
		"base_cost": {"wood": 100, "stone": 40}, "buildable": true,
	},
	"house": {
		"name": "House", "produces": "gold", "base_rate": 0.05,
		"color": Color("f2b13c"), "build_time": 10.0,
		"base_cost": {"wood": 150, "stone": 100}, "buildable": true,
	},
}

const BASE_CAP := 200.0
const WAREHOUSE_CAP_PER_LEVEL := 150.0
const COST_MULT := 1.6
const TIME_MULT := 1.35
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const GRID_W := 40
const GRID_H := 40
const START_RADIUS := 8      # owned area = Chebyshev radius around center (~16x16 base)
const MAX_RADIUS := 19
const EXPAND_GROWTH := 1.7   # cost multiplier per expansion

var resources := {}
var storage_caps := {}
var gold := 0.0
var buildings := []   # Array[Dictionary]
var queue := []       # Array[Dictionary] — references into `buildings`, FIFO construction
var owned_radius := START_RADIUS
var last_played_at := 0.0


func center() -> Vector2i:
	return Vector2i(int(GRID_W / 2), int(GRID_H / 2))


func is_owned(gx: int, gy: int) -> bool:
	var c := center()
	return max(abs(gx - c.x), abs(gy - c.y)) <= owned_radius


func expansions_done() -> int:
	return owned_radius - START_RADIUS


func random_owned_point() -> Vector2i:
	var c := center()
	return Vector2i(
		randi_range(c.x - owned_radius, c.x + owned_radius),
		randi_range(c.y - owned_radius, c.y + owned_radius))


func can_expand() -> bool:
	return owned_radius < MAX_RADIUS


func expand_cost() -> Dictionary:
	var n := expansions_done()
	var m: float = pow(EXPAND_GROWTH, n)
	return {
		"wood": int(ceil(180 * m)),
		"stone": int(ceil(140 * m)),
		"gold": int(ceil(8 * (n + 1))),
	}


func expand_land() -> bool:
	if not can_expand():
		message.emit("Your territory is already at its limit")
		return false
	var cost := expand_cost()
	if not can_afford(cost):
		message.emit("Not enough to clear the clouds — keep grinding!")
		return false
	spend(cost)
	owned_radius += 1
	resources_changed.emit()
	buildings_changed.emit()
	message.emit("Territory expanded! New land revealed.")
	return true


func _ready() -> void:
	set_process(true)


# ---------------------------------------------------------------------------
# New game / setup
# ---------------------------------------------------------------------------
func new_game() -> void:
	resources = {"wood": 200.0, "stone": 120.0, "food": 120.0, "water": 120.0}
	gold = 0.0
	buildings = []
	queue = []
	owned_radius = START_RADIUS
	var th := _make_building("town_hall", int(GRID_W / 2), int(GRID_H / 2))
	th["level"] = 1
	th["constructing"] = false
	buildings.append(th)
	_recompute_caps()
	last_played_at = Time.get_unix_time_from_system()
	resources_changed.emit()
	buildings_changed.emit()
	queue_changed.emit()


func _make_building(type: String, gx: int, gy: int) -> Dictionary:
	return {
		"type": type, "level": 0, "gx": gx, "gy": gy,
		"constructing": true, "build_finish_at": 0.0, "target_level": 1,
	}


# ---------------------------------------------------------------------------
# Grid helpers
# ---------------------------------------------------------------------------
func building_at(gx: int, gy: int):
	for b in buildings:
		if b["gx"] == gx and b["gy"] == gy:
			return b
	return null


func is_occupied(gx: int, gy: int) -> bool:
	return building_at(gx, gy) != null


# ---------------------------------------------------------------------------
# Costs / production scaling
# ---------------------------------------------------------------------------
func cost_for(type: String, level: int) -> Dictionary:
	# Cost to build (level 0) or upgrade from `level` to `level + 1`.
	var base = DEFS[type]["base_cost"]
	var out := {}
	for k in base:
		out[k] = ceil(base[k] * pow(COST_MULT, level))
	return out


func build_time_for(type: String, target_level: int) -> float:
	return DEFS[type]["build_time"] * pow(TIME_MULT, target_level - 1)


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if k == "gold":
			if gold < cost[k]:
				return false
		elif resources.get(k, 0.0) < cost[k]:
			return false
	return true


func spend(cost: Dictionary) -> void:
	for k in cost:
		if k == "gold":
			gold -= cost[k]
		else:
			resources[k] -= cost[k]


# ---------------------------------------------------------------------------
# Build queue
# ---------------------------------------------------------------------------
func queue_build(type: String, gx: int, gy: int) -> bool:
	if not DEFS.has(type):
		return false
	if not is_owned(gx, gy):
		message.emit("That land is still under the clouds")
		return false
	if is_occupied(gx, gy):
		message.emit("That tile is occupied")
		return false
	var cost := cost_for(type, 0)
	if not can_afford(cost):
		message.emit("Not enough resources")
		return false
	spend(cost)
	var b := _make_building(type, gx, gy)
	buildings.append(b)
	_enqueue(b)
	resources_changed.emit()
	buildings_changed.emit()
	queue_changed.emit()
	return true


func queue_upgrade(b: Dictionary) -> bool:
	if b["constructing"]:
		message.emit("Already under construction")
		return false
	var cost := cost_for(b["type"], b["level"])
	if not can_afford(cost):
		message.emit("Not enough resources")
		return false
	spend(cost)
	b["constructing"] = true
	b["target_level"] = b["level"] + 1
	_enqueue(b)
	resources_changed.emit()
	buildings_changed.emit()
	queue_changed.emit()
	return true


func _enqueue(b: Dictionary) -> void:
	queue.append(b)
	if queue.size() == 1:
		_start_construction(b)


func _start_construction(b: Dictionary) -> void:
	var t := build_time_for(b["type"], b["target_level"])
	b["build_finish_at"] = Time.get_unix_time_from_system() + t


# ---------------------------------------------------------------------------
# Per-frame tick
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	_advance_construction()
	_produce(delta)


func _advance_construction() -> void:
	var now := Time.get_unix_time_from_system()
	var changed := false
	while queue.size() > 0:
		var head = queue[0]
		if head["build_finish_at"] <= now:
			_complete(head)
			queue.pop_front()
			changed = true
			if queue.size() > 0:
				_start_construction(queue[0])
		else:
			break
	if changed:
		_recompute_caps()
		resources_changed.emit()
		buildings_changed.emit()
		queue_changed.emit()


func _complete(b: Dictionary) -> void:
	b["level"] = b["target_level"]
	b["constructing"] = false


func _produce(delta: float) -> void:
	var changed := false
	for b in buildings:
		if b["constructing"]:
			continue
		var def = DEFS[b["type"]]
		var res = def["produces"]
		if res == "":
			continue
		var rate: float = def["base_rate"] * b["level"]
		if res == "gold":
			gold += rate * delta
			changed = true
		elif resources[res] < storage_caps[res]:
			resources[res] = min(storage_caps[res], resources[res] + rate * delta)
			changed = true
	if changed:
		resources_changed.emit()


# ---------------------------------------------------------------------------
# Storage caps (Warehouses raise all caps)
# ---------------------------------------------------------------------------
func _recompute_caps() -> void:
	var caps := {}
	for r in RESOURCES:
		caps[r] = BASE_CAP
	for b in buildings:
		if b["type"] == "warehouse" and not b["constructing"]:
			for r in RESOURCES:
				caps[r] += WAREHOUSE_CAP_PER_LEVEL * b["level"]
	storage_caps = caps
	for r in RESOURCES:
		if resources.has(r):
			resources[r] = min(resources[r], caps[r])


# ---------------------------------------------------------------------------
# Offline accrual — called after load. Returns a report dict {res: gained}.
# ---------------------------------------------------------------------------
func apply_offline(elapsed: float) -> Dictionary:
	elapsed = clamp(elapsed, 0.0, MAX_OFFLINE_SECONDS)
	var report := {}
	if elapsed <= 0.0:
		return report
	for b in buildings:
		if b["constructing"]:
			continue
		var def = DEFS[b["type"]]
		var res = def["produces"]
		if res == "":
			continue
		var gain: float = def["base_rate"] * b["level"] * elapsed
		if res == "gold":
			gold += gain
			report["gold"] = report.get("gold", 0.0) + gain
			continue
		var before: float = resources[res]
		resources[res] = min(storage_caps[res], resources[res] + gain)
		report[res] = report.get(res, 0.0) + (resources[res] - before)
	resources_changed.emit()
	return report

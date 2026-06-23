extends CanvasLayer
## Farm-themed UI: wooden/parchment resource bar, build menu, building panel,
## toasts and offline welcome. Styled to match the LPC farm art.

# --- Theme palette (warm wood / parchment) ---
const WOOD_DK := Color("4a2e1a")
const WOOD := Color("7a4f2e")
const WOOD_L := Color("a06a3a")
const PARCH := Color("efdcae")
const PARCH_DK := Color("d8bd86")
const BARK := Color("2c1c10")
const INK := Color("3a2616")
const CREAM := Color("fff3d6")
const GOLD := Color("f2b13c")

var _res_labels := {}
var _gold_label: Label
var _queue_label: Label
var _toast: Label

var _menu: Panel
var _menu_gx := 0
var _menu_gy := 0

var _panel: Panel
var _panel_vb: VBoxContainer
var _panel_building

var _expand: Panel
var _expand_vb: VBoxContainer


func _ready() -> void:
	_build_topbar()
	_build_queue_label()
	_build_menu()
	_build_panel()
	_build_expand()
	_build_toast()

	GameState.resources_changed.connect(_update_resources)
	GameState.buildings_changed.connect(_update_resources)
	GameState.queue_changed.connect(_update_queue)
	GameState.message.connect(_show_toast)

	_update_resources()
	_update_queue()
	call_deferred("_show_offline_welcome")


# --- Style helpers --------------------------------------------------------
func _sb(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _sb(WOOD, WOOD_DK, 3, 8))
	b.add_theme_stylebox_override("hover", _sb(WOOD_L, WOOD_DK, 3, 8))
	b.add_theme_stylebox_override("pressed", _sb(WOOD_DK, BARK, 3, 8))
	b.add_theme_stylebox_override("focus", _sb(WOOD, GOLD, 3, 8))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.5, 0.45, 0.4, 0.6), WOOD_DK, 3, 8))
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", PARCH_DK)
	b.add_theme_font_size_override("font_size", 16)


func _styled_panel(size: Vector2) -> Panel:
	var p := Panel.new()
	p.anchor_left = 0.5
	p.anchor_top = 0.5
	p.anchor_right = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -size.x / 2.0
	p.offset_top = -size.y / 2.0
	p.offset_right = size.x / 2.0
	p.offset_bottom = size.y / 2.0
	p.add_theme_stylebox_override("panel", _sb(PARCH, WOOD_DK, 5, 12))
	add_child(p)
	return p


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- Top resource bar -----------------------------------------------------
func _build_topbar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 52
	var sb := _sb(Color("3a2414"), GOLD, 0, 0)
	sb.border_width_bottom = 3
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hbox)
	for r in GameState.RESOURCES:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_outline_color", BARK)
		lbl.add_theme_constant_override("outline_size", 4)
		hbox.add_child(lbl)
		_res_labels[r] = lbl
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", GOLD)
	_gold_label.add_theme_color_override("font_outline_color", BARK)
	_gold_label.add_theme_constant_override("outline_size", 4)
	hbox.add_child(_gold_label)


func _update_resources() -> void:
	for r in GameState.RESOURCES:
		var amt: float = GameState.resources.get(r, 0.0)
		var cap: float = GameState.storage_caps.get(r, 0.0)
		var info = GameState.RES_INFO[r]
		var lbl: Label = _res_labels[r]
		lbl.text = "%s %d/%d" % [info["name"], int(amt), int(cap)]
		lbl.add_theme_color_override("font_color", info["color"])
	_gold_label.text = "Gold %d" % int(GameState.gold)


# --- Build queue line -----------------------------------------------------
func _build_queue_label() -> void:
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pc.offset_left = 10
	pc.offset_top = 60
	pc.add_theme_stylebox_override("panel", _sb(Color(0.23, 0.15, 0.08, 0.85), WOOD_DK, 2, 8))
	add_child(pc)
	_queue_label = Label.new()
	_queue_label.add_theme_font_size_override("font_size", 15)
	_queue_label.add_theme_color_override("font_color", PARCH)
	pc.add_child(_queue_label)


func _update_queue() -> void:
	if GameState.queue.is_empty():
		_queue_label.text = "Build queue: empty  ·  tap an empty tile to build"
	else:
		var names := []
		for q in GameState.queue:
			names.append(GameState.DEFS[q["type"]]["name"])
		_queue_label.text = "Building: " + "  ->  ".join(names)


# --- Build menu (2-column grid) -------------------------------------------
func _build_menu() -> void:
	_menu = _styled_panel(Vector2(480, 600))
	_menu.visible = false
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 16
	vb.offset_right = -18
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 10)
	_menu.add_child(vb)
	vb.add_child(_title("Build"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)
	for bt in GameState.DEFS:
		var def = GameState.DEFS[bt]
		if not def["buildable"]:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(205, 62)
		btn.text = "%s\n%s" % [def["name"], _cost_text(GameState.cost_for(bt, 0))]
		_style_button(btn)
		btn.pressed.connect(_on_build_pressed.bind(bt))
		grid.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 44)
	_style_button(cancel)
	cancel.pressed.connect(func(): _menu.visible = false)
	vb.add_child(cancel)


func open_build_menu(gx: int, gy: int) -> void:
	_menu_gx = gx
	_menu_gy = gy
	_panel.visible = false
	_menu.visible = true


func _on_build_pressed(type: String) -> void:
	if GameState.queue_build(type, _menu_gx, _menu_gy):
		_menu.visible = false


# --- Building info / upgrade panel ----------------------------------------
func _build_panel() -> void:
	_panel = _styled_panel(Vector2(440, 400))
	_panel.visible = false
	_panel_vb = VBoxContainer.new()
	_panel_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_vb.offset_left = 18
	_panel_vb.offset_top = 16
	_panel_vb.offset_right = -18
	_panel_vb.offset_bottom = -16
	_panel_vb.add_theme_constant_override("separation", 10)
	_panel.add_child(_panel_vb)


func open_building_panel(b: Dictionary) -> void:
	_panel_building = b
	_menu.visible = false
	for c in _panel_vb.get_children():
		c.queue_free()

	var def = GameState.DEFS[b["type"]]
	_panel_vb.add_child(_title(def["name"]))

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", INK)
	var lines := ["Level: %d" % b["level"]]
	if def["produces"] != "":
		lines.append("Produces: %.2f %s/s  ->  %.2f /s next level"
			% [def["base_rate"] * b["level"], def["produces"], def["base_rate"] * (b["level"] + 1)])
	if b["type"] == "warehouse":
		lines.append("Storage (all): +%d  ->  +%d next level"
			% [int(GameState.WAREHOUSE_CAP_PER_LEVEL * b["level"]),
			   int(GameState.WAREHOUSE_CAP_PER_LEVEL * (b["level"] + 1))])
	info.text = "\n".join(lines)
	_panel_vb.add_child(info)

	if b["constructing"]:
		var c := Label.new()
		c.text = "Under construction..."
		c.add_theme_color_override("font_color", Color("9a5b1e"))
		c.add_theme_font_size_override("font_size", 18)
		_panel_vb.add_child(c)
	else:
		var cost := GameState.cost_for(b["type"], b["level"])
		var up := Button.new()
		up.custom_minimum_size = Vector2(0, 56)
		up.text = "Upgrade to Lv%d\n%s" % [b["level"] + 1, _cost_text(cost)]
		_style_button(up)
		up.pressed.connect(_on_upgrade_pressed)
		_panel_vb.add_child(up)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	_style_button(close)
	close.pressed.connect(func(): _panel.visible = false)
	_panel_vb.add_child(close)
	_panel.visible = true


func _on_upgrade_pressed() -> void:
	if GameState.queue_upgrade(_panel_building):
		open_building_panel(_panel_building)


# --- Expand territory dialog ----------------------------------------------
func _build_expand() -> void:
	_expand = _styled_panel(Vector2(440, 360))
	_expand.visible = false
	_expand_vb = VBoxContainer.new()
	_expand_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_expand_vb.offset_left = 18
	_expand_vb.offset_top = 16
	_expand_vb.offset_right = -18
	_expand_vb.offset_bottom = -16
	_expand_vb.add_theme_constant_override("separation", 12)
	_expand.add_child(_expand_vb)


func open_expand_dialog() -> void:
	_menu.visible = false
	_panel.visible = false
	for c in _expand_vb.get_children():
		c.queue_free()
	_expand_vb.add_child(_title("Expand Territory"))

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", INK)
	info.text = "Beyond the clouds lies unclaimed land. Clear it to build more — but each expansion costs more than the last. Grind your resources to push the frontier outward."
	_expand_vb.add_child(info)

	if GameState.can_expand():
		var cost := GameState.expand_cost()
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.text = "Clear the Clouds\n%s" % _cost_text(cost)
		_style_button(btn)
		btn.pressed.connect(func():
			if GameState.expand_land():
				_expand.visible = false)
		_expand_vb.add_child(btn)
	else:
		var maxed := Label.new()
		maxed.text = "Your territory has reached its limit."
		maxed.add_theme_color_override("font_color", Color("9a5b1e"))
		maxed.add_theme_font_size_override("font_size", 18)
		_expand_vb.add_child(maxed)

	var close := Button.new()
	close.text = "Cancel"
	close.custom_minimum_size = Vector2(0, 44)
	_style_button(close)
	close.pressed.connect(func(): _expand.visible = false)
	_expand_vb.add_child(close)
	_expand.visible = true


# --- Toast & offline welcome ----------------------------------------------
func _build_toast() -> void:
	var pc := PanelContainer.new()
	pc.name = "ToastBox"
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	pc.offset_top = -130
	pc.offset_bottom = -86
	pc.offset_left = -260
	pc.offset_right = 260
	pc.add_theme_stylebox_override("panel", _sb(Color("3a2414"), GOLD, 3, 10))
	pc.visible = false
	add_child(pc)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", CREAM)
	pc.add_child(_toast)


func _show_toast(text: String) -> void:
	var box := get_node("ToastBox")
	_toast.text = text
	box.visible = true
	var t := get_tree().create_timer(2.4)
	t.timeout.connect(func():
		if _toast.text == text:
			box.visible = false)


func _show_offline_welcome() -> void:
	if not GameState.has_meta("offline_report"):
		return
	var report: Dictionary = GameState.get_meta("offline_report")
	var secs: float = GameState.get_meta("offline_seconds")
	if secs < 5.0:
		return
	var parts := []
	for k in report:
		if report[k] >= 1.0:
			parts.append("+%d %s" % [int(report[k]), k])
	if parts.is_empty():
		return
	_show_toast("Welcome back! Gathered while away: " + ", ".join(parts))


# --- Helpers --------------------------------------------------------------
func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), k])
	if parts.is_empty():
		return "free"
	return ", ".join(parts)

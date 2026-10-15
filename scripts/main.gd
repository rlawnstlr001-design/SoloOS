extends Node2D
# DIMHOLD playable prototype (placeholder visuals). Rules: docs/design/01_rules.md v0.2.
# Keys: Space=End Day, F=toggle forecast, R=restart, 1-6=variant set + restart, Esc=cancel selection.

const GS := preload("res://sim/game_state.gd")

const VSETS := [
	["murk"], ["murk", "spore"], ["rime", "spore"], ["rust", "murk"], ["rime", "hollow"],
	["murk", "rime", "spore", "rust", "hollow"],
]
const VNAMES := ["murk", "murk+spore", "rime+spore", "rust+murk", "rime+hollow", "all5"]
const SIZE := 19.0
const CENTER := Vector2(215, 182)
const T_COLOR := {
	"meadow": Color(0.35, 0.62, 0.30), "woodland": Color(0.18, 0.45, 0.25), "hill": Color(0.62, 0.55, 0.32),
	"marsh": Color(0.30, 0.50, 0.45), "ruins": Color(0.55, 0.52, 0.55), "crystal": Color(0.45, 0.78, 0.85),
	"shore": Color(0.30, 0.50, 0.80), "salt": Color(0.85, 0.85, 0.80), "frost": Color(0.70, 0.85, 0.95),
	"cinder": Color(0.40, 0.30, 0.28),
}
const V_COLOR := {
	"murk": Color(0.35, 0.15, 0.60), "rime": Color(0.30, 0.75, 0.95), "spore": Color(0.85, 0.70, 0.15),
	"rust": Color(0.80, 0.40, 0.15), "hollow": Color(0.05, 0.05, 0.10),
}
const S_CODE := {
	"hearth": "H", "lantern": "L", "brazier": "Br", "beacon": "Bc", "palisade": "Pa", "rampart": "Ra",
	"pyre": "Py", "sunwell": "Sw", "camp": "Ca", "cottage": "Co", "press": "Pr",
}

var g: RefCounted
var vset_idx := 0
var seed_n := 1
var selected := -1
var hover := -1
var mode := ""          # "", "card", "build"
var card_idx := -1
var build_name := ""
var placed_today := false
var show_fc := true
var msg := "Welcome. Place a tile card, build, then End Day (Space)."
var fc: Array = []
var ui: CanvasLayer
var panel_nodes: Array = []
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	ui = CanvasLayer.new()
	add_child(ui)
	_new_game()


func _new_game() -> void:
	g = GS.new()
	g.setup(seed_n, VSETS[vset_idx])
	g.dawn()
	selected = -1; mode = ""; card_idx = -1; build_name = ""; placed_today = false
	msg = "Day 1. Variants: %s. Draft a tile (card -> frontier hex)." % VNAMES[vset_idx]
	_refresh()


func _refresh() -> void:
	fc = g.forecast()
	_build_ui()
	queue_redraw()


# ---------------- layout ----------------
func hex_pos(i: int) -> Vector2:
	var c: Vector2i = GS.COORDS[i]
	return CENTER + Vector2(SIZE * sqrt(3.0) * (c.x + c.y / 2.0), SIZE * 1.5 * c.y)


func hex_pts(p: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(6):
		var a := deg_to_rad(60.0 * k - 30.0)
		pts.append(p + Vector2(cos(a), sin(a)) * s)
	return pts


func pick(mp: Vector2) -> int:
	var best := -1
	var bd := SIZE * 0.95
	for i in range(GS.N):
		var d := hex_pos(i).distance_to(mp)
		if d < bd:
			bd = d; best = i
	return best


# ---------------- UI ----------------
func _build_ui() -> void:
	for n in panel_nodes: n.queue_free()
	panel_nodes.clear()
	var x := 392.0
	var y := 4.0
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.add_theme_font_size_override("font_size", 8)
	var resist_txt := ""
	for c in GS.CLASSES:
		if g.resist[c] > 0: resist_txt += " RESIST-%s(%d)" % [c, g.resist[c]]
	lbl.text = "Day %d/%d  Rifts %d  Sealed %d\nM %d  L %d  Folk %d  LP %d%s\nLit %d  Ember~%d" % [g.day, g.days, g.rift.size(), g.sealed, g.M, g.L, g.folk, g.lp, resist_txt, g.lit_count(), int(g.ember())]
	ui.add_child(lbl); panel_nodes.append(lbl)
	y += 40
	if not g.over:
		for k in range(g.cards.size()):
			var b := _btn("Card %d: %s%s" % [k + 1, g.cards[k], " (placed)" if placed_today else ""], Vector2(x, y), Vector2(116, 14))
			b.disabled = placed_today
			b.pressed.connect(_on_card.bind(k))
			y += 15
		y += 3
		var col := 0
		for n in GS.BUILD_ORDER:
			var c: Array = GS.STRUCT[n]
			var bx := x + col * 120.0
			var b2 := _btn("%s %dM%dL" % [n, c[0], c[1]], Vector2(bx, y), Vector2(116, 14))
			b2.pressed.connect(_on_build.bind(n))
			col += 1
			if col == 2:
				col = 0; y += 15
		if col == 1: y += 15
		y += 3
		var ab_y := y
		var bb := _btn("Burst (3L 2LP)", Vector2(x, ab_y), Vector2(116, 14))
		bb.disabled = selected < 0 or not g.can_burst(selected)
		bb.pressed.connect(_on_burst)
		var pb := _btn("Pyre fire (3L 1LP)", Vector2(x + 120, ab_y), Vector2(116, 14))
		pb.disabled = selected < 0 or not g.can_pyre(selected)
		pb.pressed.connect(_on_pyre)
		y += 15
		var sb := _btn("Seal Rift (5L 2LP)", Vector2(x, y), Vector2(116, 14))
		sb.disabled = selected < 0 or g.seal_targets(selected).is_empty()
		sb.pressed.connect(_on_seal)
		var fb := _btn("Forecast: %s (F)" % ("ON" if show_fc else "off"), Vector2(x + 120, y), Vector2(116, 14))
		fb.pressed.connect(_toggle_fc)
		y += 18
	var eb := _btn("END DAY (Space)" if not g.over else "NEW GAME (R)", Vector2(x, y), Vector2(236, 18))
	eb.pressed.connect(_end_day if not g.over else _new_game)
	y += 22
	var vb := _btn("Variants: %s  (keys 1-6)" % VNAMES[vset_idx], Vector2(x, y), Vector2(236, 14))
	vb.pressed.connect(_next_vset)
	y += 18
	var ml := Label.new()
	ml.position = Vector2(x, y)
	ml.size = Vector2(240, 80)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.add_theme_font_size_override("font_size", 8)
	ml.text = _info_text()
	ui.add_child(ml); panel_nodes.append(ml)


func _btn(t: String, p: Vector2, s: Vector2) -> Button:
	var b := Button.new()
	b.text = t; b.position = p; b.size = s
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_NONE
	ui.add_child(b); panel_nodes.append(b)
	return b


func _info_text() -> String:
	var t := msg + "\n"
	var i := hover if hover >= 0 else selected
	if i >= 0:
		var pr: Array = fc[2]; var gd: Array = fc[3]; var parts: Array = fc[4]
		t += "\nTile %s: %s%s%s\n" % [str(GS.COORDS[i]), g.terrain[i], "  [%s]" % g.structs[i] if g.structs[i] != "" else "", "  SCAR" if g.scar[i] else ""]
		t += "lit=%s  blight=%d %s\nPressure %d vs Guard %d (Light %d, Ward %d)\nNext dusk: %d" % [str(g.lit[i]), g.inten[i], g.var_[i], pr[i], gd[i], parts[i][0], parts[i][2], fc[0][i]]
	if g.over:
		t += "\n\n%s  Ember %d" % ["VICTORY" if g.won else "DEFEAT", int(g.ember())]
	return t


# ---------------- actions ----------------
func _on_card(k: int) -> void:
	mode = "card"; card_idx = k; build_name = ""
	msg = "Click a highlighted frontier hex to place %s." % g.cards[k]
	_refresh()


func _on_build(n: String) -> void:
	mode = "build"; build_name = n; card_idx = -1
	msg = "Click a lit empty hex to build %s." % n
	_refresh()


func _on_burst() -> void:
	g.burst(selected); msg = "Beacon Burst!"; _refresh()


func _on_pyre() -> void:
	g.pyre_fire(selected); msg = "Pyre fire!"; _refresh()


func _on_seal() -> void:
	var t: Array = g.seal_targets(selected)
	g.seal(selected, t[0]); msg = "Rift sealed!"; _refresh()


func _toggle_fc() -> void:
	show_fc = not show_fc; _refresh()


func _next_vset() -> void:
	vset_idx = (vset_idx + 1) % VSETS.size(); seed_n += 1; _new_game()


func _end_day() -> void:
	if g.over: return
	var before: int = g.lit_count()
	g.end_day()
	if g.over:
		msg = "Stage over: %s" % ("VICTORY" if g.won else "DEFEAT")
	else:
		g.dawn()
		placed_today = false; mode = ""; card_idx = -1; build_name = ""
		msg = "Day %d. Lit %d -> %d." % [g.day, before, g.lit_count()]
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := pick(e.position)
		if h != hover:
			hover = h; _build_ui(); queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := pick(e.position)
		if i < 0 or g.over: return
		if mode == "card" and card_idx >= 0 and not placed_today:
			if g.frontier().has(i):
				g.place_tile(i, card_idx); placed_today = true; mode = ""; card_idx = -1
				msg = "Placed tile. Now build / use abilities."
			else:
				msg = "Not a frontier hex."
		elif mode == "build" and build_name != "":
			if g.can_build(build_name, i):
				g.build(build_name, i); msg = "Built %s." % build_name
			else:
				msg = "Cannot build %s there (cost/LP/blight/occupied)." % build_name
		else:
			selected = i
		_refresh()
	elif e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_SPACE: _end_day()
			KEY_F: _toggle_fc()
			KEY_R: _new_game()
			KEY_ESCAPE: mode = ""; card_idx = -1; build_name = ""; selected = -1; _refresh()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				vset_idx = e.keycode - KEY_1; seed_n += 1; _new_game()


# ---------------- drawing ----------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.07, 0.07, 0.10))
	if g == null: return
	var pr: Array = fc[2]; var gd: Array = fc[3]
	var frontier: Array = g.frontier() if (mode == "card" and not placed_today) else []
	for i in range(GS.N):
		var p := hex_pos(i)
		var base: Color = T_COLOR[g.terrain[i]]
		var col: Color
		if g.scar[i]: col = Color(0.02, 0.02, 0.02)
		elif g.lit[i]: col = base
		else: col = base * Color(0.30, 0.30, 0.38)
		draw_colored_polygon(hex_pts(p, SIZE - 1.0), col)
		if g.inten[i] > 0:
			var vc: Color = V_COLOR.get(g.var_[i], Color(0.5, 0.2, 0.5))
			draw_colored_polygon(hex_pts(p, SIZE - 1.0), Color(vc.r, vc.g, vc.b, 0.30 + 0.22 * g.inten[i]))
		if g.rift.has(i):
			draw_polyline(hex_pts(p, SIZE - 2.0) + PackedVector2Array([hex_pts(p, SIZE - 2.0)[0]]), Color(1, 0.2, 0.2), 2.0)
		if frontier.has(i):
			draw_polyline(hex_pts(p, SIZE - 2.0) + PackedVector2Array([hex_pts(p, SIZE - 2.0)[0]]), Color(1, 1, 0.3), 1.5)
		if g.structs[i] != "":
			var code: String = S_CODE.get(g.structs[i], "?")
			var tc := Color(1, 1, 1) if not g.disabled(i) else Color(0.6, 0.6, 0.6)
			if g.dark.has(i): tc = Color(0.5, 0.4, 0.2)
			draw_string(font, p + Vector2(-8, 3), code, HORIZONTAL_ALIGNMENT_CENTER, 16, 9, tc)
		if g.inten[i] > 0:
			draw_string(font, p + Vector2(-3, 13), str(g.inten[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))
		if show_fc and not g.scar[i] and not g.rift.has(i):
			var d: int = fc[0][i] - g.inten[i]
			if d > 0:
				draw_string(font, p + Vector2(4, -8), "^%d" % fc[0][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.35, 0.35))
			elif d < 0:
				draw_string(font, p + Vector2(4, -8), "v%d" % fc[0][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 1, 0.5))
		if g.lit[i] and g.structs[i] == "" and g.inten[i] == 0 and show_fc:
			draw_string(font, p + Vector2(-10, 13), "G%d" % gd[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 0.6, 0.7))
		if i == selected:
			draw_polyline(hex_pts(p, SIZE - 1.0) + PackedVector2Array([hex_pts(p, SIZE - 1.0)[0]]), Color(1, 1, 1), 2.0)
		elif i == hover:
			draw_polyline(hex_pts(p, SIZE - 1.0) + PackedVector2Array([hex_pts(p, SIZE - 1.0)[0]]), Color(0.8, 0.8, 0.8), 1.0)
	if g.over:
		draw_rect(Rect2(60, 150, 300, 40), Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(70, 177), "%s - press R" % ("VICTORY" if g.won else "DEFEAT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4))

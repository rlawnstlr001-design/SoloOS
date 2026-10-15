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
var font: Font
var ko := OS.get_locale_language() == "ko"
var show_help := true


func T(en: String, kr: String) -> String:
	return kr if ko else en


func _style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 3; sb.content_margin_right = 3
	sb.content_margin_top = 0; sb.content_margin_bottom = 0
	return sb


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo", "NanumGothic", "sans-serif"])
	sf.fallbacks = [ThemeDB.fallback_font]
	font = sf
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


# ---------------- UI (self-drawn buttons: identical look on every Godot version) ----------------
var btns: Array = []     # {r: Rect2, t: String, cb: Callable, on: bool, act: bool}
var texts: Array = []    # {p: Vector2, w: float, t: String, c: Color, fs: int}
var hover_btn := -1


func _build_ui() -> void:
	btns.clear(); texts.clear()
	var x := 392.0
	var y := 4.0
	var resist_txt := ""
	for c in GS.CLASSES:
		if g.resist[c] > 0: resist_txt += " RESIST-%s(%d)" % [c, g.resist[c]]
	_text(Vector2(x, y + 8), 240, "Day %d/%d   Rifts %d   Sealed %d\nM %d   L %d   Folk %d   LP %d%s\nLit %d   Ember~%d" % [g.day, g.days, g.rift.size(), g.sealed, g.M, g.L, g.folk, g.lp, resist_txt, g.lit_count(), int(g.ember())], Color(1, 1, 1), 9)
	y += 40
	_text(Vector2(x, y + 8), 240, _hint(), Color(1, 0.9, 0.4), 9)
	y += 30
	if not g.over:
		for k in range(g.cards.size()):
			_btn(T("Card %d: %s", "카드 %d: %s") % [k + 1, g.cards[k]] + (T("  (used)", "  (사용됨)") if placed_today else ""), Vector2(x, y), Vector2(236, 13), _on_card.bind(k), not placed_today, mode == "card" and card_idx == k)
			y += 15
		y += 3
		var col := 0
		for n in GS.BUILD_ORDER:
			var c: Array = GS.STRUCT[n]
			_btn("%s %dM %dL" % [n, c[0], c[1]], Vector2(x + col * 120.0, y), Vector2(116, 13), _on_build.bind(n), g.M >= c[0] and g.L >= c[1] and g.lp >= c[2], mode == "build" and build_name == n)
			col += 1
			if col == 2:
				col = 0; y += 15
		if col == 1: y += 15
		y += 3
		_btn("Burst (3L 2LP)", Vector2(x, y), Vector2(116, 13), _on_burst, selected >= 0 and g.can_burst(selected), false)
		_btn("Pyre fire (3L 1LP)", Vector2(x + 120, y), Vector2(116, 13), _on_pyre, selected >= 0 and g.can_pyre(selected), false)
		y += 15
		_btn("Seal Rift (5L 2LP)", Vector2(x, y), Vector2(116, 13), _on_seal, selected >= 0 and not g.seal_targets(selected).is_empty(), false)
		_btn("Forecast: %s (F)" % ("ON" if show_fc else "off"), Vector2(x + 120, y), Vector2(116, 13), _toggle_fc, true, show_fc)
		y += 18
	_btn(T("END DAY (Space)", "하루 끝내기 (Space)") if not g.over else T("NEW GAME (R)", "새 게임 (R)"), Vector2(x, y), Vector2(236, 17), _end_day if not g.over else _new_game, true, false)
	y += 21
	_btn(T("Variant: %s (1-6)", "오염: %s (1-6)") % VNAMES[vset_idx], Vector2(x, y), Vector2(116, 13), _next_vset, true, false)
	_btn(T("HELP (H)", "도움말 (H)"), Vector2(x + 120, y), Vector2(116, 13), _toggle_help, true, show_help)
	y += 18
	_text(Vector2(x, y + 8), 240, _info_text(), Color(0.85, 0.85, 0.9), 8)


func _btn(t: String, p: Vector2, sz: Vector2, cb: Callable, on: bool, act: bool) -> void:
	btns.append({"r": Rect2(p, sz), "t": t, "cb": cb, "on": on, "act": act})


func _text(p: Vector2, w: float, t: String, c: Color, fs: int) -> void:
	texts.append({"p": p, "w": w, "t": t, "c": c, "fs": fs})


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


func _draw_ui() -> void:
	for tx in texts:
		draw_multiline_string(font, tx["p"], tx["t"], HORIZONTAL_ALIGNMENT_LEFT, tx["w"], tx["fs"], -1, tx["c"])
	for i in range(btns.size()):
		var b: Dictionary = btns[i]
		var r: Rect2 = b["r"]
		var bg := Color(0.20, 0.24, 0.34)
		if not b["on"]: bg = Color(0.11, 0.12, 0.16)
		elif b["act"]: bg = Color(0.50, 0.45, 0.15)
		elif i == hover_btn: bg = Color(0.32, 0.38, 0.55)
		draw_rect(r, bg)
		draw_rect(r, Color(0.5, 0.55, 0.7) if b["on"] else Color(0.25, 0.26, 0.32), false, 1.0)
		draw_string(font, r.position + Vector2(4, r.size.y - 3), b["t"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 8, Color(1, 1, 1) if b["on"] else Color(0.45, 0.45, 0.5))


func _btn_at(p: Vector2) -> int:
	for i in range(btns.size()):
		if btns[i]["r"].has_point(p): return i
	return -1


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


func _toggle_help() -> void:
	show_help = not show_help
	queue_redraw()


func _hint() -> String:
	if g.over:
		return T("Stage over. Press R for a new game.", "끝났습니다. R 키로 새 게임.")
	if not placed_today:
		return T("1) Click a Card button, then a YELLOW-outlined hex to expand your land.", "1) Card 버튼을 누르고 노란 테두리 칸을 클릭해 영토를 넓히세요.")
	if mode == "build":
		return T("Click a lit hex (not purple) to build. Esc cancels.", "밝은 내 칸(보라색 아님)을 클릭해 짓기. Esc로 취소.")
	if g.lp > 0 and g.M >= 2:
		return T("2) Click a build button (try lantern), then a lit hex near the purple. Then press Space.", "2) 건설 버튼(예: lantern) 후 보라색이 다가오는 쪽 내 칸 클릭. 끝나면 Space.")
	return T("3) Press Space to end the day.", "3) Space를 눌러 하루를 끝내세요.")


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
		var hb := _btn_at(e.position)
		if h != hover or hb != hover_btn:
			hover = h; hover_btn = hb; _build_ui(); queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if show_help:
			show_help = false; queue_redraw(); return
		var bi := _btn_at(e.position)
		if bi >= 0:
			if btns[bi]["on"]: btns[bi]["cb"].call()
			return
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
			KEY_H: _toggle_help()
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
	_draw_ui()
	if show_help:
		var lines: Array = [
			T("HOW TO PLAY (click anywhere to close, H to reopen)", "플레이 방법 (아무 곳이나 클릭하면 닫힘, H로 다시 열기)"),
			"",
			T("GOAL: keep the center hex H alive for 12 days.", "목표: 12일 동안 가운데 H(베이스)를 지키기."),
			T("Purple = blight. It spreads every night from the red Rifts.", "보라색 = 오염. 밤마다 빨간 테두리 Rift에서 번집니다."),
			T("A number on a hex = blight strength (1-3). ^1 = gets worse tonight.", "칸의 숫자 = 오염 강도(1~3). ^1 = 오늘 밤 악화 예고."),
			T("G2 = defense of that hex. Blight spreads where pressure > defense.", "G2 = 그 칸의 방어력. 오염 압력이 방어력보다 크면 번집니다."),
			"",
			T("EACH DAY:", "하루 순서:"),
			T("1) Card button -> click a yellow-outlined hex: expand your land (once a day).", "1) Card 버튼 -> 노란 테두리 칸 클릭: 영토 확장 (하루 1번)"),
			T("2) Build button -> click a lit hex: build. Lantern/Brazier give light (defense),", "2) 건설 버튼 -> 내 칸 클릭: 건설. Lantern/Brazier=빛(방어),"),
			T("   Palisade/Rampart give walls. Put them where purple is coming.", "   Palisade/Rampart=방벽. 보라색이 다가오는 쪽에 지으세요."),
			T("3) Press Space: night falls, blight spreads, next day.", "3) Space: 밤이 되어 오염이 번지고 다음 날로."),
			"",
			T("TIPS: Brazier burns Rime/Spore.", "팁: Brazier는 Rime/Spore 오염을 태웁니다."),
			T("Beacon (Bc): select it, then press Burst to cleanse nearby blight.", "Beacon(Bc): 선택 후 Burst 버튼으로 주변 오염 정화."),
		]
		draw_rect(Rect2(10, 40, 380, 280), Color(0.02, 0.02, 0.05, 0.93))
		var yy := 58.0
		for ln in lines:
			draw_string(font, Vector2(20, yy), ln, HORIZONTAL_ALIGNMENT_LEFT, 360, 9, Color(1, 0.95, 0.7) if yy < 60 else Color(0.92, 0.92, 0.95))
			yy += 14.5
	if g.over:
		draw_rect(Rect2(60, 150, 300, 40), Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(70, 177), "%s - press R" % ("VICTORY" if g.won else "DEFEAT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4))

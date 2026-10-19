extends Node2D
# DIMHOLD playable prototype (placeholder visuals). Rules: docs/design/01_rules.md v0.2.
# Keys: Space=End Day, F=toggle forecast, R=restart, 1-6=variant set + restart, Esc=cancel selection.

const GS := preload("res://sim/game_state.gd")
const TX := preload("res://scripts/texts.gd")

const VSETS := [
	["murk"], ["murk", "spore"], ["rime", "spore"], ["rust", "murk"], ["rime", "hollow"],
	["murk", "rime", "spore", "rust", "hollow"],
]
const VNAMES := ["murk", "murk+spore", "rime+spore", "rust+murk", "rime+hollow", "all5"]
const SIZE := 19.0
const CENTER := Vector2(215, 168)
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
var msg := ""
var fc: Array = []
var font: Font
var ko := true   # Korean by default; toggle in the menu (L key)
var show_help := false
var scr := "menu"          # "menu", "tutorial", "play"
var tut := 0
var tut_a := -1
var tut_b := -1
var tut_src: Array = []
var flash: Dictionary = {}   # tile -> "worse" | "better" | "lost"
var flash_t := 0.0
var show_codex := false
var mouse := Vector2.ZERO

const TUT := [
	{"id": "intro", "next": true, "en": "Welcome! GOAL: keep the center hex H alive for 12 days. Everything else is a tool for that.", "kr": "환영합니다! 목표: 12일 동안 가운데 '본'(본진)을 지키는 것. 나머지는 전부 그 수단입니다."},
	{"id": "blight", "next": true, "en": "The glowing purple hexes are BLIGHT. It spreads every night. This one is already right next to your land!", "kr": "반짝이는 보라색 칸이 '오염'입니다. 밤마다 번집니다. 지금 내 땅 바로 옆까지 와 있어요!"},
	{"id": "danger", "next": true, "en": "Red triangle = DANGER. P3>D2 means blight Pressure 3 beats your Defense 2, so that hex is eaten tonight. Red arrows show where it comes from.", "kr": "빨간 삼각형 = 위험. 압3>방2는 오염 압력 3이 내 방어 2를 이겨서 오늘 밤 그 칸이 먹힌다는 뜻. 빨간 화살표가 오염이 오는 방향입니다."},
	{"id": "build", "next": false, "en": "Add defense! Click the PALISADE button, then click each glowing hex (+1 defense per wall).", "kr": "방어를 올리세요! '목책' 버튼을 누르고, 반짝이는 칸을 각각 클릭하세요 (목책 하나당 방어 +1)."},
	{"id": "safe", "next": true, "en": "Green check = SAFE. Defense 3 now holds against Pressure 3. You can see danger BEFORE it happens and fix it. That is the whole game.", "kr": "초록 체크 = 안전. 방어 3이 압력 3을 막습니다. 위험을 미리 보고 막는 것, 이게 이 게임의 핵심입니다."},
	{"id": "expand", "next": false, "en": "Now grow: click a CARD button, then a yellow-outlined hex. More land = more room to build defenses.", "kr": "이제 넓히세요: '카드' 버튼을 누르고 노란 테두리 칸을 클릭. 땅이 넓어야 방어를 지을 자리가 생깁니다."},
	{"id": "endday", "next": false, "en": "Press END DAY. Night falls and the blight spreads.", "kr": "'하루 끝내기'를 누르세요(또는 Space). 밤이 되어 오염이 번집니다."},
	{"id": "result", "next": true, "en": "Your land held! Blight crept into empty land instead. Every night it comes closer: keep walling the red-triangle hexes and expand a little each day.", "kr": "내 땅이 버텼습니다! 오염은 빈 땅으로 번졌어요. 매일 밤 가까워지니, 빨간 삼각형이 뜨는 칸을 막고 하루에 한 칸씩 넓히세요."},
	{"id": "tools", "next": true, "final": true, "en": "More tools: LANTERN/BRAZIER add light (defense). BEACON can BURST to cleanse blight. Survive 12 days to win. Good luck!", "kr": "다른 도구: 등불/화로=빛(방어). 봉화는 '정화'로 오염 제거. 12일 버티면 승리. 행운을 빕니다!"},
]


func T(en: String, kr: String) -> String:
	return kr if ko else en


const KO := {
	"meadow": "초원", "woodland": "숲", "hill": "언덕", "marsh": "습지", "ruins": "유적", "crystal": "수정",
	"shore": "물가", "salt": "소금밭", "frost": "서리밭", "cinder": "잿더미",
	"hearth": "본진", "lantern": "등불", "brazier": "화로", "beacon": "봉화", "palisade": "목책", "rampart": "성벽",
	"pyre": "화염탑", "sunwell": "태양우물", "camp": "채집소", "cottage": "오두막", "press": "압착소",
	"murk": "머크", "rime": "서리", "spore": "포자", "rust": "녹", "hollow": "공허",
	"light": "빛", "flame": "화염", "ward": "방벽",
}
const KO_CODE := {
	"hearth": "본", "lantern": "등", "brazier": "화", "beacon": "봉", "palisade": "목", "rampart": "성",
	"pyre": "탑", "sunwell": "우", "camp": "채", "cottage": "집", "press": "압",
}
const VNAMES_KO := ["머크", "머크+포자", "서리+포자", "녹+머크", "서리+공허", "5종 전부"]


func N(k: String) -> String:
	return KO.get(k, k) if ko else k


func VN(i: int) -> String:
	return VNAMES_KO[i] if ko else VNAMES[i]


func _style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 3; sb.content_margin_right = 3
	sb.content_margin_top = 0; sb.content_margin_bottom = 0
	return sb


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo", "NanumGothic", "WenQuanYi Zen Hei", "Unifont", "sans-serif"])
	sf.fallbacks = [ThemeDB.fallback_font]
	sf.multichannel_signed_distance_field = true
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font = sf
	g = GS.new()
	g.setup(1, VSETS[0])
	g.dawn()
	scr = "menu"
	_refresh()


func _start_free() -> void:
	scr = "play"
	_new_game()


func _start_tutorial() -> void:
	scr = "tutorial"
	tut = 0
	g = GS.new()
	g.setup(3, ["murk"])
	tut_a = GS.IDX[Vector2i(1, 0)]
	tut_b = GS.IDX[Vector2i(1, -1)]
	g.terrain[tut_a] = "meadow"; g.terrain[tut_b] = "meadow"
	tut_src = [GS.IDX[Vector2i(2, -1)], GS.IDX[Vector2i(3, -1)]]
	for t in tut_src:
		g.inten[t] = 3; g.var_[t] = "murk"
	g.dawn()
	g.cards = ["meadow", "woodland", "hill"]
	selected = -1; mode = ""; card_idx = -1; build_name = ""; placed_today = false; flash.clear()
	msg = ""
	_refresh()


func _open_menu() -> void:
	scr = "menu"; flash.clear(); _refresh()


func _toggle_lang() -> void:
	ko = not ko; _refresh()


func _new_game() -> void:
	if scr == "menu": scr = "play"
	flash.clear()
	g = GS.new()
	g.setup(seed_n, VSETS[vset_idx])
	g.dawn()
	selected = -1; mode = ""; card_idx = -1; build_name = ""; placed_today = false
	msg = T("Day 1. Variant: %s. Draft a tile (card -> frontier hex).", "1일차. 오염 종류: %s. 카드로 영토를 넓혀 보세요.") % VN(vset_idx)
	_refresh()


func _refresh() -> void:
	fc = g.forecast()
	_tut_progress()
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
	if scr == "menu":
		_build_menu()
		return
	var x := 392.0
	var y := 4.0
	var resist_txt := ""
	for c in GS.CLASSES:
		if g.resist[c] > 0: resist_txt += T(" RESIST-%s(%d)", " 내성-%s(%d)") % [N(c), g.resist[c]]
	_text(Vector2(x, y + 8), 240, T("Day %d/%d   Rifts %d   Sealed %d\nM %d   L %d   Folk %d   LP %d%s\nLit %d   Ember~%d", "%d/%d일차   균열 %d   봉인 %d\n자재 %d   빛 %d   주민 %d   행동력 %d%s\n점등 %d칸   불씨~%d") % [g.day, g.days, g.rift.size(), g.sealed, g.M, g.L, g.folk, g.lp, resist_txt, g.lit_count(), int(g.ember())], Color(1, 1, 1), 10)
	y += 40
	_text(Vector2(x, y + 8), 240, _hint() if scr != "tutorial" else T("Tutorial: follow the glowing step.", "튜토리얼: 반짝이는 단계를 따라 하세요."), Color(1, 0.9, 0.4), 10)
	y += 30
	if not g.over:
		for k in range(g.cards.size()):
			_btn(T("Card %d: %s", "카드 %d: %s") % [k + 1, N(g.cards[k])] + (T("  (used)", "  (사용됨)") if placed_today else ""), Vector2(x, y), Vector2(236, 13), _on_card.bind(k), not placed_today, mode == "card" and card_idx == k, T("Expand your land with this tile (once a day).\n\n", "이 지형 타일로 영토를 한 칸 넓힙니다 (하루 1번).\n\n") + (TX.TERR_KO if ko else TX.TERR_EN)[g.cards[k]])
			y += 15
		y += 3
		var col := 0
		for n in GS.BUILD_ORDER:
			var c: Array = GS.STRUCT[n]
			_btn(T("%s %dM %dL", "%s 자재%d 빛%d") % [N(n), c[0], c[1]], Vector2(x + col * 120.0, y), Vector2(116, 13), _on_build.bind(n), g.M >= c[0] and g.L >= c[1] and g.lp >= c[2], mode == "build" and build_name == n, stip(n))
			col += 1
			if col == 2:
				col = 0; y += 15
		if col == 1: y += 15
		y += 3
		_btn(T("Burst (3L 2LP)", "정화 (빛3 행동2)"), Vector2(x, y), Vector2(116, 13), _on_burst, selected >= 0 and g.can_burst(selected), false, T("Select one of your Beacons first.\n\n", "먼저 지도에서 내 봉화를 클릭해 선택하세요.\n\n") + sdesc("beacon")[2])
		_btn(T("Pyre fire (3L 1LP)", "화염 발사 (빛3 행동1)"), Vector2(x + 120, y), Vector2(116, 13), _on_pyre, selected >= 0 and g.can_pyre(selected), false, T("Select one of your Pyres first.\n\n", "먼저 지도에서 내 화염탑을 클릭해 선택하세요.\n\n") + sdesc("pyre")[2])
		y += 15
		_btn(T("Seal Rift (5L 2LP)", "균열 봉인 (빛5 행동2)"), Vector2(x, y), Vector2(116, 13), _on_seal, selected >= 0 and not g.seal_targets(selected).is_empty(), false, T("Select a Sunwell near a Rift first.\n\n", "먼저 균열 근처의 태양우물을 선택하세요.\n\n") + sdesc("sunwell")[2])
		_btn(T("Forecast: %s (F)", "예고: %s (F)") % [T("ON", "켜짐") if show_fc else T("off", "꺼짐")], Vector2(x + 120, y), Vector2(116, 13), _toggle_fc, true, show_fc, T("Shows what happens tonight: red triangle = this hex will be eaten, green check = safe.", "오늘 밤 결과를 미리 보여줍니다: 빨간 삼각형 = 먹힐 칸, 초록 체크 = 안전."))
		y += 18
	_btn(T("END DAY (Space)", "하루 끝내기 (Space)") if not g.over else T("NEW GAME (R)", "새 게임 (R)"), Vector2(x, y), Vector2(236, 17), _end_day if not g.over else _new_game, true, false, T("Night falls: blight spreads, buildings produce, next day begins.", "밤이 됩니다: 오염이 번지고, 건물이 생산하고, 다음 날이 시작됩니다."))
	y += 21
	_btn(T("Blight: %s", "오염: %s") % VN(vset_idx), Vector2(x, y), Vector2(96, 13), _next_vset, true, false, T("Change the blight type and restart (keys 1-6).", "오염 종류를 바꾸고 새로 시작 (숫자키 1-6)."))
	_btn(T("Help (H)", "도움말 (H)"), Vector2(x + 99, y), Vector2(66, 13), _toggle_help, true, show_help)
	_btn(T("Codex (C)", "도감 (C)"), Vector2(x + 168, y), Vector2(68, 13), _toggle_codex, true, show_codex, T("What every building and blight does.", "모든 건물과 오염의 역할 설명."))
	y += 18
	_text(Vector2(x, y + 8), 240, _info_text(), Color(0.85, 0.85, 0.9), 9)
	if scr == "tutorial":
		var st: Dictionary = TUT[tut]
		if st["next"]:
			_btn(T("START PLAYING >", "게임 시작 >") if st.get("final", false) else T("NEXT >", "다음 >"), Vector2(290, 326), Vector2(94, 18), _tut_next, true, true)
		_btn(T("Skip tutorial", "튜토리얼 건너뛰기"), Vector2(392, 344), Vector2(120, 12), _start_free, true, false)


func _btn(t: String, p: Vector2, sz: Vector2, cb: Callable, on: bool, act: bool, tip: String = "") -> void:
	btns.append({"r": Rect2(p, sz), "t": t, "cb": cb, "on": on, "act": act, "tip": tip})


func sdesc(n: String) -> Array:
	return (TX.STRUCT_KO if ko else TX.STRUCT_EN).get(n, [n, "", ""])


func stip(n: String) -> String:
	var d: Array = sdesc(n)
	var c: Array = GS.STRUCT[n]
	return "%s\n%s\n\n%s\n\n%s" % [d[0], d[1], d[2], T("Cost: %d materials, %d light, %d action(s)", "비용: 자재 %d, 빛 %d, 행동 %d") % [c[0], c[1], c[2]]]


func vdesc(v: String) -> Array:
	return (TX.VAR_KO if ko else TX.VAR_EN).get(v, [v, ""])


func _text(p: Vector2, w: float, t: String, c: Color, fs: int) -> void:
	texts.append({"p": p, "w": w, "t": t, "c": c, "fs": fs})


func _info_text() -> String:
	var t := msg + "\n"
	var i := hover if hover >= 0 else selected
	if i >= 0:
		var pr: Array = fc[2]; var gd: Array = fc[3]; var parts: Array = fc[4]
		t += "\n" + T("Tile %s: %s%s%s\n", "칸 %s: %s%s%s\n") % [str(GS.COORDS[i]), N(g.terrain[i]), "  [%s]" % N(g.structs[i]) if g.structs[i] != "" else "", T("  SCAR", "  파괴됨") if g.scar[i] else ""]
		t += T("lit=%s  blight=%d %s\nPressure %d vs Guard %d (Light %d, Ward %d)\nNext dusk: %d", "내 땅=%s  오염=%d %s\n압력 %d vs 방어 %d (빛 %d, 방벽 %d)\n오늘 밤 이후: %d") % [T(str(g.lit[i]), "예" if g.lit[i] else "아니오"), g.inten[i], N(g.var_[i]), pr[i], gd[i], parts[i][0], parts[i][2], fc[0][i]]
	if i >= 0:
		if g.structs[i] != "":
			t += "\n" + sdesc(g.structs[i])[0] + ": " + sdesc(g.structs[i])[1]
		if g.inten[i] > 0 and g.var_[i] != "":
			t += "\n" + vdesc(g.var_[i])[0] + ": " + vdesc(g.var_[i])[1]
	if g.over:
		t += "\n\n%s  %s %d" % [T("VICTORY", "승리") if g.won else T("DEFEAT", "패배"), T("Ember", "불씨"), int(g.ember())]
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
		draw_string(font, r.position + Vector2(4, r.size.y - 3), b["t"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 9, Color(1, 1, 1) if b["on"] else Color(0.45, 0.45, 0.5))


func _draw_tooltip() -> void:
	if hover_btn < 0 or hover_btn >= btns.size(): return
	var tip: String = btns[hover_btn].get("tip", "")
	if tip == "": return
	var w := 240.0
	var sz := font.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, w - 16, 10)
	var h := sz.y + 16
	var r: Rect2 = btns[hover_btn]["r"]
	var y := clampf(r.position.y - 8, 4, 356 - h)
	var box := Rect2(r.position.x - w - 8, y, w, h)
	draw_rect(box, Color(0.05, 0.06, 0.10, 0.97))
	draw_rect(box, Color(1, 0.85, 0.4), false, 1.5)
	draw_multiline_string(font, box.position + Vector2(8, 16), tip, HORIZONTAL_ALIGNMENT_LEFT, w - 16, 10, -1, Color(0.95, 0.95, 1))


func _draw_codex() -> void:
	draw_rect(Rect2(8, 8, 376, 344), Color(0.03, 0.03, 0.07, 0.97))
	draw_rect(Rect2(8, 8, 376, 344), Color(1, 0.85, 0.4), false, 1.5)
	draw_string(font, Vector2(18, 26), T("CODEX - click anywhere to close", "도감 - 아무 곳이나 클릭하면 닫힘"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.5))
	var y := 44.0
	for n in ["hearth", "lantern", "brazier", "beacon", "palisade", "rampart", "pyre", "sunwell", "camp", "cottage", "press"]:
		var d: Array = sdesc(n)
		draw_string(font, Vector2(18, y), "%s" % d[0], HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color(1, 0.85, 0.5))
		draw_string(font, Vector2(90, y), d[1], HORIZONTAL_ALIGNMENT_LEFT, 290, 10, Color(0.92, 0.92, 0.96))
		y += 15
	y += 6
	draw_string(font, Vector2(18, y), T("BLIGHT TYPES", "오염 종류"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.5))
	y += 14
	for v in ["murk", "rime", "spore", "rust", "hollow"]:
		var vd: Array = vdesc(v)
		var vc: Color = V_COLOR[v]
		draw_rect(Rect2(18, y - 8, 8, 8), vc.lightened(0.2))
		draw_multiline_string(font, Vector2(30, y), vd[0] + ": " + vd[1], HORIZONTAL_ALIGNMENT_LEFT, 346, 9, 2, Color(0.9, 0.9, 0.95))
		y += 22


func _btn_at(p: Vector2) -> int:
	for i in range(btns.size()):
		if btns[i]["r"].has_point(p): return i
	return -1


# ---------------- menu / tutorial ----------------
func _build_menu() -> void:
	_btn(T("TUTORIAL  (learn in 2 minutes)", "튜토리얼  (2분이면 배워요)"), Vector2(210, 150), Vector2(220, 26), _start_tutorial, true, true)
	_btn(T("FREE PLAY", "자유 플레이"), Vector2(210, 184), Vector2(220, 20), _start_free, true, false)
	_btn(T("Language: English  (click for 한국어)", "언어: 한국어  (클릭: English)"), Vector2(210, 212), Vector2(220, 14), _toggle_lang, true, false)


func _tut_allows(kind: String, arg: Variant = null) -> bool:
	if scr != "tutorial": return true
	match TUT[tut]["id"]:
		"build":
			if kind == "build_btn": return arg == "palisade"
			if kind == "tile_build": return arg == tut_a or arg == tut_b
			return false
		"expand":
			return kind == "card" or kind == "place"
		"endday":
			return kind == "endday"
	return false


func _tut_blocked() -> void:
	msg = T("Follow the glowing step.", "반짝이는 단계를 따라 하세요.")
	_refresh()


func _tut_progress() -> void:
	if scr != "tutorial": return
	var id: String = TUT[tut]["id"]
	if id == "build" and g.structs[tut_a] == "palisade" and g.structs[tut_b] == "palisade":
		_tut_advance()
	elif id == "expand" and placed_today:
		_tut_advance()
	elif id == "endday" and g.day >= 2:
		_tut_advance()


func _tut_advance() -> void:
	tut = mini(tut + 1, TUT.size() - 1)
	mode = ""; card_idx = -1; build_name = ""


func _tut_next() -> void:
	if tut < TUT.size() - 1:
		tut += 1
		_refresh()
	else:
		_start_free()


func _pulse() -> float:
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)


func _hl_hex(i: int, c: Color) -> void:
	var pts := hex_pts(hex_pos(i), SIZE + 1.0)
	pts.append(pts[0])
	draw_polyline(pts, Color(c.r, c.g, c.b, 0.35 + 0.65 * _pulse()), 3.0)


func _hl_btn(prefix: String) -> void:
	for b in btns:
		if String(b["t"]).begins_with(prefix):
			draw_rect((b["r"] as Rect2).grow(2.0), Color(1, 1, 0.2, 0.35 + 0.65 * _pulse()), false, 2.0)


func _arrow(a: Vector2, b: Vector2, c: Color) -> void:
	draw_line(a, b, c, 2.0)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([b, b - d * 6 + n * 3.5, b - d * 6 - n * 3.5]), c)


func _draw_markers() -> void:
	var pr: Array = fc[2]; var gd: Array = fc[3]
	for i in range(GS.N):
		if not g.lit[i] or g.scar[i] or pr[i] <= 0: continue
		var p := hex_pos(i)
		if pr[i] > gd[i]:
			for j in GS.NEI[i]:
				if g.inten[j] > 0 and not g.scar[j]:
					var a := hex_pos(j)
					var d := (p - a).normalized()
					_arrow(a + d * 7.0, p - d * 11.0, Color(1, 0.3, 0.3, 0.9))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -16), p + Vector2(-8, -2), p + Vector2(8, -2)]), Color(0.95, 0.12, 0.12))
			draw_string(font, p + Vector2(-3, -4), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1))
			if g.inten[i] == 0:
				draw_string(font, p + Vector2(-14, 15), T("P%d>D%d", "압%d>방%d") % [pr[i], gd[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.75, 0.75))
		else:
			draw_polyline(PackedVector2Array([p + Vector2(-6, -9), p + Vector2(-2, -5), p + Vector2(6, -15)]), Color(0.3, 1, 0.45), 2.5)
			if g.inten[i] == 0:
				draw_string(font, p + Vector2(-14, 15), T("P%d<=D%d", "압%d≤방%d") % [pr[i], gd[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.7, 1, 0.8))


func _draw_tutorial() -> void:
	var st: Dictionary = TUT[tut]
	match st["id"]:
		"intro": _hl_hex(GS.HEARTH, Color(1, 1, 0.3))
		"blight":
			for i in tut_src: _hl_hex(i, Color(1, 0.4, 1))
		"danger":
			_hl_hex(tut_a, Color(1, 0.2, 0.2)); _hl_hex(tut_b, Color(1, 0.2, 0.2))
		"build":
			_hl_btn(N("palisade"))
			for t in [tut_a, tut_b]:
				if g.structs[t] == "": _hl_hex(t, Color(1, 1, 0.3))
		"safe":
			_hl_hex(tut_a, Color(0.3, 1, 0.5)); _hl_hex(tut_b, Color(0.3, 1, 0.5))
		"expand": _hl_btn(T("Card", "카드"))
		"endday": _hl_btn(T("END DAY", "하루 끝내기"))
	draw_rect(Rect2(6, 304, 382, 52), Color(0.03, 0.03, 0.08, 0.95))
	draw_rect(Rect2(6, 304, 382, 52), Color(1, 0.9, 0.3), false, 1.5)
	draw_string(font, Vector2(14, 315), "%s %d/%d" % [T("TUTORIAL", "튜토리얼"), tut + 1, TUT.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.3))
	draw_multiline_string(font, Vector2(14, 327), T(st["en"], st["kr"]), HORIZONTAL_ALIGNMENT_LEFT, 270 if st["next"] else 366, 8, 4, Color(1, 1, 1))


func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.06, 0.09))
	var c := Vector2(320, 110)
	for k in range(7):
		var pts := hex_pts(c + Vector2((k - 3) * 38.0, 0), 17.0)
		draw_colored_polygon(pts, Color(0.35, 0.18, 0.55, 0.9) if k < 3 else (Color(0.95, 0.75, 0.3) if k == 3 else Color(0.35, 0.62, 0.30)))
	draw_string(font, Vector2(0, 52), "DIMHOLD", HORIZONTAL_ALIGNMENT_CENTER, 640, 28, Color(1, 0.92, 0.7))
	draw_string(font, Vector2(0, 72), T("Hold the light. Push back the dark.", "빛을 지켜라. 어둠을 밀어내라."), HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color(0.8, 0.8, 0.9))
	_draw_ui()
	draw_string(font, Vector2(0, 250), T("Prototype v0.2  -  first time? Start the tutorial.", "프로토타입 v0.2  -  처음이라면 튜토리얼부터 하세요."), HORIZONTAL_ALIGNMENT_CENTER, 640, 9, Color(0.7, 0.7, 0.8))


# ---------------- actions ----------------
func _on_card(k: int) -> void:
	if not _tut_allows("card"): _tut_blocked(); return
	mode = "card"; card_idx = k; build_name = ""
	msg = T("Click a yellow-outlined hex to place %s.", "노란 테두리 칸을 클릭해 %s 타일을 놓으세요.") % N(g.cards[k])
	_refresh()


func _on_build(n: String) -> void:
	if not _tut_allows("build_btn", n): _tut_blocked(); return
	mode = "build"; build_name = n; card_idx = -1
	msg = T("Click a lit empty hex to build %s.", "밝은 빈 칸을 클릭해 %s을(를) 지으세요.") % N(n)
	_refresh()


func _on_burst() -> void:
	if scr == "tutorial": return
	g.burst(selected); msg = T("Beacon Burst!", "봉화 정화!"); _refresh()


func _on_pyre() -> void:
	if scr == "tutorial": return
	g.pyre_fire(selected); msg = T("Pyre fire!", "화염 발사!"); _refresh()


func _on_seal() -> void:
	if scr == "tutorial": return
	var t: Array = g.seal_targets(selected)
	g.seal(selected, t[0]); msg = T("Rift sealed!", "균열 봉인 완료!"); _refresh()


func _toggle_codex() -> void:
	show_codex = not show_codex
	show_help = false
	_refresh()


func _toggle_help() -> void:
	show_help = not show_help
	queue_redraw()


func _hint() -> String:
	if g.over:
		return T("Stage over. Press R for a new game.", "끝났습니다. R 키로 새 게임.")
	if not placed_today:
		return T("1) Click a Card button, then a YELLOW-outlined hex to expand your land.", "1) 카드 버튼을 누르고 노란 테두리 칸을 클릭해 영토를 넓히세요.")
	if mode == "build":
		return T("Click a lit hex (not purple) to build. Esc cancels.", "밝은 내 칸(보라색 아님)을 클릭해 짓기. Esc로 취소.")
	if g.lp > 0 and g.M >= 2:
		return T("2) Click a build button (try lantern), then a lit hex near the purple. Then press Space.", "2) 건설 버튼(예: 목책) 후 빨간 삼각형이 뜬 내 칸 클릭. 끝나면 Space.")
	return T("3) Press Space to end the day.", "3) Space를 눌러 하루를 끝내세요.")


func _toggle_fc() -> void:
	show_fc = not show_fc; _refresh()


func _next_vset() -> void:
	vset_idx = (vset_idx + 1) % VSETS.size(); seed_n += 1; scr = "play"; _new_game()


func _end_day() -> void:
	if g.over: return
	if not _tut_allows("endday"): _tut_blocked(); return
	var before: int = g.lit_count()
	var prev_i: Array = g.inten.duplicate()
	var prev_l: Array = g.lit.duplicate()
	g.end_day()
	flash.clear()
	var nw := 0; var nb := 0; var nl := 0
	for i in range(GS.N):
		if prev_l[i] and not g.lit[i]:
			flash[i] = "lost"; nl += 1
		elif g.inten[i] > prev_i[i] and g.lit[i]:
			flash[i] = "worse"; nw += 1
		elif g.inten[i] < prev_i[i]:
			flash[i] = "better"; nb += 1
		elif g.inten[i] > prev_i[i]:
			flash[i] = "wild"
	flash_t = 2.5
	if g.over:
		msg = T("Stage over: %s", "스테이지 종료: %s") % [T("VICTORY", "승리") if g.won else T("DEFEAT", "패배")]
	else:
		g.dawn()
		placed_today = false; mode = ""; card_idx = -1; build_name = ""
		if scr == "tutorial": g.cards = ["meadow", "woodland", "hill"]
		msg = T("Night result: %d of your hexes worsened, %d improved, %d lost. (Day %d)", "밤의 결과: 내 칸 %d개 악화, %d개 개선, %d개 상실. (%d일차)") % [nw, nb, nl, g.day]
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
		var h := pick(e.position)
		var hb := _btn_at(e.position)
		if h != hover or hb != hover_btn:
			hover = h; hover_btn = hb; _build_ui(); queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if show_help or show_codex:
			if _btn_at(e.position) < 0:
				show_help = false; show_codex = false; _refresh(); return
		var bi := _btn_at(e.position)
		if bi >= 0:
			if btns[bi]["on"]: btns[bi]["cb"].call()
			return
		if scr == "menu": return
		var i := pick(e.position)
		if i < 0 or g.over: return
		if mode == "card" and card_idx >= 0 and not placed_today:
			if not _tut_allows("place"): _tut_blocked(); return
			if g.frontier().has(i):
				g.place_tile(i, card_idx); placed_today = true; mode = ""; card_idx = -1
				msg = T("Placed tile. Now build / use abilities.", "타일을 놓았습니다. 이제 건설하거나 능력을 쓰세요.")
			else:
				msg = T("Not a frontier hex (yellow outline).", "노란 테두리 칸이 아닙니다.")
		elif mode == "build" and build_name != "":
			if not _tut_allows("tile_build", i): _tut_blocked(); return
			if g.can_build(build_name, i):
				g.build(build_name, i); msg = T("Built %s.", "%s 건설 완료.") % N(build_name)
			else:
				msg = T("Cannot build %s there (cost/LP/blight/occupied).", "%s을(를) 여기에 지을 수 없습니다 (자원/행동력 부족, 오염, 이미 사용 중).") % N(build_name)
		elif scr != "tutorial":
			selected = i
		_refresh()
	elif e is InputEventKey and e.pressed:
		if scr == "menu":
			if e.keycode == KEY_T: _start_tutorial()
			elif e.keycode == KEY_L: _toggle_lang()
			return
		if scr == "tutorial" and TUT[tut]["next"] and (e.keycode == KEY_SPACE or e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER):
			_tut_next(); return
		if scr == "tutorial" and e.keycode != KEY_SPACE and e.keycode != KEY_ESCAPE and e.keycode != KEY_F: return
		match e.keycode:
			KEY_SPACE: _end_day()
			KEY_T: _start_tutorial()
			KEY_M: _open_menu()
			KEY_F: _toggle_fc()
			KEY_H: _toggle_help()
			KEY_C: _toggle_codex()
			KEY_R: _start_free()
			KEY_ESCAPE: mode = ""; card_idx = -1; build_name = ""; selected = -1; _refresh()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				vset_idx = e.keycode - KEY_1; seed_n += 1; scr = "play"; _new_game()


func _process(delta: float) -> void:
	if flash_t > 0.0:
		flash_t -= delta
		queue_redraw()
	elif scr == "tutorial":
		queue_redraw()


# ---------------- drawing ----------------
func _draw() -> void:
	if scr == "menu":
		_draw_menu()
		return
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
			var code: String = (KO_CODE.get(g.structs[i], "?") if ko else S_CODE.get(g.structs[i], "?"))
			var tc := Color(1, 1, 1) if not g.disabled(i) else Color(0.6, 0.6, 0.6)
			if g.dark.has(i): tc = Color(0.5, 0.4, 0.2)
			draw_string(font, p + Vector2(-8, 3), code, HORIZONTAL_ALIGNMENT_CENTER, 16, 9, tc)
		if g.inten[i] > 0:
			draw_string(font, p + Vector2(-3, 13), str(g.inten[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))
		if show_fc and g.lit[i] and not g.scar[i] and not g.rift.has(i):
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
	if show_fc: _draw_markers()
	if flash_t > 0.0:
		for i in flash.keys():
			var fcol := Color(1, 0.2, 0.2)
			if flash[i] == "better": fcol = Color(0.3, 1, 0.5)
			elif flash[i] == "lost": fcol = Color(1, 1, 1)
			elif flash[i] == "wild": fcol = Color(0.8, 0.4, 1)
			var pts := hex_pts(hex_pos(i), SIZE)
			pts.append(pts[0])
			draw_polyline(pts, Color(fcol.r, fcol.g, fcol.b, minf(1.0, flash_t)), 3.0)
	if scr == "tutorial": _draw_tutorial()
	_draw_ui()
	if show_codex: _draw_codex()
	_draw_tooltip()
	if show_help:
		var lines: Array = [
			T("HOW TO PLAY (click anywhere to close, H to reopen)", "플레이 방법 (아무 곳이나 클릭하면 닫힘, H로 다시 열기)"),
			"",
			T("GOAL: keep the center hex H alive for 12 days.", "목표: 12일 동안 가운데 '본'(본진)을 지키기."),
			T("Purple = blight. It spreads every night from the red Rifts.", "보라색 = 오염. 밤마다 빨간 테두리 '균열'에서 번집니다."),
			T("A number on a hex = blight strength (1-3). ^1 = gets worse tonight.", "칸의 숫자 = 오염 강도(1~3). 빨간 삼각형 = 오늘 밤 먹힐 위험."),
			T("G2 = defense of that hex. Blight spreads where pressure > defense.", "압 > 방 이면 위험. (압=오염 압력, 방=내 방어력)"),
			"",
			T("EACH DAY:", "하루 순서:"),
			T("1) Card button -> click a yellow-outlined hex: expand your land (once a day).", "1) 카드 버튼 -> 노란 테두리 칸 클릭: 영토 확장 (하루 1번)"),
			T("2) Build button -> click a lit hex: build. Lantern/Brazier give light (defense),", "2) 건설 버튼 -> 내 칸 클릭: 건설. 등불/화로=빛(방어),"),
			T("   Palisade/Rampart give walls. Put them where purple is coming.", "   목책/성벽=방벽. 보라색이 다가오는 쪽에 지으세요."),
			T("3) Press Space: night falls, blight spreads, next day.", "3) Space(하루 끝내기): 밤이 되어 오염이 번지고 다음 날로."),
			"",
			T("TIP: hover any button to see what it does. Codex (C) lists everything.", "팁: 버튼에 마우스를 올리면 설명이 나옵니다. 도감(C)에 전체 정리."),
			T("Beacon (Bc): select it, then press Burst to cleanse nearby blight.", "봉화(봉): 선택 후 '정화' 버튼으로 주변 오염 제거."),
		]
		draw_rect(Rect2(10, 40, 380, 280), Color(0.02, 0.02, 0.05, 0.93))
		var yy := 58.0
		for ln in lines:
			draw_string(font, Vector2(20, yy), ln, HORIZONTAL_ALIGNMENT_LEFT, 360, 9, Color(1, 0.95, 0.7) if yy < 60 else Color(0.92, 0.92, 0.95))
			yy += 14.5
	if g.over:
		draw_rect(Rect2(60, 150, 300, 40), Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(70, 177), T("%s - press R", "%s - R 키로 다시") % T("VICTORY", "승리") if g.won else T("%s - press R", "%s - R 키로 다시") % T("DEFEAT", "패배"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4))

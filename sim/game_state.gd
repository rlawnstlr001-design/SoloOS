extends RefCounted
# DIMHOLD rules v0.2 simulation. Pure logic, no nodes. Port of sim_proto/duskhold.py (parity-tested).

const R := 4
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const TERRAINS := ["meadow", "woodland", "hill", "marsh", "ruins", "crystal", "shore", "salt", "frost", "cinder"]
const TERRAIN_W := [25, 20, 15, 10, 5, 10, 5, 5, 3, 2]
const CLASSES := ["light", "flame", "ward"]
# name: [costM, costL, LP, hp, light(self,adj,r2), ward, class]
const STRUCT := {
	"lantern": [3, 1, 1, 3, [2, 1, 0], 0, "light"],
	"brazier": [4, 2, 1, 3, [2, 1, 0], 0, "flame"],
	"beacon": [6, 3, 2, 3, [3, 2, 1], 0, "light"],
	"palisade": [2, 0, 1, 2, [0, 0, 0], 1, "ward"],
	"rampart": [4, 1, 1, 4, [0, 0, 0], 2, "ward"],
	"pyre": [5, 2, 1, 3, [0, 0, 0], 0, "flame"],
	"sunwell": [10, 6, 2, 3, [1, 1, 0], 0, "light"],
	"camp": [4, 0, 1, 3, [0, 0, 0], 0, ""],
	"cottage": [5, 0, 1, 3, [0, 0, 0], 0, ""],
	"press": [4, 0, 1, 3, [0, 0, 0], 0, ""],
}
const BUILD_ORDER := ["lantern", "brazier", "beacon", "palisade", "rampart", "pyre", "sunwell", "camp", "cottage", "press"]
const LIGHT_STRUCTS := ["lantern", "brazier", "beacon", "sunwell"]

static var COORDS: Array = []
static var IDX: Dictionary = {}
static var N: int = 0
static var NEI: Array = []
static var DIST: Array = []
static var REACH2: Array = []
static var WITHIN3: Array = []
static var HEARTH: int = 0
static var RIFT_TILES: Array = []


static func _static_init() -> void:
	for q in range(-R, R + 1):
		for r in range(-R, R + 1):
			if abs(q + r) <= R:
				IDX[Vector2i(q, r)] = COORDS.size()
				COORDS.append(Vector2i(q, r))
	N = COORDS.size()
	for c in COORDS:
		var nb := []
		var rc := []
		for d in DIRS:
			var n: Vector2i = c + d
			if IDX.has(n): nb.append(IDX[n])
			var n2: Vector2i = c + d * 2
			if IDX.has(n2): rc.append(IDX[n2])
		NEI.append(nb)
		REACH2.append(rc)
	for a in COORDS:
		var row := []
		for b in COORDS:
			var dq: int = a.x - b.x
			var dr: int = a.y - b.y
			row.append(maxi(maxi(absi(dq), absi(dr)), absi(dq + dr)))
		DIST.append(row)
	for i in range(N):
		var w := []
		for j in range(N):
			if DIST[i][j] > 0 and DIST[i][j] <= 3: w.append(j)
		WITHIN3.append(w)
	HEARTH = IDX[Vector2i(0, 0)]
	RIFT_TILES = [IDX[Vector2i(4, -4)], IDX[Vector2i(0, 4)], IDX[Vector2i(-4, 0)]]


# ---------------- state ----------------
var seed_val: int = 0
var variants: Array = ["murk"]
var rule: String = "B"
var days: int = 12
var day: int = 0
var pf: Array = [0, 1, 2, 3]
var wild_cap: int = 3
var pmode: String = "max"
var seal_range: int = 2
var seal_goal: int = 2
var burst_cd: int = 4
var upkeep: bool = true
var far_w: float = 2.5
var terrain: Array = []
var lit: Array = []
var scar: Array = []
var inten: Array = []
var var_: Array = []   # variant name or ""
var structs: Array = []  # structure name or ""
var hp: Array = []
var was3: Array = []
var rift: Array = []
var dark: Array = []
var cd: Dictionary = {}
var resist: Dictionary = {"light": 0, "flame": 0, "ward": 0}
var window: Array = []  # array of {light, flame, ward}
var M: int = 10
var L: int = 8
var folk: int = 4
var lp: int = 0
var cards: Array = []
var over: bool = false
var won: bool = false
var early: bool = false
var sealed: int = 0
var territory_days: int = 0
var far_days: int = 0
var builds: int = 0
var placed: int = 0
var rng := RandomNumberGenerator.new()


func setup(p_seed: int, p_variants: Array, rifts: int = 3) -> void:
	seed_val = p_seed
	variants = p_variants.duplicate()
	rng.seed = p_seed
	terrain.resize(N); lit.resize(N); scar.resize(N); inten.resize(N); var_.resize(N)
	structs.resize(N); hp.resize(N); was3.resize(N); dark = []
	for i in range(N):
		terrain[i] = TERRAINS[_pick_terrain()]
		lit[i] = false; scar[i] = false; inten[i] = 0; var_[i] = ""; structs[i] = ""; hp[i] = 0; was3[i] = false
	lit[HEARTH] = true
	structs[HEARTH] = "hearth"
	for j in NEI[HEARTH]: lit[j] = true
	rift = []
	for k in range(rifts):
		var t: int = RIFT_TILES[k]
		inten[t] = 3
		var_[t] = variants[k % variants.size()]
		rift.append(t)
	M = 10; L = 8; folk = 4


func _pick_terrain() -> int:
	var total := 0
	for w in TERRAIN_W: total += w
	var x := rng.randi_range(0, total - 1)
	var acc := 0
	for i in range(TERRAIN_W.size()):
		acc += TERRAIN_W[i]
		if x < acc: return i
	return 0


func disabled(i: int) -> bool:
	return inten[i] >= 2


# ---------------- derived maps ----------------
func light_maps() -> Array:
	var li := []; var fl := []; var co := []
	li.resize(N); fl.resize(N); co.resize(N)
	li.fill(0); fl.fill(0); co.fill(0)
	for i in range(N):
		var s: String = structs[i]
		if s == "" or not lit[i] or disabled(i) or dark.has(i): continue
		var p: Array
		var cls: String
		if s == "hearth":
			p = [3, 2, 1]; cls = "core"
		else:
			p = STRUCT[s][4]; cls = STRUCT[s][6]
			if p[0] == 0 and p[1] == 0 and p[2] == 0: continue
		var rs: bool = resist.get(cls, 0) > 0
		var tgt: Array = li if cls == "light" else (fl if cls == "flame" else co)
		var dec := 1 if rs else 0
		var v0: int = maxi(0, p[0] - dec)
		var v1: int = maxi(0, p[1] - dec)
		var v2: int = maxi(0, p[2] - dec)
		if v0 > tgt[i]: tgt[i] = v0
		for j in NEI[i]:
			if v1 > tgt[j]: tgt[j] = v1
		if v2 > 0:
			for j in range(N):
				if DIST[i][j] == 2 and v2 > tgt[j]: tgt[j] = v2
	return [li, fl, co]


func guard_parts() -> Array:
	var lm := light_maps()
	var li: Array = lm[0]; var fl: Array = lm[1]; var co: Array = lm[2]
	var hollow := []
	hollow.resize(N); hollow.fill(false)
	for i in range(N):
		if var_[i] == "hollow" and inten[i] > 0:
			for j in range(N):
				if DIST[i][j] <= 2: hollow[j] = true
	var parts := []
	for i in range(N):
		var light: int = maxi(maxi(li[i], fl[i]), co[i])
		var lclass := "core"
		if light > 0 and li[i] == light: lclass = "light"
		elif light > 0 and fl[i] == light: lclass = "flame"
		var ward := 0
		var s: String = structs[i]
		if (s == "palisade" or s == "rampart") and not disabled(i):
			ward = maxi(0, STRUCT[s][5] - (1 if resist["ward"] > 0 else 0))
		var terr := 1 if terrain[i] == "hill" else 0
		parts.append([light, lclass, ward, terr, hollow[i]])
	return parts


func seed_targets() -> Dictionary:
	var out := {}
	for i in range(N):
		if var_[i] == "spore" and inten[i] >= 2:
			var h: int = (seed_val * 7919 + day * 104729 + i * 1299709) % 1000003
			var cand: Array = WITHIN3[i]
			out[i] = cand[h % cand.size()]
	return out


func pressure_maps() -> Array:
	var pl := []
	for i in range(N): pl.append([])
	var dom := []; var domv := []
	dom.resize(N); dom.fill(""); domv.resize(N); domv.fill(0)
	for s in range(N):
		var v: String = var_[s]
		if v == "" or inten[s] <= 0: continue
		var base: int = pf[inten[s]]
		for t in NEI[s]:
			if scar[t]: continue
			var tr: String = terrain[t]
			var m := 0
			if v == "murk" and tr == "marsh": m = 1
			elif v == "rime" and (tr == "frost" or tr == "cinder"): m = 1
			elif v == "spore":
				if tr == "meadow" or tr == "woodland": m = 1
				elif tr == "salt" or tr == "cinder": m = -1
			elif v == "rust": m = 1 if structs[t] != "" else -1
			elif v == "hollow": m = -1
			_add(pl, dom, domv, t, base + m, v)
		if v == "rime" and inten[s] >= 2:
			for t in REACH2[s]:
				if not scar[t]: _add(pl, dom, domv, t, base - 1, v)
	var st := seed_targets()
	for s in st.keys():
		var t: int = st[s]
		if not scar[t]: _add(pl, dom, domv, t, 2, "spore")
	var pr := []
	pr.resize(N); pr.fill(0)
	for t in range(N):
		var l: Array = pl[t]
		if l.is_empty(): continue
		if pmode == "sum":
			var sm := 0
			for x in l: sm += x
			pr[t] = sm
		elif pmode == "max":
			pr[t] = l.max() + (1 if l.size() >= 4 else 0)
		else:
			var sm2 := 0
			for x in l: sm2 += x
			pr[t] = (sm2 + 1) / 2
	return [pr, dom]


func _add(pl: Array, dom: Array, domv: Array, t: int, val: int, v: String) -> void:
	if val <= 0: return
	pl[t].append(val)
	if val > domv[t]:
		domv[t] = val
		dom[t] = v


func guards() -> Array:
	var parts := guard_parts()
	var g := []
	for i in range(N):
		var p: Array = parts[i]
		var v: String = var_[i]
		var tb: int = p[3] if (v == "murk" or v == "rime" or v == "") else 0
		g.append(maxi(0, p[0] + p[2] + tb - (1 if p[4] else 0)))
	return [g, parts]


func forecast() -> Array:
	var pm := pressure_maps()
	var pr: Array = pm[0]; var dom: Array = pm[1]
	var gp := guards()
	var g: Array = gp[0]; var parts: Array = gp[1]
	var new_i: Array = inten.duplicate()
	var new_v: Array = var_.duplicate()
	for i in range(N):
		if rift.has(i) or scar[i]: continue
		var I: int = inten[i]
		if pr[i] > g[i]:
			new_i[i] = mini(3 if lit[i] else wild_cap, I + 1)
			if I == 0: new_v[i] = dom[i]
		elif I > 0 and g[i] > I and ((pr[i] == 0) if rule == "A" else (pr[i] <= g[i])):
			new_i[i] = I - 1
			if new_i[i] == 0: new_v[i] = ""
	return [new_i, new_v, pr, g, parts]


func dusk() -> void:
	var f := forecast()
	var new_i: Array = f[0]; var new_v: Array = f[1]; var pr: Array = f[2]; var g: Array = f[3]; var parts: Array = f[4]
	var credit := {"light": 0.0, "flame": 0.0, "ward": 0.0}
	for i in range(N):
		if not lit[i] or scar[i]: continue
		var p: Array = parts[i]
		var light: int = p[0]; var lc: String = p[1]; var ward: int = p[2]
		var comp: int = light + ward
		if comp <= 0: continue
		if pr[i] > 0:
			var neg: int = mini(pr[i], g[i])
			if lc != "core": credit[lc] += float(neg) * float(light) / float(comp)
			credit["ward"] += float(neg) * float(ward) / float(comp)
		if new_i[i] < inten[i]:
			if lc != "core": credit[lc] += float(light) / float(comp)
			credit["ward"] += float(ward) / float(comp)
	inten = new_i
	var_ = new_v
	# brazier burn
	for i in range(N):
		if structs[i] == "brazier" and lit[i] and not disabled(i):
			for j in NEI[i]:
				if (var_[j] == "rime" or var_[j] == "spore") and inten[j] > 0 and not rift.has(j):
					var amt := 2 if var_[j] == "spore" else 1
					var a: int = mini(amt, inten[j])
					inten[j] -= a
					credit["flame"] += float(a)
					if inten[j] == 0: var_[j] = ""
	# rust damage
	for i in range(N):
		if var_[i] == "rust" and inten[i] >= 1 and structs[i] != "" and structs[i] != "hearth" and lit[i]:
			hp[i] -= 1
			if hp[i] <= 0: structs[i] = ""
	# hollow seed
	if day % 3 == 0 and variants.has("hollow"):
		var lits := []
		for i in range(N):
			if lit[i] and not scar[i]: lits.append(i)
		var lm := light_maps()
		if not lits.is_empty():
			var best: int = lits[0]
			var bk: int = maxi(maxi(lm[0][best], lm[1][best]), lm[2][best])
			for i in lits:
				var k: int = maxi(maxi(lm[0][i], lm[1][i]), lm[2][i])
				if k > bk or (k == bk and i < best):
					best = i; bk = k
			var cand := []
			for j in NEI[best]:
				if not scar[j] and not (lit[j] and structs[j] != ""): cand.append(j)
			if not cand.is_empty():
				var jj: int = cand[(seed_val + day * 31) % cand.size()]
				if inten[jj] == 0:
					inten[jj] = 1; var_[jj] = "hollow"
	# collapse
	for i in range(N):
		if lit[i] and inten[i] == 3 and was3[i] and not rift.has(i):
			scar[i] = true; lit[i] = false; inten[i] = 0; var_[i] = ""; structs[i] = ""
			if i == HEARTH:
				over = true; won = false
	# sunwell reclaim
	for i in range(N):
		if structs[i] == "sunwell" and lit[i] and not disabled(i):
			for j in range(N):
				if scar[j] and DIST[i][j] <= 2:
					scar[j] = false; lit[j] = true; terrain[j] = "cinder"
					break
	for i in range(N): was3[i] = (inten[i] == 3)
	# adaptation
	window.append(credit)
	while window.size() > 3: window.pop_front()
	for c in CLASSES: resist[c] = maxi(0, resist[c] - 1)
	var tot := {"light": 0.0, "flame": 0.0, "ward": 0.0}
	var alltot := 0.0
	for w in window:
		for c in CLASSES:
			tot[c] += w[c]
			alltot += w[c]
	if alltot > 0.0:
		for c in CLASSES:
			if tot[c] >= 6.0 and tot[c] / alltot > 0.6: resist[c] = 2


# ---------------- day flow ----------------
func dawn() -> void:
	day += 1
	for k in cd.keys(): cd[k] = maxi(0, cd[k] - 1)
	M += 2; L += 1
	var cottages := 0
	for i in range(N):
		var s: String = structs[i]
		if s == "" or not lit[i] or disabled(i): continue
		var frozen: bool = (var_[i] == "rime" and inten[i] >= 1)
		if s == "camp":
			var v := 2 if (terrain[i] == "woodland" or terrain[i] == "hill") else 1
			M += (v / 2) if frozen else v
		elif s == "press":
			var near_crystal := false
			for j in NEI[i]:
				if terrain[j] == "crystal": near_crystal = true
			var v2 := 2 if near_crystal else 1
			L += (v2 / 2) if frozen else v2
		elif s == "cottage":
			cottages += 1
	dark = []
	if upkeep:
		var lights := []
		for i in range(N):
			if LIGHT_STRUCTS.has(structs[i]) and lit[i] and not scar[i]: lights.append(i)
		var need: int = (lights.size() + 1) / 2
		if L >= need:
			L -= need
		else:
			var afford: int = L * 2
			L = 0
			lights.sort_custom(func(a, b): return DIST[HEARTH][a] < DIST[HEARTH][b])
			dark = lights.slice(afford)
	var cap: int = 4 + 2 * cottages
	if day % 3 == 0 and folk < cap: folk += 1
	lp = folk
	cards = []
	for k in range(3): cards.append(TERRAINS[_pick_terrain()])


func frontier() -> Array:
	var out := []
	for i in range(N):
		if lit[i] or scar[i]: continue
		for j in NEI[i]:
			if lit[j]:
				out.append(i); break
	return out


func place_tile(tile: int, card_idx: int) -> void:
	terrain[tile] = cards[card_idx]
	lit[tile] = true
	placed += 1


func can_build(name: String, i: int) -> bool:
	var c: Array = STRUCT[name]
	if not lit[i] or scar[i] or structs[i] != "" or inten[i] >= 2: return false
	return M >= c[0] and L >= c[1] and lp >= c[2]


func build(name: String, i: int) -> void:
	var c: Array = STRUCT[name]
	M -= c[0]; L -= c[1]; lp -= c[2]
	structs[i] = name; hp[i] = c[3]
	builds += 1


func can_burst(i: int) -> bool:
	return structs[i] == "beacon" and lit[i] and not disabled(i) and cd.get("b%d" % i, 0) == 0 and L >= 3 and lp >= 2


func burst(i: int) -> void:
	L -= 3; lp -= 2; cd["b%d" % i] = burst_cd
	for j in range(N):
		if DIST[i][j] <= 2 and inten[j] > 0 and not rift.has(j):
			inten[j] -= 1
			if inten[j] == 0: var_[j] = ""


func can_pyre(i: int) -> bool:
	return structs[i] == "pyre" and lit[i] and not disabled(i) and cd.get("p%d" % i, 0) == 0 and L >= 3 and lp >= 1


func pyre_fire(i: int) -> void:
	L -= 3; lp -= 1; cd["p%d" % i] = 3
	for j in range(N):
		if DIST[i][j] <= 1 and inten[j] > 0 and inten[j] <= 2 and not rift.has(j):
			inten[j] = 0; var_[j] = ""


func seal_targets(i: int) -> Array:
	if structs[i] != "sunwell" or not lit[i] or disabled(i) or L < 5 or lp < 2: return []
	var out := []
	for r in rift:
		if DIST[i][r] <= seal_range: out.append(r)
	return out


func seal(i: int, r: int) -> void:
	L -= 5; lp -= 2
	rift.erase(r); inten[r] = 0; var_[r] = ""; sealed += 1
	if sealed >= mini(seal_goal, sealed + rift.size()):
		over = true; won = true; early = true


func end_day() -> void:
	dusk()
	var litc := 0
	var farc := 0
	for i in range(N):
		if lit[i] and not scar[i]:
			litc += 1
			if DIST[HEARTH][i] >= 3: farc += 1
	territory_days += litc
	far_days += farc
	if over: return
	if day >= days:
		over = true; won = true


func lit_count() -> int:
	var c := 0
	for i in range(N):
		if lit[i] and not scar[i]: c += 1
	return c


func ember() -> float:
	return day * 2.0 + territory_days / 4.0 + 3.0 * lit_count() + 25.0 * sealed + (30.0 if won else 0.0) + (20.0 if early else 0.0) + far_w * far_days


# ---------------- snapshot (for parity tests) ----------------
func load_snapshot(d: Dictionary) -> void:
	seed_val = int(d["seed"]); day = int(d["day"]); variants = d["variants"]
	pf = d["pf"]; wild_cap = int(d["wild_cap"]); rule = d["rule"]; pmode = d["pmode"]
	terrain = d["terrain"].duplicate(); lit = d["lit"].duplicate(); scar = d["scar"].duplicate()
	inten = []; for x in d["inten"]: inten.append(int(x))
	var_ = []; for x in d["var"]: var_.append("" if x == null else x)
	structs = []; for x in d["struct"]: structs.append("" if x == null else x)
	hp = []; for x in d["hp"]: hp.append(int(x))
	was3 = d["was3"].duplicate()
	rift = []; for x in d["rift"]: rift.append(int(x))
	dark = []; for x in d["dark"]: dark.append(int(x))
	resist = {"light": int(d["resist"]["light"]), "flame": int(d["resist"]["flame"]), "ward": int(d["resist"]["ward"])}
	window = []
	for w in d["window"]: window.append({"light": float(w["light"]), "flame": float(w["flame"]), "ward": float(w["ward"])})
	over = false; won = false

"""DIMHOLD rules prototype (headless). Implements docs/design/01_rules.md.
Run: python3 -I sim_proto/run_experiments.py
"""
import random, itertools
from collections import deque

R = 4
DIRS = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]
COORDS = [(q, r) for q in range(-R, R + 1) for r in range(-R, R + 1) if abs(q + r) <= R]
IDX = {c: i for i, c in enumerate(COORDS)}
N = len(COORDS)


def hdist(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return max(abs(dq), abs(dr), abs(dq + dr))


NEI = [[IDX[(q + dq, r + dr)] for dq, dr in DIRS if (q + dq, r + dr) in IDX] for q, r in COORDS]
DIST = [[hdist(a, b) for b in COORDS] for a in COORDS]
REACH2 = []  # tiles at distance 2 along a straight line
for (q, r) in COORDS:
    REACH2.append([IDX[(q + 2 * dq, r + 2 * dr)] for dq, dr in DIRS if (q + 2 * dq, r + 2 * dr) in IDX])
WITHIN3 = [[j for j in range(N) if 0 < DIST[i][j] <= 3] for i in range(N)]
HEARTH = IDX[(0, 0)]
RIFT_TILES = [IDX[(4, -4)], IDX[(0, 4)], IDX[(-4, 0)]]

TERRAINS = ['meadow', 'woodland', 'hill', 'marsh', 'ruins', 'crystal', 'shore', 'salt', 'frost', 'cinder']
TERRAIN_W = [25, 20, 15, 10, 5, 10, 5, 5, 3, 2]

# name: (cost M, cost L, LP, hp, light(self,adj,r2), ward, class)
BASE_STRUCT = {
    'lantern': (3, 1, 1, 3, (2, 1, 0), 0, 'light'),
    'brazier': (4, 2, 1, 3, (2, 1, 0), 0, 'flame'),
    'beacon': (6, 3, 2, 3, (3, 2, 1), 0, 'light'),
    'palisade': (2, 0, 1, 2, (0, 0, 0), 1, 'ward'),
    'rampart': (4, 1, 1, 4, (0, 0, 0), 2, 'ward'),
    'camp': (4, 0, 1, 3, (0, 0, 0), 0, None),
    'cottage': (5, 0, 1, 3, (0, 0, 0), 0, None),
    'press': (4, 0, 1, 3, (0, 0, 0), 0, None),
}
STRUCT = dict(BASE_STRUCT)
CLASSES = ('light', 'flame', 'ward')


class Game:
    def __init__(self, seed, variants=('murk',), rule='A', rifts=3, days=12, lp_bonus=0, pf=(0, 1, 2, 3), wild_cap=3, pmode='sum'):
        self.rng = random.Random(seed)
        self.seed = seed
        self.variants = list(variants)
        self.pf = pf
        self.pmode = pmode
        self.wild_cap = wild_cap
        self.rule = rule  # A: doc rule (cleanse needs pressure 0), B: relaxed (pressure<=guard)
        self.days = days
        self.day = 0
        self.terrain = ['meadow'] * N
        self.lit = [False] * N
        self.scar = [False] * N
        self.inten = [0] * N
        self.var = [None] * N
        self.struct = [None] * N
        self.hp = [0] * N
        self.was3 = [False] * N
        self.lit[HEARTH] = True
        self.struct[HEARTH] = 'hearth'
        for j in NEI[HEARTH]:
            self.lit[j] = True
        for k, t in enumerate(RIFT_TILES[:rifts]):
            self.inten[t] = 3
            self.var[t] = self.variants[k % len(self.variants)]
        self.rift = set(RIFT_TILES[:rifts])
        for i in range(N):
            self.terrain[i] = self.rng.choices(TERRAINS, TERRAIN_W)[0]
        self.M, self.L, self.folk = 10, 8, 4
        self.lp_bonus = lp_bonus
        self.lp = 0
        self.cards = []
        self.window = deque(maxlen=3)
        self.resist = {c: 0 for c in CLASSES}
        self.over = False
        self.won = False
        self.stats = dict(builds=0, tiles_placed=0)

    def clone(self):
        c = Game.__new__(Game)
        c.__dict__.update(self.__dict__)
        for k in ('terrain', 'lit', 'scar', 'inten', 'var', 'struct', 'hp', 'was3'):
            setattr(c, k, list(getattr(self, k)))
        c.window = deque(self.window, maxlen=3)
        c.resist = dict(self.resist)
        c.stats = dict(self.stats)
        c.rng = random.Random(0)
        return c

    # ---------- derived maps ----------
    def disabled(self, i):
        return self.inten[i] >= 2

    def light_maps(self):
        li = [0] * N
        fl = [0] * N
        co = [0] * N
        for i in range(N):
            s = self.struct[i]
            if s is None or not self.lit[i] or self.disabled(i):
                continue
            if s == 'hearth':
                p, cls = (3, 2, 1), 'core'
            else:
                p, cls = STRUCT[s][4], STRUCT[s][6]
                if p == (0, 0, 0):
                    continue
            rs = self.resist.get(cls, 0) > 0
            tgt = li if cls == 'light' else (fl if cls == 'flame' else co)
            v0 = max(0, p[0] - (1 if rs else 0)); v1 = max(0, p[1] - (1 if rs else 0)); v2 = max(0, p[2] - (1 if rs else 0))
            if v0 > tgt[i]: tgt[i] = v0
            for j in NEI[i]:
                if v1 > tgt[j]: tgt[j] = v1
            if v2:
                for j in range(N):
                    if DIST[i][j] == 2 and v2 > tgt[j]: tgt[j] = v2
        return li, fl, co

    def guard_parts(self):
        li, fl, co = self.light_maps()
        hollow = [False] * N
        for i in range(N):
            if self.var[i] == 'hollow' and self.inten[i] > 0:
                for j in range(N):
                    if DIST[i][j] <= 2: hollow[j] = True
        parts = []
        for i in range(N):
            light = max(li[i], fl[i], co[i])
            if light > 0 and li[i] == light: lclass = 'light'
            elif light > 0 and fl[i] == light: lclass = 'flame'
            else: lclass = 'core'
            ward = 0
            s = self.struct[i]
            if s in ('palisade', 'rampart') and not self.disabled(i):
                ward = max(0, STRUCT[s][5] - (1 if self.resist['ward'] > 0 else 0))
            terr = 1 if self.terrain[i] == 'hill' else 0
            parts.append((light, lclass, ward, terr, hollow[i]))
        return parts

    def seed_targets(self):
        out = {}
        for i in range(N):
            if self.var[i] == 'spore' and self.inten[i] >= 2:
                h = (self.seed * 7919 + self.day * 104729 + i * 1299709) % 1000003
                cand = WITHIN3[i]
                out[i] = cand[h % len(cand)]
        return out

    def pressure_maps(self):
        pr = [0] * N
        pl = [[] for _ in range(N)]
        dom = [None] * N
        domv = [0] * N

        def add(t, val, v):
            if val <= 0: return
            pl[t].append(val)
            if val > domv[t]:
                domv[t] = val; dom[t] = v
        for s in range(N):
            v = self.var[s]
            if v is None or self.inten[s] <= 0:
                continue
            I = self.pf[self.inten[s]]
            for t in NEI[s]:
                if self.scar[t]: continue
                tr = self.terrain[t]
                m = 0
                if v == 'murk' and tr == 'marsh': m = 1
                elif v == 'rime' and tr in ('frost', 'cinder'): m = 1
                elif v == 'spore': m = 1 if tr in ('meadow', 'woodland') else (-1 if tr in ('salt', 'cinder') else 0)
                elif v == 'rust': m = 1 if self.struct[t] is not None else -1
                elif v == 'hollow': m = -1
                add(t, I + m, v)
            if v == 'rime' and self.inten[s] >= 2:
                for t in REACH2[s]:
                    if not self.scar[t]: add(t, I - 1, v)
        for s, t in self.seed_targets().items():
            if not self.scar[t]: add(t, 2, 'spore')
        for t in range(N):
            l = pl[t]
            if not l: continue
            if self.pmode == 'sum': pr[t] = sum(l)
            elif self.pmode == 'max': pr[t] = max(l) + (1 if len(l) >= 4 else 0)
            else: pr[t] = (sum(l) + 1) // 2
        return pr, dom

    def guards(self):
        parts = self.guard_parts()
        g = []
        for i, (light, lc, ward, terr, hol) in enumerate(parts):
            v = self.var[i]
            tb = terr if v in ('murk', 'rime') or v is None else 0
            g.append(max(0, light + ward + tb - (1 if hol else 0)))
        return g, parts

    # ---------- forecast / dusk ----------
    def forecast(self):
        pr, dom = self.pressure_maps()
        g, parts = self.guards()
        new = list(self.inten)
        newv = list(self.var)
        for i in range(N):
            if i in self.rift or self.scar[i]:
                continue
            I = self.inten[i]
            if pr[i] > g[i]:
                new[i] = min(3 if self.lit[i] else self.wild_cap, I + 1)
                if I == 0: newv[i] = dom[i]
            elif I > 0 and g[i] > I and (pr[i] == 0 if self.rule == 'A' else pr[i] <= g[i]):
                new[i] = I - 1
                if new[i] == 0: newv[i] = None
        return new, newv, pr, g, parts

    def dusk(self):
        new, newv, pr, g, parts = self.forecast()
        credit = {c: 0.0 for c in CLASSES}
        for i in range(N):
            if not self.lit[i] or self.scar[i]: continue
            light, lc, ward, terr, hol = parts[i]
            comp = light + ward
            if comp <= 0: continue
            if pr[i] > 0:
                neg = min(pr[i], g[i])
                if lc != 'core': credit[lc] += neg * light / comp
                credit['ward'] += neg * ward / comp
            if new[i] < self.inten[i]:
                if lc != 'core': credit[lc] += light / comp
                credit['ward'] += ward / comp
        self.inten, self.var = new, newv
        # brazier burn
        for i in range(N):
            if self.struct[i] == 'brazier' and self.lit[i] and not self.disabled(i):
                for j in NEI[i]:
                    if self.var[j] in ('rime', 'spore') and self.inten[j] > 0 and j not in self.rift:
                        amt = 2 if self.var[j] == 'spore' else 1
                        a = min(amt, self.inten[j]); self.inten[j] -= a; credit['flame'] += a
                        if self.inten[j] == 0: self.var[j] = None
        # rust damage
        for i in range(N):
            if self.var[i] == 'rust' and self.inten[i] >= 1 and self.struct[i] not in (None, 'hearth') and self.lit[i]:
                self.hp[i] -= 1
                if self.hp[i] <= 0: self.struct[i] = None
        # hollow seed
        if self.day % 3 == 0 and 'hollow' in self.variants:
            lits = [i for i in range(N) if self.lit[i] and not self.scar[i]]
            li, fl, co = self.light_maps()
            if lits:
                best = max(lits, key=lambda i: (max(li[i], fl[i], co[i]), -i))
                cand = [j for j in NEI[best] if not self.scar[j] and not (self.lit[j] and self.struct[j])]
                if cand:
                    j = cand[(self.seed + self.day * 31) % len(cand)]
                    if self.inten[j] == 0: self.inten[j] = 1; self.var[j] = 'hollow'
        # collapse
        for i in range(N):
            if self.lit[i] and self.inten[i] == 3 and self.was3[i] and i not in self.rift:
                self.scar[i] = True; self.lit[i] = False; self.inten[i] = 0; self.var[i] = None
                self.struct[i] = None
                if i == HEARTH:
                    self.over = True; self.won = False
        for i in range(N): self.was3[i] = (self.inten[i] == 3)
        # adaptation
        self.window.append(credit)
        for c in CLASSES: self.resist[c] = max(0, self.resist[c] - 1)
        tot = {c: sum(w[c] for w in self.window) for c in CLASSES}
        alltot = sum(tot.values())
        if alltot > 0:
            for c in CLASSES:
                if tot[c] >= 6 and tot[c] / alltot > 0.6: self.resist[c] = 2

    # ---------- day ----------
    def dawn(self):
        self.day += 1
        self.M += 2; self.L += 1
        cottages = 0
        for i in range(N):
            s = self.struct[i]
            if s is None or not self.lit[i] or self.disabled(i): continue
            frozen = (self.var[i] == 'rime' and self.inten[i] >= 1)
            if s == 'camp':
                v = 2 if self.terrain[i] in ('woodland', 'hill') else 1
                self.M += v // 2 if frozen else v
            elif s == 'press':
                v = 2 if any(self.terrain[j] == 'crystal' for j in NEI[i]) else 1
                self.L += v // 2 if frozen else v
            elif s == 'cottage':
                cottages += 1
        cap = 4 + 2 * cottages
        if self.day % 3 == 0 and self.folk < cap: self.folk += 1
        self.lp = self.folk + self.lp_bonus
        self.cards = self.rng.choices(TERRAINS, TERRAIN_W, k=3)

    def frontier(self):
        out = []
        for i in range(N):
            if self.lit[i] or self.scar[i]: continue
            if any(self.lit[j] for j in NEI[i]): out.append(i)
        return out

    def place_tile(self, tile, card_idx):
        self.terrain[tile] = self.cards[card_idx]
        self.lit[tile] = True
        self.stats['tiles_placed'] += 1

    def can_build(self, name, i):
        c = STRUCT[name]
        if not self.lit[i] or self.scar[i] or self.struct[i] is not None or self.inten[i] >= 2: return False
        return self.M >= c[0] and self.L >= c[1] and self.lp >= c[2]

    def build(self, name, i):
        c = STRUCT[name]
        self.M -= c[0]; self.L -= c[1]; self.lp -= c[2]
        self.struct[i] = name; self.hp[i] = c[3]
        self.stats['builds'] += 1

    def end_day(self):
        self.dusk()
        if self.over: return
        if self.day >= self.days:
            self.over = True; self.won = True

    # ---------- metrics ----------
    def loss(self):
        new, _, _, _, _ = self.forecast()
        tot = 0.0
        for i in range(N):
            if self.lit[i] and not self.scar[i]:
                p = new[i]
                tot += p * p + (60 * p if i == HEARTH else 0) + (6 if (p == 3 and self.was3[i]) else 0)
        return tot

    def summary(self):
        lit = sum(1 for i in range(N) if self.lit[i] and not self.scar[i])
        defs = sum(1 for i in range(N) if self.lit[i] and self.struct[i] in ('lantern', 'brazier', 'beacon', 'palisade', 'rampart'))
        blight = sum(1 for i in range(N) if self.inten[i] > 0)
        return dict(M=self.M, L=self.L, builds=self.stats['builds'], placed=self.stats['tiles_placed'], won=self.won, day=self.day, lit=lit, scars=sum(self.scar), defense=defs, blight=blight, folk=self.folk)

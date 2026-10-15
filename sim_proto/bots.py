import random
from duskhold import *

PREF = {'hill': 6, 'woodland': 5, 'crystal': 4, 'meadow': 3, 'salt': 2, 'ruins': 2, 'shore': 1, 'marsh': 1, 'frost': 0, 'cinder': 0}


def blight_dist(g):
    srcs = [i for i in range(N) if g.inten[i] > 0]
    if not srcs: return [99] * N
    return [min(DIST[i][s] for s in srcs) for i in range(N)]


def do_expand(g, rng, style='safe'):
    fr = g.frontier()
    if not fr: return
    bd = blight_dist(g)
    best = None
    for i in fr:
        nl = sum(1 for j in NEI[i] if g.lit[j])
        if style == 'safe':
            sc = nl * 2 - (6 if bd[i] <= 1 else 0) + rng.random()
        else:  # greedy: reach toward blight for yield
            sc = (6 - bd[i]) + rng.random()
        if best is None or sc > best[0]: best = (sc, i)
    ci = max(range(3), key=lambda k: PREF[g.cards[k]])
    g.place_tile(best[1], ci)


def econ_target(g):
    cnt = {}
    for i in range(N):
        if g.struct[i] and g.struct[i] != 'hearth': cnt[g.struct[i]] = cnt.get(g.struct[i], 0) + 1
    return cnt


def threat_tiles(g):
    new, _, pr, gd, parts = g.forecast()
    out = []
    for i in range(N):
        if g.lit[i] and not g.scar[i] and g.struct[i] is None and g.inten[i] < 2:
            if new[i] > g.inten[i] or pr[i] > 0:
                out.append((pr[i] - gd[i], i))
    out.sort(reverse=True)
    return [i for _, i in out]


def empty_lit(g):
    return [i for i in range(N) if g.lit[i] and not g.scar[i] and g.struct[i] is None and g.inten[i] < 2]


def build_eco(g, rng):
    cnt = econ_target(g)
    order = []
    if cnt.get('camp', 0) < 2: order.append('camp')
    if cnt.get('cottage', 0) < 1: order.append('cottage')
    if cnt.get('press', 0) < 1: order.append('press')
    if cnt.get('camp', 0) < 4: order.append('camp')
    for name in order:
        spots = [i for i in empty_lit(g) if i != HEARTH]
        if not spots: return False
        # keep economy tiles away from the front
        bd = blight_dist(g)
        spots.sort(key=lambda i: (-bd[i], rng.random()))
        if name == 'camp':
            spots.sort(key=lambda i: (-(g.terrain[i] in ('woodland', 'hill')), -bd[i]))
        for i in spots[:1]:
            if g.can_build(name, i):
                g.build(name, i); return True
        return False
    return False


def policy_random(g, rng):
    do_expand(g, rng)
    names = ['lantern', 'brazier', 'palisade', 'rampart', 'camp', 'cottage', 'press', 'beacon']
    tries = 0
    while g.lp > 0 and tries < 30:
        tries += 1
        n = rng.choice(names); spots = empty_lit(g)
        if not spots: break
        i = rng.choice(spots)
        if g.can_build(n, i): g.build(n, i)


def _class_bot(defs):
    def pol(g, rng):
        do_expand(g, rng)
        tries = 0
        while g.lp > 0 and tries < 40:
            tries += 1
            if g.day <= 2 and build_eco(g, rng): continue
            th = threat_tiles(g)
            if th:
                i = th[0]
                for n in defs:
                    if g.can_build(n, i): g.build(n, i); break
                else:
                    if not build_eco(g, rng): break
                continue
            if not build_eco(g, rng):
                spots = [i for i in empty_lit(g) if i != HEARTH]
                bd = blight_dist(g); spots.sort(key=lambda i: bd[i])
                done = False
                for i in spots[:1]:
                    for n in defs:
                        if g.can_build(n, i): g.build(n, i); done = True; break
                if not done: break
    return pol


policy_lantern = _class_bot(['lantern'])
policy_wall = _class_bot(['rampart', 'palisade'])
policy_flame = _class_bot(['brazier'])


def horizon_loss(g, H=3):
    c = g.clone(); tot = 0.0
    for h in range(H):
        c.day += 1
        c.dusk()
        w = 1.0 if h == 0 else 0.7
        for i in range(N):
            if c.lit[i] and not c.scar[i]:
                p = c.inten[i]
                tot += w * (p * p + (60 * p if i == HEARTH else 0))
        if c.over and not c.won: tot += 5000
        c.day -= 0
    return tot


def policy_mixed(g, rng):
    do_expand(g, rng)
    tries = 0
    while g.lp > 0 and tries < 10:
        tries += 1
        if g.day <= 2 and build_eco(g, rng): continue
        bd = blight_dist(g)
        cands = sorted([i for i in empty_lit(g) if i != HEARTH], key=lambda i: bd[i])[:10]
        base = horizon_loss(g)
        best = None
        for i in cands:
            for n in ('lantern', 'brazier', 'palisade', 'rampart', 'beacon'):
                if not g.can_build(n, i): continue
                c = STRUCT[n]
                g.struct[i] = n; g.hp[i] = c[3]
                after = horizon_loss(g)
                g.struct[i] = None
                gain = (base - after) / (c[0] + 1.5 * c[1] + 0.5)
                if gain > 0 and (best is None or gain > best[0]): best = (gain, n, i)
        if best and best[0] > 0.2:
            g.build(best[1], best[2]); continue
        if g.day < 10 and build_eco(g, rng): continue
        break


POLICIES = {'random': policy_random, 'lantern_only': policy_lantern, 'wall_only': policy_wall,
            'flame_only': policy_flame, 'mixed': policy_mixed}


def play(seed, policy, variants, rule='A', rifts=3, pf=(0, 1, 2, 3), wild_cap=3, pmode='sum'):
    g = Game(seed, variants, rule, rifts, pf=pf, wild_cap=wild_cap, pmode=pmode)
    rng = random.Random(seed * 13 + 7)
    pol = POLICIES[policy]
    while not g.over:
        g.dawn()
        pol(g, rng)
        g.end_day()
    return g.summary()

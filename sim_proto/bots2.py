import random
from duskhold import *
from bots import blight_dist, empty_lit, build_eco, horizon_loss, PREF


def expand(g, rng, mode):
    if mode == 'none': return
    fr = g.frontier()
    if not fr: return
    bd = blight_dist(g)
    if mode == 'rift' and g.rift:
        tgt = min(g.rift, key=lambda r: min(DIST[r][i] for i in range(N) if g.lit[i]))
    best = None
    for i in fr:
        nl = sum(1 for j in NEI[i] if g.lit[j])
        if mode == 'safe':
            sc = nl * 2 - (6 if bd[i] <= 1 else 0) + rng.random()
        else:
            sc = -DIST[i][tgt] * 3 + nl + rng.random() - (4 if g.inten[i] >= 2 else 0)
        if best is None or sc > best[0]: best = (sc, i)
    ci = max(range(3), key=lambda k: PREF[g.cards[k]])
    g.place_tile(best[1], ci)


def plan(g, rng, actives, rush):
    tries = 0
    while g.lp > 0 and tries < 10 and not g.over:
        tries += 1
        if g.day <= 2 and build_eco(g, rng): continue
        if rush and g.rift:
            # try sealing, else sunwell near a rift
            done = False
            for i in range(N):
                for r in g.seal_targets(i):
                    g.seal(i, r); done = True; break
                if done: break
            if done: continue
            near = [i for i in empty_lit(g) if any(DIST[i][r] <= g.seal_range for r in g.rift)]
            if near and g.can_build('sunwell', near[0]):
                g.build('sunwell', near[0]); continue
        bd = blight_dist(g)
        cands = sorted([i for i in empty_lit(g) if i != HEARTH], key=lambda i: bd[i])[:10]
        base = horizon_loss(g)
        best = None
        names = ['lantern', 'brazier', 'palisade', 'rampart', 'beacon'] + (['pyre'] if actives else [])
        for i in cands:
            for n in names:
                if not g.can_build(n, i): continue
                c = STRUCT[n]
                g.struct[i] = n; g.hp[i] = c[3]
                after = horizon_loss(g)
                g.struct[i] = None
                gain = (base - after) / (c[0] + 1.5 * c[1] + 0.5)
                if gain > 0 and (best is None or gain > best[0]): best = (gain, 'b', n, i)
        if actives:
            for i in range(N):
                if g.can_burst(i):
                    c = g.clone(); c.burst(i)
                    gain = (base - horizon_loss(c)) / 5.0
                    if gain > 0 and (best is None or gain > best[0]): best = (gain, 'burst', None, i)
                if g.can_pyre(i):
                    c = g.clone(); c.pyre_fire(i)
                    gain = (base - horizon_loss(c)) / 8.0
                    if gain > 0 and (best is None or gain > best[0]): best = (gain, 'pyre', None, i)
        if best and best[0] > 0.2:
            if best[1] == 'b': g.build(best[2], best[3])
            elif best[1] == 'burst': g.burst(best[3])
            else: g.pyre_fire(best[3])
            continue
        if g.day < 10 and build_eco(g, rng): continue
        break


def make(expand_mode, actives, rush):
    def pol(g, rng):
        expand(g, rng, expand_mode)
        plan(g, rng, actives, rush)
    return pol


def play2(seed, variants, cfg, regime):
    g = Game(seed, variants, 'B', 3, pmode='max', wild_cap=3, seal_range=cfg.get('seal_range', 1), base_m=cfg.get('base_m', 2), base_l=cfg.get('base_l', 1))
    rng = random.Random(seed * 13 + 7)
    pol = make(cfg['expand'], cfg['actives'], cfg['rush'])
    while not g.over:
        g.dawn(); pol(g, rng)
        if g.over: break
        g.end_day()
    return g.summary()

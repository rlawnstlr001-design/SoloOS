"""Export state snapshots + expected post-dusk state for GDScript parity test."""
import json, random, sys
from duskhold import *
from bots2 import make

VSETS = [('murk',), ('murk', 'spore'), ('rime', 'spore'), ('rust', 'murk'), ('rime', 'hollow'), ('murk', 'rime', 'spore', 'rust', 'hollow')]


def ser(g):
    return dict(seed=g.seed, day=g.day, variants=list(g.variants), pf=list(g.pf), wild_cap=g.wild_cap, rule=g.rule, pmode=g.pmode,
                terrain=list(g.terrain), lit=list(g.lit), scar=list(g.scar), inten=list(g.inten), var=list(g.var), struct=list(g.struct),
                hp=list(g.hp), was3=list(g.was3), rift=sorted(g.rift), dark=sorted(g.dark), resist=dict(g.resist),
                window=[dict(w) for w in g.window], over=g.over, won=g.won)


def random_all(g, rng):
    g.M += 40; g.L += 30; g.lp += 6
    names = ['lantern', 'brazier', 'beacon', 'palisade', 'rampart', 'pyre', 'sunwell', 'camp', 'cottage', 'press']
    for _ in range(10):
        spots = [i for i in range(N) if g.lit[i] and not g.scar[i] and g.struct[i] is None and g.inten[i] < 2]
        if not spots: break
        n = rng.choice(names); i = rng.choice(spots)
        if g.can_build(n, i): g.build(n, i)
    fr = g.frontier()
    if fr: g.place_tile(rng.choice(fr), 0)


def main(out):
    cases = []
    for vi, v in enumerate(VSETS):
        for s in range(3):
            for mode in ('planC', 'random'):
                g = Game(7000 + vi * 10 + s, v, 'B', 3, pmode='max', wild_cap=3, upkeep=True, seal_goal=2)
                rng = random.Random(s * 5 + vi)
                pol = make('safe', True, False) if mode == 'planC' else None
                while not g.over:
                    g.dawn()
                    if pol: pol(g, rng)
                    else: random_all(g, rng)
                    if g.day in (2, 4, 6, 8, 10, 12) or g.day % 5 == 0:
                        c = g.clone(); pre = ser(g); c.dusk()
                        cases.append(dict(pre=pre, post=ser(c), name='%s/%s/%d/day%d' % ('+'.join(v), mode, s, g.day)))
                    g.end_day()
    json.dump(cases, open(out, 'w'))
    print(len(cases), 'cases ->', out)


if __name__ == '__main__':
    main(sys.argv[1])

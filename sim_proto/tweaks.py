import sys, copy, time
from multiprocessing import Pool
import duskhold, bots
from run_experiments import VSETS, REGIMES
from bots import *

TWEAKS = {
 'T0 baseline': {},
 'T1 lantern(2M,r2)': {'lantern': (2, 1, 1, 3, (2, 1, 1), 0, 'light')},
 'T2 brazier(5M,3L)': {'brazier': (5, 3, 1, 3, (2, 1, 0), 0, 'flame')},
 'T3 both': {'lantern': (2, 1, 1, 3, (2, 1, 1), 0, 'light'), 'brazier': (5, 3, 1, 3, (2, 1, 0), 0, 'flame')},
}
def job(a):
    tw, vname, pol, seed, rule = a
    duskhold.STRUCT.clear(); duskhold.STRUCT.update(duskhold.BASE_STRUCT)
    for k, v in TWEAKS[tw].items(): duskhold.STRUCT[k] = v
    r = play(seed, pol, VSETS[vname], rule=rule, **REGIMES['R1 max,wild2'])
    return (tw, vname, pol, r)
if __name__ == '__main__':
    rule = sys.argv[1] if len(sys.argv) > 1 else 'B'
    jobs = [(tw, v, pol, 2000 + s, rule) for tw in TWEAKS for v in VSETS for pol in POLICIES for s in range(30 if pol == 'mixed' else 60)]
    t = time.time()
    with Pool(4) as p: res = p.map(job, jobs, chunksize=8)
    agg = {}
    for tw, v, pol, r in res: agg.setdefault((tw, pol), {}).setdefault(v, []).append(r['won'])
    print('rule', rule, 'avg win% across 6 variant sets  |  per-variant for [lantern, wall, flame, mixed]')
    for tw in TWEAKS:
        avg = {pol: 100 * sum(sum(x) / len(x) for x in agg[(tw, pol)].values()) / len(VSETS) for pol in POLICIES}
        print('%-20s' % tw, ' '.join('%s %3.0f' % (p[:6], avg[p]) for p in POLICIES))
        for v in VSETS:
            print('    %-12s' % v, ' '.join('%s %3.0f' % (p[:6], 100 * sum(agg[(tw, p)][v]) / len(agg[(tw, p)][v])) for p in ('lantern_only', 'wall_only', 'flame_only', 'mixed')))
    print('time %.0fs' % (time.time() - t))

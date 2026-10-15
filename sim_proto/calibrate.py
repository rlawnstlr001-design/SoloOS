import sys, time
from multiprocessing import Pool
import duskhold
from bots import *
VSETS = {'murk': ('murk',), 'murk+spore': ('murk', 'spore'), 'rime+spore': ('rime', 'spore'),
         'rust+murk': ('rust', 'murk'), 'rime+hollow': ('rime', 'hollow'), 'all5': ('murk', 'rime', 'spore', 'rust', 'hollow')}
GRID = {
 'rifts3 wild2': dict(rifts=3, wild_cap=2),
 'rifts5 wild2': dict(rifts=5, wild_cap=2),
 'rifts3 wild3': dict(rifts=3, wild_cap=3),
 'rifts5 wild3': dict(rifts=5, wild_cap=3),
 'rifts6 wild3': dict(rifts=6, wild_cap=3),
}
def job(a):
    g, v, pol, seed = a
    r = play(seed, pol, VSETS[v], rule='B', pmode='max', pf=(0, 1, 2, 3), **GRID[g])
    return (g, v, pol, r)
if __name__ == '__main__':
    jobs = [(g, v, pol, 3000 + s) for g in GRID for v in VSETS for pol in POLICIES for s in range(24 if pol == 'mixed' else 48)]
    t = time.time()
    with Pool(4) as p: res = p.map(job, jobs, chunksize=8)
    agg = {}
    for g, v, pol, r in res: agg.setdefault((g, pol), {}).setdefault(v, []).append((r['won'], r['lit']))
    for g in GRID:
        print('\n##', g)
        for pol in POLICIES:
            vs = agg[(g, pol)]
            w = {v: 100 * sum(x[0] for x in l) / len(l) for v, l in vs.items()}
            lit = sum(sum(x[1] for x in l) / len(l) for l in vs.values()) / len(vs)
            print('  %-13s avg %3.0f%% (lit %4.1f) | ' % (pol, sum(w.values()) / len(w), lit) + ' '.join('%s %3.0f' % (v[:9], w[v]) for v in VSETS))
    print('time %.0fs' % (time.time() - t))

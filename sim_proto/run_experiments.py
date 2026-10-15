import sys, json, time
from multiprocessing import Pool
from bots import *

VSETS = {'murk': ('murk',), 'murk+spore': ('murk', 'spore'), 'rime+spore': ('rime', 'spore'),
         'rust+murk': ('rust', 'murk'), 'rime+hollow': ('rime', 'hollow'),
         'all5': ('murk', 'rime', 'spore', 'rust', 'hollow')}
REGIMES = {
    'R1 max,wild2': dict(pmode='max', wild_cap=2, pf=(0, 1, 2, 3)),
    'R2 max,cap2': dict(pmode='max', wild_cap=3, pf=(0, 1, 1, 2)),
}


def job(a):
    regime, vname, pol, seed, rule = a
    r = play(seed, pol, VSETS[vname], rule=rule, **REGIMES[regime])
    return (regime, vname, pol, rule, r)


if __name__ == '__main__':
    regimes = sys.argv[1].split(',') if len(sys.argv) > 1 else list(REGIMES)
    rules = sys.argv[2].split(',') if len(sys.argv) > 2 else ['B']
    jobs = []
    for reg in REGIMES:
        if reg.split()[0] not in regimes: continue
        for v in VSETS:
            for pol in POLICIES:
                n = 30 if pol == 'mixed' else 80
                for rule in rules:
                    for s in range(n): jobs.append((reg, v, pol, 1000 + s, rule))
    t = time.time()
    with Pool(4) as p: res = p.map(job, jobs, chunksize=8)
    agg = {}
    for reg, v, pol, rule, r in res:
        a = agg.setdefault((reg, rule, v, pol), [])
        a.append(r)
    out = {}
    for k, rs in agg.items():
        out['|'.join(k)] = dict(n=len(rs), win=sum(x['won'] for x in rs) / len(rs), lit=sum(x['lit'] for x in rs) / len(rs),
                               defense=sum(x['defense'] for x in rs) / len(rs), blight=sum(x['blight'] for x in rs) / len(rs))
    json.dump(out, open('results_%s.json' % ('_'.join(r.split()[0] for r in regimes)), 'w'), indent=1)
    for reg in regimes:
        for rule in rules:
            print('\n##', reg, 'rule', rule)
            print('%-12s' % 'variants', *['%-14s' % p for p in POLICIES])
            for v in VSETS:
                row = []
                for pol in POLICIES:
                    k = [kk for kk in out if kk.startswith(reg) and kk.endswith('|%s|%s' % (v, pol)) and ('|%s|' % rule) in kk]
                    d = out[k[0]] if k else None
                    row.append('%3d%% lit%4.1f   ' % (100 * d['win'], d['lit']) if d else ' - ')
                print('%-12s' % v, *row)
    print('time %.0fs' % (time.time() - t))

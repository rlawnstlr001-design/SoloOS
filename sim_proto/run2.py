import sys, time, json
from multiprocessing import Pool
from bots2 import *
VSETS = {'murk+spore': ('murk', 'spore'), 'rime+spore': ('rime', 'spore'), 'rust+murk': ('rust', 'murk'), 'all5': ('murk', 'rime', 'spore', 'rust', 'hollow')}
CFGS = {
 'A no-expand, no-actives': dict(expand='none', actives=False, rush=False),
 'B safe-expand, no-actives': dict(expand='safe', actives=False, rush=False),
 'C safe-expand + actives': dict(expand='safe', actives=True, rush=False),
 'D rift-expand + actives': dict(expand='rift', actives=True, rush=False),
 'E rush seal (range1)': dict(expand='rift', actives=True, rush=True, seal_range=1),
 'F rush seal (range2)': dict(expand='rift', actives=True, rush=True, seal_range=2),
 'G rush seal (range3)': dict(expand='rift', actives=True, rush=True, seal_range=3),
}
def job(a):
    cn, vn, seed = a
    return (cn, vn, play2(seed, VSETS[vn], CFGS[cn], None))
if __name__ == '__main__':
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    jobs = [(c, v, 5000 + s) for c in CFGS for v in VSETS for s in range(n)]
    t = time.time()
    with Pool(4) as p: res = p.map(job, jobs, chunksize=4)
    agg = {}
    for c, v, r in res: agg.setdefault(c, {}).setdefault(v, []).append(r)
    out = {}
    print('%-27s | %5s %5s %5s %5s %6s %6s | per-variant win%%: %s' % ('config', 'win', 'early', 'seals', 'lit', 'tdays', 'ember', ' '.join(VSETS)))
    for c in CFGS:
        allr = [r for v in agg[c] for r in agg[c][v]]
        m = lambda k: sum(float(r[k]) for r in allr) / len(allr)
        pv = ' '.join('%4.0f' % (100 * sum(r['won'] for r in agg[c][v]) / len(agg[c][v])) for v in VSETS)
        print('%-27s | %4.0f%% %4.0f%% %5.2f %5.1f %6.0f %6.0f | %s' % (c, 100 * m('won'), 100 * m('early'), m('sealed'), m('lit'), m('tdays'), m('ember'), pv))
        out[c] = dict(far=m('far_days'), burst=m('n_burst'), pyre=m('n_pyre'), win=m('won'), early=m('early'), sealed=m('sealed'), lit=m('lit'), tdays=m('tdays'), ember=m('ember'), unspentM=m('M'), unspentL=m('L'), builds=m('builds'), placed=m('placed'))
    json.dump(out, open('results_run2.json', 'w'), indent=1)
    print()
    for c in CFGS: print('%-27s far-days %5.1f | burst/run %.2f pyre/run %.2f | unspent M %.0f L %.0f | builds %.1f | tiles placed %.1f' % (c, out[c]['far'], out[c]['burst'], out[c]['pyre'], out[c]['unspentM'], out[c]['unspentL'], out[c]['builds'], out[c]['placed']))
    base = out['C safe-expand + actives']
    print()
    for c in ('D rift-expand + actives', 'G rush seal (range3)'):
        d = out[c]
        if d['far'] > base['far']:
            print('break-even Ember per far-tile-day for %s to beat C: %.2f' % (c, (base['ember'] - d['ember']) / (d['far'] - base['far'])))
        else:
            print('%s has FEWER far tile-days than C (%.1f vs %.1f): no weight on far tiles can make it win' % (c, d['far'], base['far']))
    print('time %.0fs, n=%d per cell' % (time.time() - t, n))

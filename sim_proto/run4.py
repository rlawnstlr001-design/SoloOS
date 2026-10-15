import sys, time
from multiprocessing import Pool
from bots2 import *
from run2 import VSETS
V1 = dict(upkeep=True, seal_goal=2, far_w=1.5, burst_cd=4)
CF = {
 'old rules, C safe+actives': dict(expand='safe', actives=True, rush=False),
 'v0.2 C safe+actives': dict(expand='safe', actives=True, rush=False, **V1),
 'v0.2 D rift+actives': dict(expand='rift', actives=True, rush=False, **V1),
 'v0.2 G rush seal r3': dict(expand='rift', actives=True, rush=True, seal_range=3, **V1),
 'v0.2 G2 rush seal r2': dict(expand='rift', actives=True, rush=True, seal_range=2, **V1),
 'v0.2 A no-expand': dict(expand='none', actives=False, rush=False, **V1),
 'v0.2 C, far_w 2.5': dict(expand='safe', actives=True, rush=False, **dict(V1, far_w=2.5)),
 'v0.2 D, far_w 2.5': dict(expand='rift', actives=True, rush=False, **dict(V1, far_w=2.5)),
 'v0.2 G r3, far_w 2.5': dict(expand='rift', actives=True, rush=True, seal_range=3, **dict(V1, far_w=2.5)),
}
def job(a):
    c, v, seed = a
    return (c, v, play2(seed, VSETS[v], CF[c], None))
if __name__ == '__main__':
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    jobs = [(c, v, 9000 + s) for c in CF for v in VSETS for s in range(n)]
    with Pool(4) as p: res = p.map(job, jobs, chunksize=4)
    agg = {}
    for c, v, r in res: agg.setdefault(c, {}).setdefault(v, []).append(r)
    print('%-26s | %4s %5s %5s %5s %5s %6s | unspent M/L | burst pyre | win by variant: %s' % ('config', 'win', 'early', 'seal', 'lit', 'far', 'ember', ' '.join(VSETS)))
    for c in CF:
        a = [r for v in agg[c] for r in agg[c][v]]; m = lambda k: sum(float(r[k]) for r in a) / len(a)
        pv = ' '.join('%3.0f' % (100 * sum(r['won'] for r in agg[c][v]) / len(agg[c][v])) for v in VSETS)
        print('%-26s | %3.0f%% %4.0f%% %5.2f %5.1f %5.1f %6.0f | %4.0f / %3.0f | %.2f %.2f | %s' % (c, 100 * m('won'), 100 * m('early'), m('sealed'), m('lit'), m('far_days'), m('ember'), m('M'), m('L'), m('n_burst'), m('n_pyre'), pv))

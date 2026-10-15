import sys, time
from multiprocessing import Pool
from bots2 import *
from run2 import VSETS
INC = {'income 2M+1L (current)': (2, 1), 'income 1M+1L': (1, 1), 'income 1M+0L': (1, 0), 'income 0M+0L': (0, 0)}
def job(a):
    inc, vn, seed = a
    cfg = dict(expand='safe', actives=True, rush=False, base_m=INC[inc][0], base_l=INC[inc][1])
    return (inc, vn, play2(seed, VSETS[vn], cfg, None))
if __name__ == '__main__':
    n = 60
    jobs = [(i, v, 7000 + s) for i in INC for v in VSETS for s in range(n)]
    with Pool(4) as p: res = p.map(job, jobs, chunksize=4)
    agg = {}
    for i, v, r in res: agg.setdefault(i, []).append(r)
    print('%-24s %5s %5s %6s | unspent M / L | builds | burst' % ('config (safe-expand+actives)', 'win', 'lit', 'ember'))
    for i in INC:
        a = agg[i]; m = lambda k: sum(float(r[k]) for r in a) / len(a)
        print('%-24s %4.0f%% %5.1f %6.0f | %4.0f / %3.0f | %5.1f | %.2f' % (i, 100 * m('won'), m('lit'), m('ember'), m('M'), m('L'), m('builds'), m('n_burst')))

# -*- coding: utf-8 -*-
"""
dukascopy_replica.py — La prueba de fuego: replicar el hallazgo en un feed INDEPENDIENTE
=========================================================================================
Regla del caso Tokio Reversal (ver docs/): ningún positivo es creíble sin replicarse en
datos que NO se usaron para encontrarlo. Este script descarga los ticks públicos de
Dukascopy (feed suizo, bid/ask reales) SOLO de las 2 horas necesarias de cada día gotobi,
y ejecuta la regla congelada: SELL primer tick >=00:55 UTC, cubrir primer tick >=01:10,
stop 20 pips, costo = spread real del tick + comisión.

USO:      python dukascopy_replica.py          (sin dependencias raras: stdlib + pandas/numpy)
NOTA:     Dukascopy limita por IP (~6 archivos/min). ~900 archivos => paciencia o varias corridas
          (cachea en ./duka_cache y retoma donde quedó).

Criterio PASA (fíjalo ANTES de correr): media > +1 pip, t >= 2.5, >= 5/7 años positivos.
Instituto Quant · https://www.InstitutoQuant.com · Material educativo, no asesoría financiera.
"""
import lzma
import os
import struct
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta

import numpy as np
import pandas as pd

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "duka_cache")
os.makedirs(CACHE, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0"}
SIMBOLO = "USDJPY"
ESCALA = 1000.0          # precios bi5 en milésimas para pares JPY (p.ej. 157421 -> 157.421)
PIP = 0.01
COMISION_PIPS = 1.1
STOP = 20 * PIP
ANIO_INI, ANIO_FIN = 2020, 2026


def gotobis():
    out, d = [], date(ANIO_INI, 1, 1)
    fin = date(ANIO_FIN, 12, 31) if date.today().year > ANIO_FIN else date.today()
    while d <= fin:
        if d.day in (5, 10, 15, 20, 25, 30):
            g = d
            while g.weekday() >= 5:
                g -= timedelta(days=1)
            out.append(g)
        d += timedelta(days=1)
    return sorted(set(out))


def bajar(args):
    d, h = args
    fn = os.path.join(CACHE, f"{d.isoformat()}_{h:02d}.bin")
    if os.path.exists(fn) and os.path.getsize(fn) > 0:
        return
    url = (f"https://datafeed.dukascopy.com/datafeed/{SIMBOLO}/"
           f"{d.year}/{d.month - 1:02d}/{d.day:02d}/{h:02d}h_ticks.bi5")
    for _ in range(3):
        try:
            data = urllib.request.urlopen(
                urllib.request.Request(url, headers=UA), timeout=25).read()
            if data:
                open(fn, "wb").write(data)
                return
        except Exception:
            time.sleep(1.0)


def ticks(fn):
    """bi5 = LZMA de registros big-endian: ms_offset(i32), ask(i32), bid(i32), vols(f32 x2)."""
    if not os.path.exists(fn) or os.path.getsize(fn) == 0:
        return []
    try:
        raw = lzma.decompress(open(fn, "rb").read())
    except Exception:
        return []
    return [(ms, a / ESCALA, b / ESCALA)
            for ms, a, b, _, _ in struct.iter_unpack(">3i2f", raw)]


def main():
    G = gotobis()
    tareas = [(d, h) for d in G for h in (0, 1)]
    print(f"{len(G)} gotobis -> {len(tareas)} archivos (cacheados: se saltan)")
    with ThreadPoolExecutor(max_workers=3) as ex:      # >3 hilos = Dukascopy te bloquea
        list(ex.map(bajar, tareas))

    res = []
    for d in G:
        t0 = ticks(os.path.join(CACHE, f"{d.isoformat()}_00.bin"))
        t1 = ticks(os.path.join(CACHE, f"{d.isoformat()}_01.bin"))
        if not t0 or not t1:
            continue
        ent = [x for x in t0 if x[0] >= 55 * 60000]
        if not ent:
            continue
        e_ms, _, e_bid = ent[0]                        # SELL al bid real
        stop_px, ex_px = e_bid + STOP, None
        for ms, a, b in (x for x in t0 if x[0] > e_ms):
            if a >= stop_px:
                ex_px = stop_px
                break
        if ex_px is None:
            for ms, a, b in t1:
                if ms >= 10 * 60000:                   # cubrir al ASK real >= 01:10
                    ex_px = a
                    break
                if a >= stop_px:
                    ex_px = stop_px
                    break
        if ex_px is None:
            continue
        res.append(dict(f=pd.Timestamp(d), pips=(e_bid - ex_px) / PIP - COMISION_PIPS))

    df = pd.DataFrame(res)
    p = df.pips.values
    se = p.std() / np.sqrt(len(p))
    t = p.mean() / se
    print(f"\nTOTAL  N={len(p)}  media={p.mean():+.2f} pips  "
          f"IC95=[{p.mean()-1.96*se:+.2f},{p.mean()+1.96*se:+.2f}]  t={t:.2f}")
    pos = tot = 0
    for y, g in df.groupby(df.f.dt.year):
        m = g.pips.mean()
        print(f"  {y}: N={len(g):3d}  media={m:+.2f}  win={100*(g.pips>0).mean():.0f}%")
        if len(g) >= 15:
            tot += 1
            pos += m > 0
    pasa = p.mean() > 1.0 and t >= 2.5 and pos >= 5
    print(f"\nCriterios: media>+1.0={p.mean()>1.0}  t>=2.5={t>=2.5}  años {pos}/{tot}")
    print("VEREDICTO:", "PASA — sigue al forward (docs/04)" if pasa
          else "FALLA — archívalo y documenta la muerte")


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""
nakane_backtest.py — Arnés replicable del caso Tokio Reversal (Instituto Quant)
================================================================================
Reproduce el backtest del short post-fix de Tokio: SELL en el fix (09:55 JST),
cubrir 10:10, solo días gotobi (5/10/15/20/25/30; finde -> viernes previo) y
último día hábil del mes. Stop de protección 20 pips. Neto de costos.

REQUISITOS:  pip install MetaTrader5 pandas numpy
             Terminal MT5 abierto y logueado (cualquier broker con historial M1).

USO:         python nakane_backtest.py [SIMBOLO]     (por defecto USDJPY)

Qué imprime: total y por año (media pips, win%, t-stat), grupo de CONTROL
(mismas horas en días no-gotobi) y el desglose por día gotobi.

Material educativo del caso de estudio: github -> tokio-reversal-caso
Aprende el método completo en https://www.InstitutoQuant.com
NO es asesoría financiera. Un backtest es una sola trayectoria histórica.
"""
import sys
from datetime import datetime

import numpy as np
import pandas as pd
import MetaTrader5 as mt5

SIMBOLO = sys.argv[1] if len(sys.argv) > 1 else "USDJPY"
PIP = 0.01            # pares JPY
COMISION_PIPS = 1.1   # ida+vuelta cuenta Raw tipica ($7/lote RT); ajusta a tu broker
STOP_PIPS = 20
ANIO_INI, ANIO_FIN = 2020, 2026
SERVIDOR_UTC_OFFSET = 0   # Exness = UTC; verifica el de tu broker (afecta la hora del fix!)


def cargar_m1(sym):
    """M1 por tramos anuales (evita el tope de barras por peticion)."""
    partes = []
    for y in range(ANIO_INI, ANIO_FIN + 1):
        r = mt5.copy_rates_range(sym, mt5.TIMEFRAME_M1,
                                 datetime(y, 1, 1), datetime(y, 12, 31, 23, 59))
        if r is not None and len(r):
            partes.append(pd.DataFrame(r))
    if not partes:
        raise RuntimeError(f"sin datos M1 para {sym}")
    m = pd.concat(partes).drop_duplicates("time").sort_values("time").reset_index(drop=True)
    print(f"[{sym}] {len(m)} barras M1: {pd.to_datetime(m.time.iloc[0], unit='s')} -> "
          f"{pd.to_datetime(m.time.iloc[-1], unit='s')}")
    return m


def preparar(m):
    t = m.time.values.astype(np.int64)
    jst = pd.to_datetime(t + (9 - SERVIDOR_UTC_OFFSET) * 3600, unit="s")
    return dict(O=m.open.values, H=m.high.values,
                jd=pd.Series(jst).dt.date.values, jh=jst.hour.values, jm=jst.minute.values,
                jst=jst)


def calendarios(x):
    """gotobi (finde->viernes) y ultimo dia habil del mes."""
    fechas = pd.to_datetime(pd.Series(pd.Series(x["jst"]).dt.normalize()).unique())
    gotobi = set()
    for f in fechas:
        if f.day in (5, 10, 15, 20, 25, 30):
            g = f
            while g.weekday() >= 5:
                g -= pd.Timedelta(days=1)
            gotobi.add(g.date())
    habiles = [f for f in fechas if f.weekday() < 5]
    ult = {}
    for f in habiles:
        ult[(f.year, f.month)] = max(ult.get((f.year, f.month), f), f)
    fin_de_mes = {v.date() for v in ult.values()} - gotobi
    return gotobi, fin_de_mes


def correr(x, dias):
    """SELL open de la barra >=09:55 JST; cubrir open de la barra >=10:10; stop 20p intrabar."""
    idx = pd.DataFrame({"d": x["jd"], "h": x["jh"], "m": x["jm"],
                        "i": np.arange(len(x["O"]))})
    res = []
    for d, g in idx.groupby("d"):
        if d not in dias:
            continue
        e = g[(g.h == 9) & (g.m >= 55)]
        s = g[(g.h == 10) & (g.m >= 10)]
        if len(e) == 0 or len(s) == 0:
            continue
        i0, i1 = int(e.i.iloc[0]), int(s.i.iloc[0])
        if i1 <= i0:
            continue
        entry = x["O"][i0]
        stop = entry + STOP_PIPS * PIP
        ex = None
        for j in range(i0, i1):               # adverso primero (pesimista)
            if x["H"][j] >= stop:
                ex = stop
                break
        if ex is None:
            ex = x["O"][i1]
        res.append(dict(f=pd.Timestamp(d), pips=(entry - ex) / PIP - COMISION_PIPS))
    return pd.DataFrame(res)


def stats(df, label):
    if len(df) < 15:
        return f"{label:26s} N={len(df)} (muestra corta)"
    p = df.pips.values
    se = p.std() / np.sqrt(len(p))
    ic = (p.mean() - 1.96 * se, p.mean() + 1.96 * se)
    return (f"{label:26s} N={len(p):4d}  media={p.mean():+.2f} pips  "
            f"IC95=[{ic[0]:+.2f},{ic[1]:+.2f}]  win={100 * (p > 0).mean():.0f}%  "
            f"t={p.mean() / se:.2f}")


def main():
    if not mt5.initialize():
        raise RuntimeError("MT5 no inicializa — abre el terminal primero")
    x = preparar(cargar_m1(SIMBOLO))
    gotobi, fdm = calendarios(x)

    print("\n=== TOKIO REVERSAL: short 09:55->10:10 JST ===")
    g = correr(x, gotobi)
    print(stats(g, "GOTOBI"))
    print(stats(correr(x, fdm), "FIN DE MES (no-gotobi)"))
    ctrl = correr(x, {d for d in set(x["jd"]) if d not in gotobi and pd.Timestamp(d).weekday() < 5})
    print(stats(ctrl, "CONTROL (dias normales)"))
    print("\n--- gotobi por anio (busca DECAY antes de creer) ---")
    for y, gg in g.groupby(g.f.dt.year):
        print(stats(gg, str(y)))
    print("\nRecuerda: esto es UNA trayectoria en UN feed. Replica en datos independientes")
    print("y valida forward antes de arriesgar un peso. https://www.InstitutoQuant.com")


if __name__ == "__main__":
    main()

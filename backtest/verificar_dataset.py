# -*- coding: utf-8 -*-
"""
verificar_dataset.py — Auditoría reproducible del dataset publicado (Instituto Quant)
=====================================================================================
Para un estudiante que quiere COMPROBAR el caso, no creerlo. Dos capas:

  1) RE-CÁLCULO (sin red, solo stdlib): recalcula media, t, win, años+ y cobertura del
     calendario gotobi a partir de data/resultados_replica_dukascopy.csv.
  2) SPOT-CHECK a nivel de tick (opcional, requiere red): baja los ticks Dukascopy de
     N días muestreados y verifica que reproducen el CSV celda por celda.

USO:   python verificar_dataset.py                 (solo re-cálculo, instantáneo)
       python verificar_dataset.py --spotcheck 15  (además descarga y compara 15 días)

No modifica ningún archivo. Material educativo, no asesoría financiera.
https://www.InstitutoQuant.com
"""
import csv, math, os, sys
from datetime import date, timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
CSVP = os.path.join(HERE, "..", "data", "resultados_replica_dukascopy.csv")
ANIO_INI, ANIO_FIN = 2020, 2026
PIP, COMISION_PIPS, STOP = 0.01, 1.1, 20 * 0.01


def gotobis_calendario():
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


def recalculo():
    rows = list(csv.DictReader(open(CSVP)))
    pips = [float(r["pips"]) for r in rows]
    fechas = [date.fromisoformat(r["f"]) for r in rows]
    n = len(pips)
    mean = sum(pips) / n
    sd = math.sqrt(sum((x - mean) ** 2 for x in pips) / (n - 1))  # ddof=1
    se = sd / math.sqrt(n)
    print("=== RE-CÁLCULO DEL DATASET PUBLICADO (independiente, stdlib) ===")
    print(f"N={n}  media={mean:+.3f} pips  t={mean/se:.2f}  win={100*sum(x>0 for x in pips)/n:.1f}%")
    by = {}
    for x, f in zip(pips, fechas):
        by.setdefault(f.year, []).append(x)
    pos = tot = 0
    for y in sorted(by):
        g = by[y]; m = sum(g) / len(g)
        marca = ""
        if len(g) >= 15:
            tot += 1; pos += m > 0
        print(f"  {y}: N={len(g):3d}  media={m:+.2f}  win={100*sum(v>0 for v in g)/len(g):.0f}%{marca}")
    print(f"Años positivos (N>=15): {pos}/{tot}")

    # cobertura vs calendario (el desfase que detectó la auditoría de la comunidad)
    cal = set(gotobis_calendario())
    have = set(fechas)
    ausentes = sorted(cal - have)
    print("\n=== COBERTURA vs CALENDARIO GOTOBI ===")
    print(f"calendario={len(cal)}  en CSV={len(have)}  AUSENTES={len(ausentes)}  extra={len(have-cal)}")
    if ausentes:
        print("  (días gotobi sin fila en el CSV — ver data/EVENTOS_AUSENTES.md)")
        print("  primeros:", ", ".join(d.isoformat() for d in ausentes[:8]), "...")
    return {r["f"]: float(r["pips"]) for r in rows}


def spotcheck(csvmap, k):
    import lzma, struct, time, urllib.request
    from concurrent.futures import ThreadPoolExecutor
    cache = os.path.join(HERE, "duka_cache"); os.makedirs(cache, exist_ok=True)
    ua = {"User-Agent": "Mozilla/5.0"}
    fechas = sorted(csvmap)
    idx = [int(round(i)) for i in [j * (len(fechas) - 1) / (k - 1) for j in range(k)]]
    muestra = [date.fromisoformat(fechas[i]) for i in sorted(set(idx))]
    print(f"\n=== SPOT-CHECK A NIVEL DE TICK ({len(muestra)} días) ===")

    def bajar(a):
        d, h = a
        fn = os.path.join(cache, f"{d.isoformat()}_{h:02d}.bin")
        if os.path.exists(fn) and os.path.getsize(fn) > 0:
            return
        url = (f"https://datafeed.dukascopy.com/datafeed/USDJPY/"
               f"{d.year}/{d.month-1:02d}/{d.day:02d}/{h:02d}h_ticks.bi5")
        for _ in range(4):
            try:
                open(fn, "wb").write(urllib.request.urlopen(
                    urllib.request.Request(url, headers=ua), timeout=25).read()); return
            except Exception:
                time.sleep(1.5)

    with ThreadPoolExecutor(max_workers=3) as ex:
        list(ex.map(bajar, [(d, h) for d in muestra for h in (0, 1)]))

    def ticks(fn):
        if not os.path.exists(fn) or os.path.getsize(fn) == 0:
            return []
        try:
            raw = lzma.decompress(open(fn, "rb").read())
        except Exception:
            return []
        return [(ms, a / 1000.0, b / 1000.0) for ms, a, b, _, _ in struct.iter_unpack(">3i2f", raw)]

    ok = tot = 0
    for d in muestra:
        t0 = ticks(os.path.join(cache, f"{d.isoformat()}_00.bin"))
        t1 = ticks(os.path.join(cache, f"{d.isoformat()}_01.bin"))
        if not t0 or not t1:
            print(f"  {d}  (sin datos descargados)"); continue
        ent = [x for x in t0 if x[0] >= 55 * 60000]
        if not ent:
            continue
        e_ms, _, e_bid = ent[0]; stop_px = e_bid + STOP; ex_px = None
        for ms, a, b in (x for x in t0 if x[0] > e_ms):
            if a >= stop_px:
                ex_px = stop_px; break
        if ex_px is None:
            for ms, a, b in t1:
                if ms >= 10 * 60000:
                    ex_px = a; break
                if a >= stop_px:
                    ex_px = stop_px; break
        if ex_px is None:
            continue
        recalc = (e_bid - ex_px) / PIP - COMISION_PIPS
        csvv = csvmap[d.isoformat()]; diff = recalc - csvv
        good = abs(diff) < 0.05; ok += good; tot += 1
        print(f"  {d}  CSV={csvv:+7.2f}  recalc={recalc:+7.2f}  diff={diff:+.2f}  {'OK' if good else 'XX'}")
    print(f"\nCoinciden (|diff|<0.05): {ok}/{tot}",
          "-> ticks reproducen el CSV" if tot and ok == tot else "-> revisar")


if __name__ == "__main__":
    m = recalculo()
    if "--spotcheck" in sys.argv:
        i = sys.argv.index("--spotcheck")
        k = int(sys.argv[i + 1]) if len(sys.argv) > i + 1 else 15
        spotcheck(m, k)
    else:
        print("\n(añade '--spotcheck 15' para verificar contra ticks Dukascopy)")

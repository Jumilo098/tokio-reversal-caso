# Dataset — resultados de la réplica independiente (Dukascopy)

`resultados_replica_dukascopy.csv` — **el dataset del veredicto**: un registro por día gotobi
(2020-01 → 2026-08, 436 días con data) con el resultado del trade bajo la regla congelada:

| Columna | Significado |
|---|---|
| `f` | Fecha del día gotobi (JST) |
| `pips` | Resultado NETO del trade en pips: SELL al bid real del primer tick ≥00:55 UTC, cubierto al ask real del primer tick ≥01:10 UTC (o stop +20 pips), menos 1.1 pips de comisión |

**Para verificarlo tú mismo:** `python ../backtest/dukascopy_replica.py` regenera este archivo
desde los ticks públicos de Dukascopy (tarda: el servidor limita a ~6 archivos/min).

**Resumen del dataset:** media **+1.32 pips** · IC95 [+0.37, +2.26] · t=2.74 · win 53% · 6/7 años
positivos → **PASA** los tres criterios pre-registrados (ver `../docs/04_PROTOCOLO_FORWARD.md`).

Los datos crudos (ticks) no se incluyen: son públicos de Dukascopy y pesan cientos de MB — el
script los descarga y cachea. Los datos M1 del backtest primario vienen de cualquier terminal
MetaTrader 5 (`../backtest/nakane_backtest.py`).

🎓 [www.InstitutoQuant.com](https://www.InstitutoQuant.com)

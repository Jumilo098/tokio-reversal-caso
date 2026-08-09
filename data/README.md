# Dataset — resultados de la réplica independiente (Dukascopy)

`resultados_replica_dukascopy.csv` — **el dataset del veredicto**: un registro por día gotobi
(2020-01 → 2026-08, 436 días con data) con el resultado del trade bajo la regla congelada:

| Columna | Significado |
|---|---|
| `f` | Fecha del día gotobi (JST) |
| `pips` | Resultado NETO del trade en pips: SELL al bid real del primer tick ≥00:55 UTC, cubierto al ask real del primer tick ≥01:10 UTC (o stop +20 pips), menos 1.1 pips de comisión |

**Para verificarlo tú mismo (rápido):** `python ../backtest/verificar_dataset.py` recalcula las
estadísticas desde cero (solo stdlib) y muestra la cobertura al instante; añade `--spotcheck 15` para
comparar contra ticks Dukascopy.
**Para regenerarlo desde ticks:** `python ../backtest/dukascopy_replica.py` (tarda horas: el servidor
limita a ~6 archivos/min). Guarda `resultados_replica_dukascopy_regen.csv` (no sobrescribe este) y
reporta la cobertura.

**Resumen del dataset:** media **+1.32 pips** · IC95 [+0.37, +2.26] · t=2.74 · win 53% · 6/7 años
positivos → **PASA** los tres criterios pre-registrados (ver `../docs/04_PROTOCOLO_FORWARD.md`).

> ⚠️ **Cobertura (transparencia tras auditoría de la comunidad):** el calendario gotobi tiene 468
> eventos; este CSV contiene 436. Los **32 ausentes** son días donde la descarga de ticks falló en la
> corrida de generación (no un filtro de la señal), listados y explicados en `EVENTOS_AUSENTES.md`.
> *"El CSV reproduce los resultados"* ≠ *"reprodujimos el experimento"*: hasta cerrar la cobertura
> 468/468, la clasificación honesta es **seguir investigando**, no *validado*.

Los datos crudos (ticks) no se incluyen: son públicos de Dukascopy y pesan cientos de MB — el
script los descarga y cachea. Los datos M1 del backtest primario vienen de cualquier terminal
MetaTrader 5 (`../backtest/nakane_backtest.py`).

🎓 [www.InstitutoQuant.com](https://www.InstitutoQuant.com)

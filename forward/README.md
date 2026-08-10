# Bitácora del forward — el conteo hacia los 60 eventos

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com)

`bitacora_forward.csv` — un registro por evento operado en **demo**, bajo la regla congelada, hacia el
corte pre-registrado de **60 eventos** (~10 meses a ~6/mes). Metodología completa en
`../docs/08_TELEMETRIA_Y_FORWARD.md`.

## Columnas
| Columna | Qué |
|---|---|
| `n` | Número de evento (1…60) |
| `fecha_jst` | Día del evento (JST) |
| `simbolo` | Pata operada |
| `tipo` | SELL (siempre, es el short post-fix) |
| `entrada` / `salida` | Precios de fill reales |
| `pips_netos` | Resultado neto del evento |
| `slippage_pips` | Fill real − precio de referencia (+ = a favor) |
| `spread_fix_pts` | Spread medido en el minuto del fix |
| `latencia_ms` | Tiempo de ejecución de la orden |
| `motivo_salida` | TIME / STOP / SKIP |
| `nota` | Cualquier anomalía o contexto |

## Criterios de PASA/FALLA (firmados ANTES del primer trade)
- **Rentabilidad:** media > +1 pip · t ≥ 2.5.
- **Ejecución:** slippage medio < 0.5 pip · sin rechazos sistemáticos de filling/stops.
- **Corte:** 60 eventos. **No se mueve al ver resultados.**

## Estado
| | |
|---|---|
| Eventos registrados | **1 / 60** |
| Primer evento | 2026-08-10 · STOP · −20 pips (dentro del ~47% perdedor esperado) |
| Ejecución hasta ahora | limpia (fill 76 ms, slippage +0.2p, spread 0, sin rechazos) |

> Recordatorio: el resultado de los primeros eventos **no dice nada** del edge (varianza enorme con
> N chico). Lo que sí se valida temprano es la **ejecución**. El promedio empieza a significar algo
> recién en decenas de eventos.

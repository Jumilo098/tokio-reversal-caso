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
| `pips_netos` | Resultado neto del evento (regla real, con stop) |
| `sombra_tiempo_pips` | **Sombra**: lo que habría dado la salida por tiempo 10:10 SIN stop (medir, no operar) |
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

## La sombra del stop (¿el stop de 20 pips ayuda o estorba?)
La columna `sombra_tiempo_pips` registra, evento por evento, lo que **habría** dado la salida por
tiempo (10:10) **sin** el stop — sin cambiar la regla en vivo. Sobre 60 eventos se ve si el stop suma
o resta neto. Es la técnica de la `v2` (medir sin operar), aplicada al stop.

**Evento 1 (ejemplo del método):** el stop pegó en el pico (158.144) → −20 pips; la salida por tiempo
habría cerrado a 158.052 → **−13.7**. Es decir, en este evento el stop **restó ~6 pips** (te sacó en
el peor tick y el precio luego aflojó). PERO el trade era perdedor de todos modos: el precio nunca
revirtió bajo la entrada. **Un evento no decide** — por eso se mide la sombra en los 60, no se cambia
la regla por una anécdota.

# Telemetría del forward — qué medir, y un primer evento real auditado

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)**

El backtest propone; el forward dispone. Pero un forward mal medido es tan inútil como un backtest
tramposo. Este documento define **qué se mide en el forward** (más allá de los pips), muestra el
**primer evento real ejecutado en demo, auditado end-to-end**, y deja la **bitácora** para llevar el
conteo hacia el corte de 60.

---

## 1. Qué mide el forward que el backtest NO puede

Un backtest reproduce precios; **no reproduce tu ejecución**. El forward existe para medir justo eso:

| Métrica de ejecución | Por qué importa | Criterio pre-firmado |
|---|---|---|
| **Slippage de entrada** | Entrar a mercado en el minuto del fix puede costar más que el mid del backtest | media < 0.5 pip |
| **Spread real en el fix** | El spread a las 09:55 JST no es el de mediodía; el edge es de 1-2 pips | vigilar; skip si ≥ 3 pips |
| **Latencia de fill** | Requotes/rechazos = trade perdido en una estrategia de 1 disparo/día | < ~1 s, sin requote |
| **Filling aceptado** | Un rechazo por filling (retcode 10030) = 0 trade ese día | 0 rechazos |
| **% de skips por spread** | Cuántos eventos se pierden por spread alto (sesga la muestra) | registrar |
| **Tasa de stop-hit** | El repo dice "el tiempo corta antes que el stop"; ¿se cumple en vivo? | registrar vs backtest |
| **Diferencia backtest↔real** | ¿El trade real se parece al simulado, evento por evento? | registrar |

**Los pips son lo de menos al principio.** Con ~53% de aciertos y +1-2 pips de media, hacen falta
**decenas** de eventos para que el promedio signifique algo. Lo que un puñado de trades SÍ valida de
inmediato es la **plumbing**: que el EA entra puntual, gestiona el stop y cierra, con costo realista.

---

## 2. Primer evento real — auditado end-to-end (ejemplo de método)

Primer disparo en demo (cuenta Raw de un broker minorista, símbolo USDJPY). Reconstruido desde el log
del terminal y el historial de deals de la cuenta:

```
SELL 0.01 USDJPY @ 157.926   (09:55:00 JST / 00:55:00 UTC)
BUY  0.01 USDJPY @ 158.124   (10:04:00 JST / 01:04:00 UTC)  <- STOP LOSS
```

| Dato | Valor |
|---|---|
| Duración | **9.0 min** (el stop pegó antes del cierre por tiempo de 15 min) |
| Pips brutos | **−19.8** |
| Costo | comisión ≈ 0.05 USD / 0.01 lote · spread en el fix **0 pts** · swap 0 |
| Resultado neto | ≈ **−20 pips** = el riesgo pre-definido del evento (~0.2% de una demo pequeña) |
| Motivo de salida | **STOP LOSS** (el precio subió ~20 pips en contra del short en 9 min) |

### Scorecard de EJECUCIÓN (esto es lo que se validó)
| Chequeo | Resultado |
|---|---|
| Disparo puntual | 00:55:00 exacto ✓ |
| Latencia de fill | 76 ms, sin requote ✓ |
| Slippage de entrada | **+0.2 pip a favor** (vendió a 157.926 vs bid leído 157.924) ✓ |
| Spread en el fix | **0 pts** ✓ |
| Stop colocado y respetado | server-side a 158.124 ✓ |
| Filling | aceptado a la primera (Exness OK con FOK) ✓ |
| Modelo de costos | comisión + spread ≈ el supuesto Raw (1.1 pip) del backtest ✓ |

### La lectura honesta
- **No se lee NADA en el resultado de un trade.** Un evento es una moneda al aire; este cayó en el
  ~47% perdedor, y encima fue de los que llegan al stop (que el repo describe como raros: *"el tiempo
  casi siempre las corta antes"* — casi, no siempre). Sirve de dato para la tasa de stop-hit, nada más.
- **Lo que sí quedó probado al 100% es la ejecución**: entrada→gestión de stop→cierre corre limpia,
  con costo realista y sin bugs. Ese era el objetivo del primer evento, no ganar dinero.
- **Bonus:** se validó de gratis el camino del **stop-loss** (el "airbag" funciona server-side), no
  solo la salida por tiempo.

---

## 3. La bitácora del forward (llevar el conteo a 60)

Sin fecha de corte y criterios firmados **antes**, un forward es esperanza con gráficos. Se registra
**cada evento** en `forward/bitacora_forward.csv` con esta granularidad:

| Columna | Qué |
|---|---|
| `fecha_jst` | Día del evento (JST) |
| `simbolo` | Pata operada |
| `entrada` / `salida` | Precios de fill reales |
| `pips_netos` | Resultado neto del evento |
| `slippage_pips` | Fill real − precio de referencia |
| `spread_fix_pts` | Spread medido en el minuto del fix |
| `motivo_salida` | TIME / STOP / SKIP |
| `latencia_ms` | Tiempo de ejecución de la orden |
| `nota` | Cualquier anomalía |

**Criterios de PASA/FALLA (firmados ANTES del primer trade):**
- Media > +1 pip · t ≥ 2.5 · slippage medio < 0.5 pip · sin rechazos de ejecución sistemáticos.
- **Corte a 60 eventos (~10 meses a ~6/mes).** No se mueve el corte al ver resultados.

**Regla de oro:** la regla NO se toca durante el forward. Cualquier idea (trailing, otra salida, otra
pata) se mide como *sombra* o como hipótesis nueva pre-registrada — nunca bolteando el EA en marcha.

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — el forward es el único juez final.

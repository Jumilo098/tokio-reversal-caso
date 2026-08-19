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

## 4. Conectar el EA al hub (v1.20)

Medir a mano lo que el EA ya sabe es trabajo perdido — y peor, es trabajo que se olvida de hacer el
día que el evento sale raro. `ea/TokioReversal_v1_telemetria.mq5` es la **v1.10 endurecida con la
regla intacta**, más el arnés de telemetría del hub del Instituto. Compilado y verificado: 0
errores, 0 warnings.

Lo que reporta, evento por evento:

| Evento | Qué lleva |
|---|---|
| `START` | Se manda **por temporizador**, no en el primer tick: así se confirma la integración un sábado con el mercado cerrado |
| `HEARTBEAT` | Uno por día JST. Sirve para distinguir "no operó" de "estaba caído" — que es justo la diferencia que el incidente del 10-ago hizo importante |
| `OPEN` | Lote, riesgo, spread en el fix, precio pretendido vs. lleno (**slippage real**) y SL colocado |
| `CLOSE` | Profit, swap, comisión, motivo (`TIME`/`STOP`), duración y pips brutos |
| `SKIP` | Cuando el spread veta el evento — el skip honesto también es un dato |

Puesta en marcha (los tres fallos que se llevan el 90% del tiempo están en la bitácora del hub):

1. Coger el **token personal** del miembro en el panel del hub.
2. MT5 → Herramientas → Opciones → Asesores Expertos → **Permitir WebRequest**, y **PEGAR** el
   dominio del proyecto. No escribirlo: el identificador son veinte caracteres aleatorios y una
   letra distinta hace que MetaTrader corte la llamada en silencio (`err=4014`). Pulsar **Enter**
   para que la fila quede añadida.
3. Inputs: `UseWebTelemetry=true`, `TelemetryUrl=.../functions/v1/runner-ingest`, `TelemetryToken=<token>`.
4. Verificar en el **Diario de MetaTrader (pestaña Expertos)**. Es el único sitio donde el terminal
   dice la verdad; todo lo demás es adivinar.
5. Si migras a VPS: la lista blanca de WebRequest viaja en la **foto** del terminal. Cambiarla
   después no le hace nada al VPS hasta re-sincronizar.

> ⚠️ **Trampa medida:** el hub guarda `ea_version` **truncado a 16 caracteres**. Por eso el EA manda
> `tokio-1.20` y no `tokioreversal-1.20`, que llegaría cortado. Si ves una versión a medias en la
> base, es esto — y no un EA distinto.

**La telemetría nunca decide nada.** Si el envío falla, el trade sigue exactamente igual: aquí no
hay trailing que gestionar entre las 09:55 y las 10:10, así que un `WebRequest` lento no puede
estropear una ejecución.

---
---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — el forward es el único juez final.

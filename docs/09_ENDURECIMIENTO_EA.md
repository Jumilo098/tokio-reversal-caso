# Endurecimiento del EA para ejecución en vivo (Exness) — la regla no cambia, la ejecución sí

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)**

El `TokioReversal_v1.mq5` implementa la **regla congelada** (correcta y pre-registrada). Pero pasar de
un backtest a **operar en un broker real** expone una capa que el backtest ignora: **la ejecución**.
Una revisión de código (con un revisor independiente) encontró varios puntos que, sin cambiar la
regla, hacen la diferencia entre que el EA opere o falle silenciosamente en Exness.

`ea/TokioReversal_v1_exness.mq5` es la variante **v1.10 EXNESS** con los arreglos aplicados. La
**regla es idéntica** (SELL 09:55 JST, cubrir 10:10, gotobi, stop 20); solo cambia la robustez.

---

## Hallazgos, por severidad

### 🔴 Críticos

**C1 — El reloj dependía del último tick.** `HoraJST()` usaba `TimeCurrent()`, que devuelve la marca
de tiempo del **último tick recibido**, no la hora del servidor. En el pre-open asiático quieto, si no
llegan ticks, el reloj se **congela** y el disparo del fix (o el cierre 10:10) llega tarde o no llega.
Para una estrategia de hora exacta, es un fallo silencioso.
- **Fix:** usar `TimeTradeServer()` (hora de servidor calculada, avanza sin ticks).

**C3 — No se fijaba el modo de filling.** `CTrade` por defecto intenta `ORDER_FILLING_FOK`. Varios
símbolos de Exness (sobre todo cuentas market-execution y símbolos con sufijo `m`) solo aceptan
**IOC** → `OrderSend` devuelve **retcode 10030** y **no abre nada**. En una estrategia de 1 disparo/día,
eso es perder el evento entero, en silencio.
- **Fix:** `trade.SetTypeFillingBySymbol(_Symbol)` en `OnInit` (resuelve IOC/FOK según el símbolo).
- *Nota de campo:* en la prueba real, el USDJPY de la cuenta demo **sí aceptó FOK** (fill a la primera).
  Pero no todas las cuentas/símbolos lo hacen — el fix elimina el modo de fallo.

**C2 — Offset servidor→UTC estático (riesgo DST).** El input `ServerToUTC_Horas=0` se mide correcto
hoy, pero los servidores de Exness pueden **cambiar el offset con el DST**. Japón no tiene DST, así que
el único que se mueve es el servidor → en el cambio de estación, TODOS los fixes se corren 1 hora.
- **Fix robusto (opcional):** derivar el offset en vivo de `TimeGMT()` vs `TimeTradeServer()` y
  loguearlo en `OnInit` para detectar drift. Como mínimo: re-verificar en cada frontera DST.

**C4 — La telemetría se apropia del temporizador.** (Hallado al conectar el EA al hub, 18-ago-2026.)
`TelemetriaTimer()` del módulo oficial hace `EventKillTimer()` + `EventSetTimer(60)` en cuanto el
`START` sale bien. Este EA necesita el reloj a **1 segundo**: su ventana de entrada dura 120 s y su
salida es al minuto exacto. Con un temporizador de 60 s puede **perder el evento entero**, sin error
y sin rastro. Descomentar `USAR_TELEMETRIA` sin más es suficiente para provocarlo.
- **Fix:** devolver el reloj a 1 s justo después del anuncio (ver `docs/08` §4). Aplicado en
  `TokioReversal_v1_telemetria.mq5`; **pendiente en v2 y v3**.

### 🟡 Medios

**M1 — La ventana de entrada era de 5 minutos, no 2.** La condición `t.min < 55` (con hora==9) aceptaba
**09:55–09:59:59**, no los "09:55–09:56:59" del comentario. Riesgo real: si el EA reinicia tarde en día
gotobi, entra a los 4-5 min del fix, **fuera del edge medido**.
- **Fix:** cerrar la ventana (`t.min > 56` → return).

**M3 — El SL en la orden podía ser rechazado por `STOPS_LEVEL`.** Si el broker exige distancia mínima
de stop y por redondeo/spread el SL queda muy cerca, `OrderSend` devuelve **10016** y no abre. El SL
aquí es secundario (la salida real es por tiempo), pero un rechazo mata el evento.
- **Fix:** respetar `SYMBOL_TRADE_STOPS_LEVEL` (ampliar el SL si hace falta). Alternativa más robusta:
  abrir a mercado **sin SL** y ponerlo con `PositionModify` justo después.

**M2 — `g_ultimoDiaOperado` no persiste.** Es una global en memoria; al reiniciar el terminal/EA se
resetea. La salvaguarda `TicketMio()!=0` protege mientras la posición viva, pero el "1 trade/día" y el
"skip honesto" se pierden ante reinicio.
- **Fix:** persistir con `GlobalVariableSet`/`Get`.

**M5 — Sin reintento ante rechazos transitorios.** Un requote/price-off en el segundo del fix = 0 trade
ese día (la entrada solo hace `Print` y no reintenta).
- **Fix:** loop de 2-3 reintentos dentro de la ventana ante `REQUOTE`/`PRICE_OFF`/`PRICE_CHANGED`,
  refrescando el tick, sin marcar el día como operado hasta lograr fill o agotar reintentos.

### 🟢 Menores
Guarda de `lotStep > 0` antes de dividir; `SlippagePoints=50` (5 pips) es generoso — bueno para
asegurar el fill, pero es justo lo que quieres *medir*; telemetría estructurada de cierres tras
`#ifdef` (desactivada por defecto).

---

## Estado en `TokioReversal_v1_exness.mq5` (v1.10)

| Fix | Estado |
|---|---|
| C1 (`TimeTradeServer`) | ✅ aplicado |
| C3 (`SetTypeFillingBySymbol`) | ✅ aplicado |
| M1 (ventana 55–56) | ✅ aplicado |
| M3 (stops level) | ✅ aplicado |
| C4 (reloj vs telemetría) | ✅ aplicado en `v1_telemetria` |
| C2 (offset dinámico DST) | ⏳ recomendado (pendiente) |
| M2 (persistencia) | ⏳ recomendado (pendiente) |
| M5 (reintentos) | ⏳ recomendado (pendiente) |

**Importante:** v2 y v3 comparten la misma base (`HoraJST`, ausencia de `SetTypeFilling`, misma
ventana y falta de persistencia), así que C1, C2, C3, M1, M2, M3 y M5 aplican igual cuando llegues a
ellas — y **C4 además muerde en cuanto enciendas la telemetría en cualquiera de las dos**.

## La meta-lección
El backtest valida la **regla**; el forward valida la **ejecución**. Un edge correcto puede morir por
un filling rechazado, un reloj congelado o un offset de DST — cosas que no aparecen en ningún gráfico.
Endurecer la ejecución no es opcional: es la mitad del trabajo de llevar un sistema a producción.

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — la regla se congela; la ejecución se audita.

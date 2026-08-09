# El protocolo forward — cómo se valida esto de verdad

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)**

El backtest (dos feeds independientes) solo compra una cosa: **el derecho a un forward test en
demo**. Este documento es el protocolo exacto — cópialo para tus propios sistemas.

## Por qué el forward es innegociable

- El backtest no mide TU ejecución real (slippage, spread en el instante exacto, caídas de VPS).
- El backtest no puede medir el futuro del mecanismo (¿el flujo sigue? ¿se masificó el lado corto?).
- Y sobre todo: sin un corte pre-firmado, siempre encontrarás razones para seguir "un mes más".

## El pre-registro del forward (firmado ANTES del primer trade)

| Elemento | Valor |
|---|---|
| Vehículo | EA v3 (canasta 5 patas), cuenta DEMO, balance virtual ≥$3.000 |
| Riesgo | 0.25% por EVENTO (repartido automáticamente entre patas) |
| Regla | CONGELADA (la del pre-registro). Cualquier cambio = reinicio del reloj |
| **Corte** | **60 eventos** (~11 meses) |
| Criterio de edge | Esperanza neta > 0 con IC95 · consistente con la banda del backtest (+1.3 a +2.1 pips/pata) |
| Criterio de ejecución | Slippage medio < 0.5 pips · spread en el fix dentro de lo medido |
| Salida por ARRIBA | → cuenta real pequeña, riesgo 1%/evento, escalera hasta 2% con historial propio |
| Salida por ABAJO | → se archiva con sus datos. Sin "una versión más" que no reinicie todo |

## La "sombra": medir variantes SIN operarlas

El EA opera la salida 10:10 (regla primaria) y **registra** el precio de las 10:15 sin operarlo.
Una posición, dos mediciones: al corte, la salida alternativa tiene su propio veredicto forward
gratis. Lo mismo aplica al sizing por volatilidad (hipótesis declarada): se evalúa en sombra sobre
los eventos del forward. **Nada se adopta en vivo hasta que su sombra Y el feed independiente
coincidan en aprobarlo.**

## Taxonomía de fallas durante la ventana (qué se toca y qué no)

| Qué falla | Qué se hace |
|---|---|
| Bug de implementación (el código no hace lo que la regla declara) | Se arregla YA — reloj intacto |
| La regla "parece" mala (racha, n chico) | Se ANOTA y se decide en el corte |
| Falla catastrófica demostrada del mecanismo | Se detiene, aceptando que el reloj muere |

## Los riesgos residuales, dichos de antemano

1. **Intervención del MoF en el minuto del fix**: el stop puede deslizar más allá de 20 pips.
   Raro, acotado, y la dirección de intervención suele favorecer al corto — pero existe.
2. **Masificación**: hay EAs comerciales japoneses en el lado corto. El corte forward y la
   re-verificación ANUAL del edge son la defensa — un edge de flujo se alquila, no se compra.
3. **Cambio estructural**: si Japón cambia la costumbre de liquidación gotobi (o el fixing),
   el mecanismo muere de raíz. Señal: el diferencial vs control colapsa.

## El error que este protocolo te impide cometer

Sin fecha de corte, un forward "prometedor" se opera con tamaño creciente hasta que la primera
racha mala (que ES normal: 8 pérdidas seguidas están dentro de lo esperado) te saca con el riesgo
máximo puesto. El protocolo invierte eso: **tamaño mínimo mientras no hay veredicto, y el veredicto
tiene fecha.**

---
🎓 Aprende a montar forwards con telemetría y cortes pre-registrados en
**[www.InstitutoQuant.com](https://www.InstitutoQuant.com)**

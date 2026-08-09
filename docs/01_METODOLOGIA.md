# La metodología — el método replicable detrás del hallazgo

> Del caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) · Aprende el método completo: **[matricúlate aquí](https://www.InstitutoQuant.com)**

Este documento decanta el MÉTODO. Si entiendes esto, puedes repetir el proceso sobre cualquier
mercado — y sobre todo, puedes dejar de auto-engañarte, que es el 90% del oficio.

## Los 7 principios (en orden de importancia)

### 1. Mecanismo primero, patrón después
No se buscó "un patrón que funcione". Se preguntó: **¿quién está OBLIGADO a operar, cuándo, y quién
paga por ello?** Respuesta: importadores japoneses liquidando facturas en USD los días gotobi,
con bancos cubriendo esa demanda hasta el fixing de las 9:55 JST. El flujo es *insensible al precio*
(pagan por costumbre comercial, no por alpha) → la presión y su resaca son predecibles.
**Un edge sin mecanismo causal es una coincidencia esperando su muerte.**

### 2. Pre-registro: las reglas y los criterios se escriben ANTES de ver los datos
Antes de correr cada test se declaró por escrito:
- La regla EXACTA (hora de entrada, salida, stop, calendario) — congelada, de fuente externa
- Los criterios de PASA/FALLA (ej.: media > +1 pip, t ≥ 2.5, ≥5/7 años positivos)
- La familia completa de tests que se iban a correr (para el ajuste de multiplicidad)

Si defines el éxito después de ver el resultado, siempre "ganas" — y siempre es mentira.

### 3. Familias declaradas: cada test compra un boleto de lotería
Probar 20 ideas y publicar la que salió verde = garantía de falso positivo. Aquí cada tanda se
declaró como familia ANTES de correr (ej.: "familia de 5: pata larga nocturna, AUDJPY, CHFJPY,
CADJPY, fix de Londres") y la significancia se juzgó contra el tamaño de la familia (Bonferroni:
con 5 tests, exige p < 0.01, no p < 0.05).

### 4. La falsación es el trabajo; el hallazgo es el subproducto
De ~20 tests corridos, **la mayoría murió** — y cada muerte quedó documentada con números para que
nadie la reabra. Ejemplos del caso:
- El lado largo pre-fix (el famoso): diferencial vs control +0.02 pips → arbitrado a cero
- El calendario con feriados japoneses (práctica estándar del gremio): los días "adelantados" dan −1.7 pips
- El fade del fix de Londres: bruto ≈ 0, el costo lo entierra
- 14 variantes de salida sobre otra señal: la única verde en IS dio −0.06R en OOS (así se ve el ruido)
**Un "no" bien medido vale tanto como un "sí": cierra puertas para siempre.**

### 5. El grupo de control separa el mecanismo del ruido
El short post-fix se midió también en los días SIN gotobi (mismas horas): −0.4 pips. El efecto vive
en el CALENDARIO, no en la hora. Sin control, habrías atribuido al gotobi lo que era de la sesión.

### 6. Réplica en datos independientes — o no cuentes el verde
Regla dura: **ningún positivo es creíble sin replicarse en datos que no se usaron para encontrarlo.**
Aquí: el hallazgo salió de datos de un broker (Exness M1); la réplica se corrió sobre ticks de
Dukascopy (feed suizo independiente) con la regla congelada y criterios pre-firmados. El backtest
de un solo feed puede estar contaminado por artefactos del feed.

### 7. El forward es el único juez final
Todo lo anterior solo compra el derecho a un **forward test en demo** con corte pre-registrado
(aquí: 60 eventos, ~1 año) y criterios firmados antes del primer trade — incluyendo criterios de
EJECUCIÓN (slippage medio < 0.5 pips) que solo la realidad puede medir. Sin fecha de corte y
salidas aceptadas de antemano, un forward es solo esperanza con gráficos.

## Los auto-engaños que este caso cuantificó (apréndetelos)

| Trampa | Cómo se ve | Medida en este caso |
|---|---|---|
| **Backtest sobre Heikin Ashi** | "Las velas HA filtran ruido" | La MISMA señal: −0.04R ejecutando a precios reales vs **+0.42R (PF 1.7, t=8!)** ejecutando a precios HA — que NO existen. +0.46R de pura ficción |
| **Optimizar salidas/parámetros** | 14 variantes, una da verde | La verde del in-sample (+0.011R) dio **−0.06R** out-of-sample |
| **Adoptar la práctica del gremio sin medir** | "Los japoneses ajustan por feriados" | El ajuste RESTA (−1.7 pips en los días adelantados) |
| **Creer al que vende el EA** | "Alta volatilidad = evitar" | INVERTIDO: vol alta = +3.9 pips, vol baja = +0.5 |
| **Contar patas correlacionadas como diversificación** | "5 pares = 5 fuentes de edge" | Correlación 0.83–0.92 entre patas: es UNA apuesta en 5 sabores. Alisa, no multiplica |
| **Sizing que miente** | "Riesgo 1%" con lote clavado en tope/mínimo | El riesgo real medido variaba 4× sin que el operador lo supiera |

## El flujo de trabajo con IA (replicable)

1. **Falsar lo obvio primero** (barato): porta/prueba lo que ya tienes sobre el mercado nuevo.
2. **Investigar mecanismos**: papers académicos (NBER/SSRN/JMCB) + sondeo de comunidades (X vía
   Grok, incluyendo el idioma local del mercado — el japonés aquí valió oro). Prompts en `03_PROMPTS.md`.
3. **Declarar familia + pre-registrar** reglas y criterios.
4. **Testear con costos reales** (medidos de ticks, no supuestos) y grupo de control.
5. **Endurecer el verde**: por año, por subgrupo, stress de costos, con/sin cada componente.
6. **Expandir por declaración externa** (otras patas/eventos que el mecanismo predice), nunca por minería.
7. **Replicar en feed independiente.**
8. **Forward con corte firmado.** Y solo entonces, capital.

---
🎓 Este método se enseña completo, con casos en vivo, en **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)**

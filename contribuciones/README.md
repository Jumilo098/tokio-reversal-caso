# Contribuciones de la comunidad

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)**

Este directorio recoge el trabajo que **estudiantes del Instituto Quant** hicieron sobre el caso
después de publicarlo: auditorías de código, backtests independientes y experimentos deliberados.
Es la parte del método que no se puede escribir sola — **la réplica y la falsación por terceros**.

Cada aporte se publica **tal como lo entregó su autor**, con su nombre y su crédito. Lo único que
edita este repositorio es el saneo de datos personales antes de hacerlos públicos (ver más abajo).
Lo que sigue a cada ficha no es un adorno: es la **lectura crítica** del caso sobre ese aporte —
qué aporta, y qué NO se debe leer en sus números. Un aporte que se publica sin sus límites al lado
se convierte en la trampa que este repo enseña a evitar.

---

## 1. Andrés Xi — Sobreoptimización deliberada (12-ago-2026)

📁 [`andres-xi-sobreoptimizacion/`](andres-xi-sobreoptimizacion/)

Andrés amplió el espacio de búsqueda de la regla **después** de ver los resultados del primer
ejercicio, y lo documentó llamándolo por su nombre: **sobreoptimización**. Barrió 3.584
combinaciones (4 temporalidades × 896) variando el número de velas previas a la entrada
(`entryLeadBars` 0→15), el stop (5–35 pips), la hora de salida (10:00–10:30) y siete escenarios de
gestión TP/SL.

**Qué contiene:** el script Python completo (2.171 líneas, con auto-instalación de dependencias y
dashboard HTML), el informe de 17 páginas, y el paquete entero de resultados — todas las
combinaciones, los top-20, el log de trades, las curvas de equity y los gráficos de estabilidad.

**Por qué vale la pena leerlo.** Es lo contrario de lo que hace el 99% del retail: en vez de
enseñar la ganadora, Andrés enseña el **experimento** y lo etiqueta como in-sample. Sus propias
conclusiones (§4.3) dicen que los nuevos máximos *"deben considerarse candidatos in-sample, no
parámetros mejores en sentido prospectivo"*, y §4.4 propone el paso correcto siguiente: congelar
candidatos y someterlos a datos no usados en la selección. Ese es exactamente el método de
`docs/01`. Además el resultado es honestamente **mixto** —en 5M y 15M la ampliación no mejoró
nada— y publicar el empate es más difícil que publicar la victoria.

### ⚠️ Cómo NO leer estos números

Las tablas del informe muestran Profit Factor 4,77 y +27R neto. **No son comparables con el
+1,32 pips del caso principal**, y no lo son por cuatro razones que hay que tener delante:

| Límite | Detalle |
|---|---|
| **N=24 operaciones** | Todas las configuraciones ganadoras tienen 24 trades. 3.584 evaluaciones sobre 24 operaciones: el ganador de ese barrido es, casi por construcción, ruido con suerte. El caso principal usa 436 eventos y aun así depende de su cola (ver `docs/06`). |
| **114,8 días de histórico** | Menos de cuatro meses, contra los 6,6 años del caso. No hay ni un ciclo de régimen ahí dentro. |
| **Cero costos** | El informe lo declara (§2.7): no modela spread, comisión, slippage ni gaps. Y los ganadores usan **stop de 5 pips** — con el costo de 1,1 pips del caso, la fricción se come el 22% de la unidad de riesgo en cada operación. El propio informe marca esos stops como "especialmente sensibles a fricciones de ejecución". |
| **El ganador abandona el mecanismo** | Esta es la lección grande, y no está en el informe: las configuraciones ganadoras entran en **09:41–09:46 JST**, es decir **ANTES del fixing**. Pero el caso mide que el lado pre-fix está *arbitrado a cero* (`docs/02`) y que lo único vivo es la resaca posterior. El optimizador, dejado suelto, se fue del lado del mercado que tiene causa hacia el que no la tiene — y subió el Score haciéndolo. **Cuando el óptimo numérico contradice el mecanismo, gana el mecanismo.** |

**Cómo usarlo en clase:** como demostración en vivo de por qué el pre-registro existe. El aporte
de Andrés no es la configuración ganadora — es la prueba de que se puede fabricar una ganadora
espectacular en tarde y media, y de que un autor honesto la etiqueta antes de que alguien la
confunda con un edge.

---

## 2. Eduard Burbano — Auditoría de código y forward independiente (12-ago-2026)

📁 [`eduard-burbano-labtest/`](eduard-burbano-labtest/)

Eduard pasó el `TokioReversal_v3.mq5` por su propio laboratorio de auditoría de EAs, encontró
5 fallos, los corrigió en una copia (`_LABTEST`, sin tocar el original), corrió un backtest
independiente en su propio terminal y **arrancó su propio forward en demo** con corte
pre-registrado a 60 eventos de calendario.

**Qué contiene:** el informe de auditoría y validación, y el `.mq5` v3.03-LABTEST con los cinco
fixes documentados línea por línea en la cabecera.

### Lo que encontró (y confirma de forma independiente)

| # | Hallazgo | Estado en el caso |
|---|---|---|
| C1 | **DST**: el offset servidor→UTC fijo no maneja el horario de verano del broker | Coincide con C2 de `docs/09`, que estaba **pendiente**. Eduard lo resuelve derivando la hora de `TimeGMT()+9h` |
| C2 | El gate "solo demo" era un `Print()`, no un bloqueo | **Hallazgo nuevo.** Su versión devuelve `INIT_FAILED` en cuenta real salvo que el operador ponga `AceptoOperarReal=true` a mano |
| C3 | `CTrade` mandaba FOK sin comprobar qué admite el símbolo | Coincide con C3 de `docs/09` (ya arreglado en `v1_exness`, pendiente en v3) |
| A4 | **`MinutosHold` era un input muerto**: la hora de cierre estaba hardcodeada | **Hallazgo nuevo, confirmado.** Afecta a los cuatro EAs del repo |
| A5 | Documentación vs código: el header decía "solo gotobi" mientras el código operaba también fin de mes | Real. Su versión lo declara explícitamente en la regla congelada |

Su backtest independiente (USDJPYm/EURJPYm/GBPJPYm, nov-2021→ago-2026, n=352–356) **replica el
grupo de control casi exacto**: −0,40 pips en USDJPY, contra el −0,4 que reportó este repo por su
cuenta. Dos laboratorios distintos, el mismo número. Eso es réplica de verdad.

Además hizo algo que este repo no había hecho: **igualar la ventana de calendario entre patas**
antes de comparar. En su primera pasada GBPJPY parecía sobrevivir el umbral por tener 3× más
historial acumulado, no por mejor edge; al igualar las series el efecto desapareció. Es una
corrección de multiplicidad que merece entrar en el método.

### ⚠️ Dónde discrepa del caso (a resolver, no a esconder)

1. **Cambió la regla en marcha: 10:10 → 10:15.** Lo justifica con un test pareado sobre la sombra
   (t pareado 6,37/10,80/10,25) y lo reconfirma con un backtest real. El dato es sólido, pero
   `docs/06` §7.4 advierte exactamente contra esto: elegir entre dos variantes cercanas por su
   resultado es el tipo de selección que la metodología marca. Su forward mide ahora una regla
   distinta a la del pre-registro de este repo, así que **los dos forwards no son sumables**.
2. **La sombra que usó para decidir está sesgada.** Mide `(entrada − bid)` sin restar comisión,
   pero cerrar un corto se paga **al ask**. La salida tardía sale favorecida en ~1 spread + la
   comisión frente a la regla que sí se opera. Eduard detectó una parte del problema (que la
   sombra no simula el riesgo de stop) y lo cubrió con un backtest real — bien —, pero el sesgo
   de precio sigue vivo en la sombra de 10:20 que está midiendo ahora.
3. **Riesgo 12× el pre-registrado.** Pasó de 0,25%/evento a 1,0%/pata (`RiskPorEvento=3.0`,
   `PatasActivas=3`) porque a $800 el lote siempre caía en el mínimo y el input de riesgo era
   decorativo. El razonamiento es correcto y está documentado — pero conviene decir en voz alta
   que su forward no corre el sizing firmado en `docs/04`.
4. **La ventana de entrada sigue abierta.** Su copia mantiene `t.min < 55` sin cota superior, así
   que un reinicio tardío puede entrar hasta las 09:59, fuera del edge medido. Es el fix M1 de
   `docs/09`, que sí está aplicado en `v1_exness` y no en esta rama.

---

## Saneo aplicado al publicar

- **`eduard-burbano-labtest/Informe_TokioReversal_v3_LABTEST.md`**: se redactó el número de cuenta
  demo y el nombre del servidor del broker que aparecían en la §6. No aportan nada al lector y son
  un identificador personal en un repositorio público.
- No se encontró ninguna otra credencial, clave ni dato personal en los dos paquetes.
- Los CSV de precios crudos **no** se incluyen (son datos de broker, no redistribuibles). El
  paquete de Andrés contiene resultados y gráficos, no el histórico de origen.

## Licencia y crédito

Ambos aportes conservan la atribución al material original (CC BY-NC 4.0, ver `../LICENSE.md`) y
**el crédito de su autor**: el trabajo, los números y las decisiones de diseño de cada carpeta son
de Andrés Xi y de Eduard Burbano respectivamente.

## ¿Quieres aportar el tuyo?

Lo que este repo valora, por orden: una **réplica en datos que no usamos**, una **falsación con
números**, una **auditoría de código** que encuentre lo que se nos pasó, o un **forward propio con
corte firmado antes de empezar**. Un "no" bien medido entra igual que un "sí".

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — un caso se estudia en serio cuando otros intentan romperlo.

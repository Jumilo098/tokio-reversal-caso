# FAQ del estudiante — montar el forward y las dudas que siempre surgen

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)**

Preguntas reales que aparecen al pasar del backtest al forward. Las respuestas no son opiniones: se
apoyan en el mecanismo del edge y en la metodología del caso (`01_METODOLOGIA.md`). Si algo aquí
choca con tu intuición, ese choque **es** el aprendizaje.

---

## ❓ ¿Por qué cierra por tiempo (10:10) y no le pongo un trailing stop para dejar correr las ganancias?

La pregunta más común, y va al corazón del caso. **El trailing stop rompería justo lo que hace que el
edge exista.**

- **El edge es una reversión ACOTADA EN EL TIEMPO, no un movimiento que haya que "dejar correr".** El
  flujo de importadores termina en punto a las 09:55; su resaca se descarga en los ~15 minutos
  siguientes. Después de 10:10–10:15 **el mecanismo se agotó**: ya no hay edge, solo una posición
  USDJPY expuesta a todo lo demás.
- **Aquí el reloj es el gestor de riesgo, no el precio.** El estudio lo midió: *"las pérdidas casi
  nunca llegan al stop — el tiempo las corta antes"*. El stop de 20 pips es un airbag, no la salida.
- **El trailing es herramienta de MOMENTUM; esto es REVERSIÓN.** El trailing paga cuando el movimiento
  *persiste* (tendencia). La resaca revierte y rebota — un trailing te sacaría devolviendo la ganancia
  justo en la vuelta, y te mantendría en la zona sin edge.
- **Cambiar la salida invalida TODAS las cifras.** El +2.1 pips, t=4.26, 6/7 años, la réplica — todo
  se calculó con salida por tiempo. La cambias y estás forward-testeando una estrategia que **nunca
  backtesteaste**, y rompes el pre-registro de 60 eventos.
- **Los datos ya exploraron alargar la salida:** 10:10 vs 10:15, y el óptimo está en ~15–20 min. Si
  aguantar más pagara, se habría visto. Que el punto dulce sea corto **confirma que el edge está
  acotado**.

**¿Y si aun así quiero probar el trailing?** Bien — pero **como hipótesis nueva, medida en datos
primero, no en vivo sobre el forward.** El `TokioReversal_v2.mq5` incluye una **"sombra"**: mide una
salida alternativa *sin operarla*. Backtesteas la variante (in-sample → out-of-sample, declarada como
familia); si sobrevive OOS, *entonces* pre-registras una v2. Meterle trailing al forward en marcha es
convertir un test pre-registrado en tinkering discrecional — la trampa #1 del oficio.

---

## ❓ ¿Puedo "apoyar" esta estrategia sobre otro sistema que ya corro (p. ej. uno de tendencia)?

**Estratégicamente sí tiene sentido — de hecho es el diseño original** (la pregunta de partida fue si
existía un edge JPY *no correlacionado* con un sistema de tendencia). Por qué encaja:

- **Estilos complementarios:** un sistema de tendencia es *momentum*; Tokio es *reversión*. Ganan en
  **regímenes distintos** (tendencia vs chop). Es diversificación de estilo, no solo de instrumento.
- **Correlación estructuralmente baja:** distinto activo, distinto driver (macro vs flujo de fixing),
  distinta hora (15 min a las 09:55 JST vs todo el día). Sumar dos expectativas positivas poco
  correlacionadas **sube el Sharpe del conjunto**.
- **Footprint mínimo:** posición diminuta, 15 min, sin overnight → no le compite margen al otro sistema.
- **Sin conflicto técnico:** cada EA filtra sus posiciones por **símbolo + número mágico**, así que no
  se tocan entre sí aunque compartan cuenta.

**Pero respeta la secuencia (medir > creer):**
1. **Valida Tokio solo primero.** No mezcles un sistema probado con uno sin forward.
2. **Mide la correlación REAL**, no la asumas: cuando tengas ambos operando en la misma ventana,
   calcula la correlación de retornos. Espéras ≈0, pero verifícalo.
3. **Solo entonces** los fusionas como overlay, con el peor caso combinado dimensionado.

**Matiz honesto:** una sola pata (USDJPY) es fina. El overlay potente no es "USDJPY sobre tu sistema",
sino **"canasta de 5 patas JPY sobre tu sistema"** — pero eso llega después de validar la pata base.

---

## ❓ ¿Cuánto capital le pongo? ¿Y qué apalancamiento?

- **El sizing es por RIESGO contra el stop, no por apalancamiento.** El EA calcula el lote para que la
  pérdida al stop de 20 pips = `RiskPercent` del balance. El apalancamiento casi no importa (posición
  chica, 15 min, sin overnight). No subas el apalancamiento "por si acaso": no cambia tu riesgo aquí.
- **El capital de la demo debe ESPEJAR tu plan real.** Si piensas operar con X, haz la demo con X — así
  el forward refleja tu sizing verdadero.
- **Cuidado con el lote mínimo en cuentas chicas:** con poco capital y `RiskPercent` bajo, el cálculo
  puede caer por debajo del lote mínimo (0.01) y **redondear hacia arriba** → tu riesgo real termina
  siendo mayor (o menor) que el objetivo. Revísalo: el EA **loguea el riesgo real** cuando eso pasa.
  Ejemplo: capital pequeño + 0.25% puede forzar 0.01 lote y dejar el riesgo efectivo por debajo del
  objetivo — aceptable, pero **hay que saberlo**, no asumirlo.

---

## ❓ ¿Cuenta Raw o Standard?

- **Raw Spread** espeja el modelo de costo del estudio (comisión + spread ≈ 0) → forward más fiel al
  backtest.
- **Standard** también sirve **si** su spread en la hora del fix es ≈ 1 pip (equivalente al costo Raw).
- La regla real: **mide el costo de TU cuenta a las 09:55 JST** y decide con ese número, no con la
  etiqueta. (Ver `06_AUDITORIA_INDEPENDIENTE.md`, sección 5.)

---

## ❓ ¿Demo dedicada o la mezclo con lo que ya tengo corriendo?

**Dedicada.** El forward del caso pide 60 eventos con **curva de equity limpia**. Si mezclas Tokio con
otro sistema en la misma cuenta, no puedes leer su desempeño por separado — que es justo lo que quieres
medir. Además, una cuenta/instancia aislada evita líos de doble ejecución (local vs hosting). Fusionar
sistemas es una decisión **posterior** a validar, no una comodidad de arranque.

---

## ❓ ¿VPS o lo dejo en mi PC?

- **Local sirve** para probar la plumbing una noche — **pero tu PC no puede dormirse** antes de la
  salida, o no hay trade. Entrada 09:55 JST / salida 10:10 JST: la máquina debe estar despierta en esa
  ventana.
- **VPS (virtual hosting)** es lo correcto para un forward serio de ~1 año: corre 24/7 sin depender de
  que tu PC esté encendido. Para una entrada a hora fija diaria en días gotobi, si vas en serio, VPS.
- Un terminal MT5 solo puede estar logueado en **una cuenta a la vez**: para correr esto sin tocar otro
  sistema, usa una **segunda instancia (portable)** o una cuenta/terminal aparte.

---

## ❓ Si entra hoy y gana (o pierde) un trade, ¿ya sé algo?

**No.** El edge es +1–2 pips de media con **varianza enorme**: un solo evento es casi una moneda al
aire. Por eso el corte pre-registrado es **60 eventos (~1 año)**, no 1 ni 5. Un trade solo prueba la
*plumbing* (que el EA entra, sale y calcula bien), no el edge.

---

## ❓ ¿Qué mido en el forward, además de los pips?

Los pips son lo de menos al principio. Lo que el forward valida y el backtest **no puede**:

- **Slippage de ejecución real** (criterio pre-firmado: < 0.5 pip). Entrar a mercado en el minuto del
  fix puede costar más de lo que asume el backtest.
- **% de skips por spread** (el EA no opera si el spread ≥ 3 pips en el fix — skip honesto).
- **Diferencia backtest vs. realidad** por evento: ¿el trade real se parece al simulado?
- **Disciplina:** ¿respetaste el corte de 60 y los criterios firmados, o los moviste al ver los
  resultados?

---

## Checklist de arranque (genérico)

1. **Compila** el EA en tu terminal (o instancia portable dedicada).
2. **Cuenta/instancia aislada** del resto de tus sistemas (métricas limpias).
3. **Símbolo correcto:** puede llamarse `USDJPY` o `USDJPYm` según el tipo de cuenta — el EA matchea
   ambos por `SymbolLock`. Adjúntalo al que muestre tu cuenta.
4. **Verifica el offset servidor→UTC** (input `ServerToUTC_Horas`). Si tu broker no está en UTC, la
   hora del fix se corre y el test es basura. Compáralo antes de armar.
5. **Algo Trading activo** y "permitir Algo Trading" en el EA (carita sonriente en el gráfico).
6. **PC despierto o VPS** cubriendo la ventana 09:55–10:10 JST.
7. **Criterios de corte firmados ANTES** del primer trade (media, t, años, slippage). Sin fecha de
   corte y salidas aceptadas de antemano, un forward es solo esperanza con gráficos.

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — el forward es el único juez final.

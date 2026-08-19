# Tokio Reversal — Caso de estudio completo de búsqueda de edge con IA

> **Un caso real del [Instituto Quant](https://www.InstitutoQuant.com):** cómo se encontró, se midió,
> se intentó destruir y se pre-registró una anomalía de mercado en pares JPY — en una sola jornada
> de trabajo asistido por IA, con cada paso documentado y replicable.
>
> 🎓 **¿Quieres aprender a hacer esto?** Matricúlate en **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)**

---

## ⚠️ Léeme primero (honestidad ante todo)

Este repositorio es **material educativo**. No es asesoría financiera, no es una promesa de
rentabilidad, y el sistema documentado aquí estaba —al momento de publicar— **en fase de
validación forward** (demo, corte pre-registrado de 60 eventos). Un backtest no es una promesa:
es una sola trayectoria histórica. Si algo aprenderás aquí, es exactamente eso.

## El hallazgo, en una frase

**Vender USDJPY (y sus hermanos JPY) en el minuto exacto del fixing de Tokio (9:55 JST), solo los
días gotobi (5/10/15/20/25/30) y fin de mes, cubriendo 15 minutos después** — cosecha la resaca del
flujo de importadores japoneses que termina, en punto, a las 9:55.

| Métrica (backtest 2020–2026, neto de costos) | Valor |
|---|---|
| Eventos por año | ~67 |
| Pips netos por trade (pata USDJPY) | **+2.1** (t=4.26) |
| Canasta 5 patas, R/año | **+8.3 a +10.6** |
| Años positivos | 6/7 (salida 10:10) · **7/7** (salida 10:15) |
| Max drawdown en 6.6 años | **−2.4R** |
| Sharpe anualizado | **~2.1–2.4** |
| Exposición | 15 minutos por evento, sin overnight, sin swap |

**Y el detalle que lo hace creíble:** el lado *cómodo* de esta anomalía (comprar la subida previa
al fix, que es lo que hace todo el mundo) está **muerto — arbitrado a cero**. Solo sobrevive el
lado incómodo: vender contra el último aliento del flujo institucional. Medimos ambos.

## Qué hay en este repositorio

```
├── docs/
│   ├── 01_METODOLOGIA.md    ← EL documento: el método replicable (pre-registro, familias, falsación)
│   ├── 02_HALLAZGOS.md      ← todos los números: lo que funcionó Y lo que murió (igual de valioso)
│   ├── 03_PROMPTS.md        ← los prompts exactos de investigación (Grok/X, literatura académica)
│   ├── 04_PROTOCOLO_FORWARD.md ← cómo se valida esto de verdad (demo, corte, criterios firmados)
│   ├── 05_STACK.md          ← el mapa de la sala de máquinas: cada herramienta, su rol y su costo
│   ├── 06_AUDITORIA_INDEPENDIENTE.md ← cómo un tercero re-verificó Y cuestionó el caso (¡léelo!)
│   ├── 07_FAQ_FORWARD_ESTUDIANTE.md  ← dudas frecuentes al montar el forward (trailing, capital, VPS…)
│   ├── 08_TELEMETRIA_Y_FORWARD.md    ← qué medir en el forward + primer evento real auditado end-to-end
│   └── 09_ENDURECIMIENTO_EA.md       ← revisión de ejecución del EA (filling, reloj, DST…) para Exness
├── ea/
│   ├── TokioReversal_v1.mq5 ← la regla pura (1 pata, gotobi, salida 10:10)
│   ├── TokioReversal_v1_exness.mq5 ← v1.10: MISMA regla, ejecución endurecida (ver docs/09)
│   ├── TokioReversal_v1_telemetria.mq5 ← v1.20: v1.10 + telemetría al hub, con el fix C4 del reloj
│   ├── TokioReversal_v2.mq5 ← + fin de mes + "sombra" de la salida alternativa (medir sin operar)
│   └── TokioReversal_v3.mq5 ← canasta de 5 patas calificadas con riesgo por evento
├── backtest/
│   ├── nakane_backtest.py   ← arnés completo replicable (MetaTrader5 + Python)
│   ├── dukascopy_replica.py ← réplica en feed independiente (la prueba de fuego)
│   └── verificar_dataset.py ← auditoría reproducible: recalcula el CSV + spot-check de ticks
├── data/
│   ├── resultados_replica_dukascopy.csv ← el dataset del veredicto (436 días, verificable)
│   └── EVENTOS_AUSENTES.md  ← los 32 gotobis ausentes (468 vs 436): cobertura y trazabilidad
├── forward/
│   ├── bitacora_forward.csv ← el conteo real hacia los 60 eventos (evento 1 registrado)
│   └── README.md            ← columnas, criterios de corte firmados y estado
└── contribuciones/          ← lo que ESTUDIANTES hicieron con el caso (réplicas, auditorías, falsaciones)
    ├── andres-xi-sobreoptimizacion/  ← 3.584 combinaciones: cómo se fabrica una ganadora falsa
    └── eduard-burbano-labtest/       ← auditoría de código (5 fallos) + forward independiente
```

## La historia en 10 pasos (cómo se llegó aquí en un día)

1. **Pregunta inicial:** ¿existe un edge en USDJPY no correlacionado con un sistema de tendencia en oro?
2. **Falsación masiva primero:** se probaron y ENTERRARON con datos: la señal de tendencia portada
   (0/7 años positivos netos), 14 variantes de salida (la única verde en IS murió en OOS), Fibonacci
   y Heikin Ashi (y se cuantificó el auto-engaño de backtestear sobre velas HA: +0.42R de edge FICTICIO).
3. **Investigación de mecanismos:** literatura académica (NBER, JMCB) + sondeo de X vía IA → anomalías
   de FLUJO con causa real: el fixing de Tokio y los días gotobi.
4. **Pre-registro:** reglas y criterios de éxito escritos ANTES de tocar los datos.
5. **Primer test:** el lado famoso (long hacia el fix) = muerto. El lado incómodo (short post-fix) = vivo
   (t=4.4) y FORTALECIÉNDOSE (2025 fue su mejor año).
6. **Endurecimiento:** por año, por día, stress de costos ×2, con y sin stop, spread real medido de ticks.
7. **Expansión declarada:** el efecto replica en EURJPY, GBPJPY, CHFJPY (¡t=5.1 en GBPJPY!) y en fin de mes.
8. **Contra-verificación de la sabiduría del gremio:** el ajuste por feriados japoneses que usa el crowd
   RESTA (−1.7 pips); el "evitar volatilidad" de los EAs comerciales está INVERTIDO (la vol alta paga 8×
   más que la baja). Medir > creer.
9. **Réplica en feed independiente** (ticks Dukascopy) — porque ningún positivo es creíble sin datos
   que no se hayan usado.
10. **Forward:** EA compilado, demo con corte pre-registrado a 60 eventos, criterios firmados antes
    del primer trade. **El backtest propone; el forward dispone.**

## La comunidad ya lo está rompiendo (y eso es el punto)

Desde que se publicó, estudiantes del Instituto Quant tomaron el caso y le hicieron lo que se le
debe hacer a cualquier resultado: intentar romperlo. Su trabajo está en
**[`contribuciones/`](contribuciones/)**, con su nombre y con sus límites al lado:

- **[Andrés Xi](contribuciones/andres-xi-sobreoptimizacion/)** barrió 3.584 combinaciones y llamó
  al experimento por su nombre: *sobreoptimización*. Encontró configuraciones con PF 4,77 sobre
  **24 operaciones** y sin costos — y las etiquetó como candidatas in-sample en vez de venderlas.
  El detalle que lo corona: sus ganadoras entran ANTES del fixing, o sea que el optimizador se fue
  del lado del mercado que tiene mecanismo al que no lo tiene. *Cuando el óptimo numérico
  contradice el mecanismo, gana el mecanismo.*
- **[Eduard Burbano](contribuciones/eduard-burbano-labtest/)** auditó el EA, encontró **5 fallos**
  (dos que no estaban en `docs/09`: el gate "solo demo" que no bloqueaba nada, y el input
  `MinutosHold` que no hacía nada), los corrigió en una copia y arrancó **su propio forward** con
  corte firmado. Su grupo de control replicó el nuestro casi exacto: −0,40 pips contra −0,4.

Los dos aportes también **discrepan** del caso en cosas concretas, y esas discrepancias están
escritas, no escondidas. Léelas: es donde más se aprende.

## Lo que este caso enseña (más valioso que los pips)

- **El edge no estaba en un indicador** — estaba en un CALENDARIO y un RELOJ (flujo institucional recurrente).
- **Todo lo optimizable murió en out-of-sample.** Lo único que sobrevivió fue una regla externa congelada.
- **La medición honesta es la ventaja competitiva:** 15+ tests pre-declarados, cada puerta cerrada con
  datos, cada verde sometido a réplica. Así se busca edge en serio.
- **La IA multiplica al analista, no lo reemplaza:** investigación (X/papers), backtesting, falsación y
  documentación — todo en una jornada. Pero cada decisión de diseño y cada criterio fue humano.

---

## 🎓 Aprende a hacer esto tú mismo

Este caso salió del programa del **Instituto Quant**: trading algorítmico + IA, construyendo y
auditando sistemas reales en vivo con una comunidad que somete todo a réplica.

**→ Matricúlate en [www.InstitutoQuant.com](https://www.InstitutoQuant.com)**

*Material educativo. Los mercados conllevan riesgo de pérdida. Rendimientos pasados (y backtests)
no garantizan resultados futuros.*

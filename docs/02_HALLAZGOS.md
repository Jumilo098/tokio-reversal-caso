# Los hallazgos — todos los números (lo que vivió Y lo que murió)

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)** para aprender a producir esto

Todos los tests corridos sobre M1/ticks 2020–2026, netos de costos reales (comisión Raw ≈1.1 pips;
spread medido de ticks en la ventana exacta: ~0). Cada tanda fue **declarada como familia antes de
correr** (ver `01_METODOLOGIA.md`).

## ✅ Lo que VIVE

### El núcleo: short post-fix de Tokio (9:55→10:10 JST, solo gotobi)

| Feed | N | Media neta | t | Años + |
|---|---|---|---|---|
| Exness M1 | 399 | **+2.12 pips** | 4.26 | 6/7 |
| **Dukascopy ticks (réplica independiente)** | 436 | **+1.32 pips** | 2.74 | 6/7 |

- Win ~53–58% · las pérdidas casi nunca llegan al stop (el tiempo las corta antes)
- **Sin decay — al contrario**: 2020 ≈ 0 → 2025 el mejor año en ambos feeds
- Grupo de control (mismas horas, días no-gotobi): **−0.4 pips** → el efecto es del CALENDARIO
- Incondicional: no depende del run-up previo (r=−0.015), ni del día del mes, ni de nada medible antes

### La salida extendida (10:15) — declarada como secundaria, validada en ambos feeds

| Feed | Media | t | Años + |
|---|---|---|---|
| Exness | +2.23 (canasta: R/evento +0.157) | 6.09 | **7/7** |
| Dukascopy | **+1.89** | **3.46** | 6/7 |

### La familia de patas (regla de inclusión pre-declarada: t≥2.5 individual)

| Pata | Media neta | t | ¿Califica? |
|---|---|---|---|
| GBPJPY | **+2.85** | **5.09** | ✅ |
| USDJPY | +2.12 | 4.26 | ✅ |
| EURJPY | +2.26 | 4.70 | ✅ |
| CHFJPY | +1.76 | 4.04 | ✅ |
| CADJPY | +0.94 | 2.64 | ✅ justo |
| AUDJPY | +0.66 | 1.63 | ❌ excluida |

⚠ Correlación entre patas: **0.83–0.92** — es UNA apuesta en 5 sabores. La canasta aporta robustez
(no apostar a una sola pata), NO diversificación. No la vendas como lo que no es.

### Los eventos extra: fin de mes (último día hábil)
+3.33 pips (n=43, t=2.16) — consistente con lo que reportan las cuentas japonesas.

### La canasta completa (5 patas · gotobi + fin de mes · 442 eventos)
- Salida 10:10: R/evento +0.124 · t=5.3 · **R/año +8.3** · maxDD −2.4R en 6.6 años · Sharpe ~2.1
- Salida 10:15: R/evento +0.157 · t=6.1 · **R/año +10.6** · Sharpe ~2.4 · 7/7 años

### El condicionante hallado CONTRA la sabiduría del gremio
Los vendedores de EAs japoneses dicen "alta volatilidad = evitar". Los datos dicen lo contrario:

| Volatilidad previa (rango 1h) | Media | t |
|---|---|---|
| Baja (~12p) | +0.46 | 1.1 |
| Media (~22p) | +1.98 | 2.4 |
| **Alta (~42p)** | **+3.92** | **3.4** |

Más actividad = más flujo = más resaca. (Declarado como hipótesis v2.2; pendiente de sombra forward.)

## ❌ Lo que MURIÓ (igual de valioso — no lo reabras sin datos nuevos)

| Hipótesis | Resultado | Lección |
|---|---|---|
| **Long pre-fix 9:00→9:55** (lo que hace el crowd) | Diferencial vs control **+0.02 pips** (t=0.03) | El lado cómodo y famoso está arbitrado a CERO |
| **Long nocturno hacia el fix** (config de un quant público, OOS positivo 2022-26) | +3.6 global PERO 2023-25 muriendo (win 44-46%) | El lado largo entero está siendo arbitrado; solo el corto sobrevive |
| **Calendario con feriados JP (前倒し)** — práctica estándar japonesa | Días "adelantados": **−1.71 pips** | La práctica del gremio no aparece en el lado post-fix. Medir > imitar |
| **Fade del fix de Londres 4pm diario** (Evans 2018 documenta reversión) | Bruto ≈ 0; neto −1.04 (t=−5.1) | El efecto académico existe pero NO en tamaño cobrable retail |
| **Melvin-Prins fin de mes London fix** (condicional equities) | **−7.4 pips** (¡signo invertido!) | Un signo invertido NO se voltea post-hoc: sería hipótesis nueva |
| **Fibonacci pullback 50/61.8%** en otra señal JPY | −0.095/−0.120R (peor que la base) | Los retrocesos sufren selección adversa: te llenan cuando vas a perder |
| **Heikin Ashi "filtra ruido"** | Honesto: −0.04R · **Tramposo (ejecutando a precios HA): +0.42R, t=8** | El mayor generador de falsos edges del retail, cuantificado |
| **14 variantes de salida** sobre señal de tendencia | La única verde IS (+0.011R) dio **−0.06R** OOS | Así se ve el ruido cuando compras 14 boletos |
| **TTM vs spot como señal** | Nadie lo usa operativamente | Cerrada sin gastar test |
| **Fix del PBoC (USDCNH)** | Sin anomalía operable documentada | Cerrada por investigación |

## El patrón de fondo (la meta-lección)

De todo el ecosistema del fixing, **sobrevive exactamente lo que exige operar CONTRA el flujo
institucional en su último minuto** — todo lo que se podía surfear cómodamente está muerto.
Los mercados no dejan dinero en las partes fáciles; lo dejan donde duele recogerlo.

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — aprende a medir así, con casos en vivo.

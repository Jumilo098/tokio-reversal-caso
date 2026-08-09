# Auditoría independiente — cómo un tercero verificó (y cuestionó) el caso

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)** para aprender a auditar así

Un backtest publicado no vale por sus números, sino por lo que sobrevive cuando **otra persona
intenta romperlo**. Este documento recoge una auditoría independiente del caso: qué se re-verificó,
qué aguantó, y —más importante para un estudiante— **qué preguntas incómodas hay que hacerle al caso
antes de creerle**. Todo aquí es reproducible con los scripts de `backtest/`.

---

## 1. Re-cálculo del dataset publicado (¿los números cuadran consigo mismos?)

Primer paso, el más barato: recalcular las estadísticas **desde cero** sobre
`data/resultados_replica_dukascopy.csv`, sin usar el código original, solo la columna de pips.

| Métrica (réplica Dukascopy, USDJPY) | Publicado | Re-cálculo independiente |
|---|---|---|
| N (eventos gotobi) | 436 | 436 |
| Media neta | +1.32 pips | **+1.317** |
| t-stat | 2.74 | **2.73** |
| Win | ~53% | 53.4% |
| Años positivos | 6/7 | 6/7 (2020 el único negativo) |

Desglose por año (revela **de dónde** sale el edge):

| Año | N | Media | Win |
|---|---|---|---|
| 2020 | 71 | **−0.20** | 49% |
| 2021 | 63 | +0.15 | 52% |
| 2022 | 68 | +1.89 | 59% |
| 2023 | 66 | +0.69 | 50% |
| 2024 | 71 | +2.44 | 52% |
| 2025 | 65 | **+3.29** | 60% |
| 2026 (parcial) | 32 | +0.57 | 50% |

Acumulado ≈ +574 pips, drawdown máximo del acumulado ≈ −147 pips.

**Veredicto:** internamente consistente, sin inflado. **Lección técnica:** cuidado con `numpy.std()`,
que por defecto usa `ddof=0` (divide por N, no por N−1) y **sobreestima el t-stat**. Con N=436 el
efecto es ~0.1% (despreciable), pero con muestras chicas te puede regalar significancia falsa. Usa
`ddof=1` para el error estándar.

---

## 2. El hallazgo de la comunidad: cobertura incompleta y reproducibilidad rota

La auditoría independiente encontró dos cosas que el re-cálculo por sí solo no revela — y que son
**el mejor ejemplo del caso** de cómo un tercero fortalece un experimento:

**a) 32 eventos ausentes (468 vs 436).** El calendario gotobi 2020–2026 genera **468 eventos**; el
CSV publicado tiene **436**. Faltan **32** (0 sobrantes). No es un filtro de la señal: el script
descartaba **en silencio** (`if not t0 or not t1: continue`) los días sin ticks de Dukascopy en esa
corrida (festivos, huecos del feed, o fallos por rate-limit). Como el acceso es intermitente, **cada
corrida pierde días distintos** → la cobertura no era determinista.

**b) El script no guardaba el CSV.** `dukascopy_replica.py` calculaba e imprimía las estadísticas
pero **nunca escribía el CSV** (no había `to_csv`). Es decir, el artefacto publicado no se regeneraba
con el script publicado → la cadena de reproducibilidad estaba rota.

**Qué se hizo (arreglo, no excusa):**
- El script ahora **guarda** el CSV regenerado (`*_regen.csv`, sin sobrescribir el original, que se
  preserva como evidencia) y **reporta la cobertura**, listando los días sin datos. Sin truncamiento
  silencioso.
- Los 32 ausentes quedaron **identificados** en `data/EVENTOS_AUSENTES.md`, sin modificar el original.
  La auditoría reconstruyó dos desde ticks (2021-06-18: +1.8 · 2026-05-29: +1.0) y los dejó marcados
  como ausentes, preservando la evidencia.

**La lección (la más importante del documento):** *"el CSV reproduce los resultados principales"* **no
es lo mismo que** *"reprodujimos independientemente el experimento"*. Mientras la cobertura no sea
468/468 desde una fuente estable, la clasificación honesta es **SEGUIR INVESTIGANDO / *promising but
fragile***, no *validado*. Un caso de estudio que **acoge** este tipo de crítica y corrige el código
es más sólido que uno que nunca fue auditado. Sin silencios: si un artefacto tiene huecos, se dicen.

---

## 3. Prueba de autenticidad a nivel de tick (¿el CSV se puede regenerar desde la fuente cruda?)

Un dataset "verificable" tiene que poder **reconstruirse desde los datos crudos**, no solo existir.
Prueba: tomar ~15 días gotobi repartidos por todo el periodo, **descargar sus ticks Dukascopy de
nuevo**, aplicar la regla congelada y comparar celda por celda contra el CSV.

Resultado: **10 de 10 días efectivamente descargados coincidieron al centavo** (diferencia +0.00 pips).
Los días faltantes fueron archivos que no alcanzaron a bajar por el rate-limit del servidor, no
discrepancias.

```
fecha        CSV      recalc   diff
2020-01-03   +3.20    +3.20    0.00  OK
2020-06-15   +1.10    +1.10    0.00  OK
2022-09-30   +3.90    +3.90    0.00  OK
2024-03-05   -6.40    -6.40    0.00  OK
...          10/10 coinciden
```

**Lección:** si publicas un resultado, publica también el **camino para regenerarlo desde crudo**.
"Confía en mi CSV" no es ciencia; "aquí está el script que baja los ticks y reproduce cada fila" sí.

---

## 4. Réplica en un TERCER feed (otro broker, cuenta minorista)

El caso ya se replicó en dos feeds (broker de origen + Dukascopy). Un tercero corrió la **misma regla
congelada** contra el feed M1 de **otro broker minorista** (cuenta mini, símbolo con sufijo), en la
única ventana con historial M1 disponible en ese terminal: **~un trimestre (may–ago 2026), 16 eventos
gotobi**.

| Grupo (09:55→10:10 JST) | N | Media | Win | t |
|---|---|---|---|---|
| GOTOBI | 16 | +2.67 pips | 62% | 2.08 |
| CONTROL (días no-gotobi) | 48 | **−0.62 pips** | 52% | −0.70 |

**Lo que SÍ dice:** la **dirección** del edge replica en un feed y un periodo independientes —
gotobi positivo, control negativo, el mismo signo que el estudio. Eso es señal cualitativa real.

**Lo que NO dice:** con **N=16**, el t=2.08 es ruido con suerte; el IC95 inferior pega en cero, y
quitando un solo outlier (+14.8 pips de un día) la media cae de +2.67 a +1.86. **Lección:** distingue
siempre entre *replicar el signo* (valioso con N chico) y *replicar la magnitud/significancia* (exige
N grande). Un trimestre no valida nada; confirma que el fenómeno apunta al mismo lado.

---

## 5. La realidad del costo (mide el TUYO, no el del paper)

El estudio asume ~1.1 pips de costo (comisión de cuenta Raw + spread ≈ 0). En la cuenta mini del
tercer feed, el **spread real medido en el minuto exacto del fix** fue ≈ **1.0 pip constante, sin
comisión** → costo total prácticamente igual al supuesto. El modelo de costos se sostiene.

**Lección:** el edge es de +1 a +2 pips. A esa escala, **medio pip de costo mal estimado te borra un
tercio del retorno**. No asumas el costo: mídelo en TU broker, en TU tipo de cuenta, **en la hora
exacta** en que operas (el spread a las 09:55 JST no es el de mediodía).

---

## 6. La fricción de datos es parte del trabajo (reproducibilidad real)

Reproducir la réplica Dukascopy completa **no es un clic**:

- El feed público de Dukascopy **throttlea por IP**: ~2 archivos/min de éxitos sostenidos.
- **Subir hilos no ayuda** — con >3 conexiones el servidor bloquea *todo* (probado: 10 hilos → 0
  éxitos). El tope de 3 hilos del script es correcto.
- El set completo (≈936 archivos de 2 horas × ~468 gotobis) tarda **~7–8 horas**.
- **No hay tier de pago de Dukascopy** que levante ese límite (su producto de pago es el bróker, no
  un API de datos). Alternativas más rápidas para M1: HistData.com (zips mensuales, pero el token de
  descarga lo pone JavaScript) o TrueFX.
- El script cachea y **retoma donde quedó**, así que se corre por tandas.

**Lección:** presupuesta la fricción de datos como parte del proyecto. Un backtest "reproducible" que
tarda 8 horas en bajar los datos sigue siendo reproducible — pero planifícalo.

---

## 7. Las preguntas incómodas que TÚ debes hacerle al caso

Auditar no es solo confirmar; es **buscar por dónde se rompe**. Estas son las debilidades honestas que
un estudiante crítico debe plantear (el caso las reconoce, pero conviene tenerlas al frente):

1. **¿Es un edge estructural o dependiente de régimen?** Casi todo el alpha vive en **2022–2025**,
   justo la era de debilidad brutal del yen e intervención del BoJ. 2020–2021 fueron ≈0. Lectura
   alternativa válida: "funciona sobre todo cuando el USDJPY está en tendencia alcista fuerte".
   El caso lo enmarca como "sin decay"; un auditor lo enmarca como "a vigilar en el forward".

2. **El Sharpe de la canasta (~2.1–2.4) está inflado por correlación.** Las 5 patas JPY correlacionan
   **0.83–0.92**: es *una* apuesta en 5 sabores, no 5 fuentes independientes. Alisa, no multiplica.
   El "R/año +8–10" no son 5 edges sumados.

3. **El edge es fino frente al riesgo de ejecución.** +1–2 pips entrando a mercado en el minuto de
   mayor actividad. El backtest asume slippage ≈ 0. La única forma de saber si sobrevive es **medir
   el slippage real en forward** (criterio pre-firmado: < 0.5 pip).

4. **Selección entre variantes cercanas.** El README alterna entre salida 10:10 (6/7 años) y 10:15
   (7/7 años). Elegir la que da 7/7 es exactamente el tipo de selección que la metodología advierte.
   Cuál usar debe estar **pre-registrado**, no elegido post-hoc por el resultado.

Ninguna de estas hunde el caso — pero un estudiante que **no** las plantea no está auditando, está
aplaudiendo. La ventaja competitiva no es encontrar el edge; es saber exactamente **por dónde podría
morir** y vigilarlo.

---

## Cómo reproducir esta auditoría

- `python backtest/verificar_dataset.py` → recalcula las estadísticas del CSV desde cero (solo stdlib)
  y muestra la cobertura (los 32 ausentes) al instante. Añade `--spotcheck 15` para verificar contra
  ticks Dukascopy.
- `python backtest/dukascopy_replica.py` → regenera el dataset desde ticks (paciencia: horas), ahora
  **guardando** el `*_regen.csv` y **reportando** los días sin datos.
- `python backtest/nakane_backtest.py [SIMBOLO]` → corre la regla contra tu propio terminal MT5.
- `data/EVENTOS_AUSENTES.md` → los 32 eventos ausentes, preservados como evidencia.

> Crédito: las secciones 2 y 3 nacen de una **auditoría independiente de la comunidad** (laboratorio
> separado, repo original intacto, falsación antes que optimización). Así se estudia un edge en serio.

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — aprende a auditar un sistema, no solo a construirlo.

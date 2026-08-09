# Eventos ausentes del dataset publicado — cobertura y trazabilidad

> Este documento existe gracias a una **auditoría independiente de la comunidad** (ver
> `docs/06_AUDITORIA_INDEPENDIENTE.md`). Preservar la evidencia > maquillarla.

## El hallazgo

El calendario gotobi 2020–2026 (regla congelada: 5/10/15/20/25/30; fin de semana → viernes previo)
genera **468 eventos**. El dataset publicado `resultados_replica_dukascopy.csv` contiene **436 filas**.
Faltan exactamente **32 eventos** (0 filas sobrantes).

## La causa (verificada)

No es un filtro de la estrategia ni una selección: es un **artefacto de la descarga**. El script
`dukascopy_replica.py` descartaba en silencio (`if not t0 or not t1: continue`) los días gotobi para
los que el feed de Dukascopy **no devolvió ticks en esa corrida** — festivos, huecos del feed, o
—sobre todo— archivos que fallaron por el rate-limit del servidor durante la generación. Como el
acceso a Dukascopy es intermitente, **cada corrida pierde días distintos**: la cobertura no era
determinista, y el CSV publicado es una corrida particular con esos 32 huecos.

Se corrigió: el script ahora **guarda el CSV regenerado** y **reporta la cobertura** (lista los días
sin datos en `data/eventos_sin_datos.txt`), sin truncamiento silencioso.

## Los 32 eventos ausentes (preservados como evidencia)

No se añaden al dataset original para no contaminar la evidencia. Se dejan **identificados**:

```
2021-02-05  2021-06-18  2021-06-25  2021-07-15  2021-08-05  2021-08-20
2021-08-25  2021-09-10  2022-11-18  2022-12-23  2022-12-30  2023-01-05
2023-01-13  2023-03-15  2023-03-20  2023-03-24  2025-08-05  2025-08-20
2025-08-29  2025-09-05  2025-09-25  2025-11-10  2026-02-25  2026-03-25
2026-04-15  2026-05-29  2026-06-05  2026-06-10  2026-06-15  2026-06-19
2026-07-10  2026-07-15
```

Distribución por año: 2020: 0 · 2021: 8 · 2022: 3 · 2023: 6 · 2024: 0 · 2025: 6 · 2026: 9.
(Los bloques recientes de 2026 coinciden con el tramo donde una corrida de generación se quedó
corta de datos — consistente con fallos de descarga, no con nada de la señal.)

Dos de estos eventos fueron **reconstruidos desde ticks por la auditoría independiente** y quedaron
registrados como ausentes, sin modificar el original:

| Fecha ausente | Reconstruido (auditoría) |
|---|---|
| 2021-06-18 | +1.8 pips |
| 2026-05-29 | +1.0 pip |

## Por qué esto NO invalida el caso (pero SÍ importa)

- Los 32 ausentes son **~7% de los eventos**, repartidos, sin sesgo de signo aparente (los dos
  reconstruidos son pequeños, uno + y otro +). No hay indicio de que se hayan omitido perdedores.
- Pero mientras no se **regenere el dataset completo** (los 468 con datos) desde una fuente estable,
  no se puede afirmar *"reproducimos independientemente el experimento"*. La clasificación honesta es
  **SEGUIR INVESTIGANDO / *promising but fragile***, no *validado*.

## Cómo cerrar el hueco

```
python backtest/dukascopy_replica.py     # regenera y guarda *_regen.csv + reporta cobertura
python backtest/verificar_dataset.py     # recalcula stats y muestra los ausentes al instante
```

Meta: una corrida con **cobertura 468/468** (o el máximo que el feed permita), con los días sin datos
explícitamente listados. Ese sería el artefacto plenamente reproducible.

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — un "no" bien medido vale tanto como un "sí".

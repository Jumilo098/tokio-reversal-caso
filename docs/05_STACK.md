# El stack — todos los componentes con los que se hizo esto (y cómo montarlo tú)

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)** y aprende a montar este laboratorio completo

Este documento es el mapa de la sala de máquinas: qué herramienta hizo qué, en qué paso, cuánto
cuesta, y con qué la reemplazas si no la tienes. **Casi todo es gratis o casi-gratis** — la barrera
no es el dinero, es el método (docs/01).

## Los componentes, uno a uno

| # | Componente | Rol en este caso | Cómo lo consigues | Costo |
|---|---|---|---|---|
| 1 | **Agente de IA en terminal** (Claude Code o similar) | El orquestador de TODO: escribió los backtests, corrió la investigación, compiló los EAs, redactó los docs y construyó este repo — en una jornada | claude.com/claude-code | Suscripción del modelo |
| 2 | **MetaTrader 5** (terminal del broker) | Fuente de datos M1/ticks del broker real + donde corren los EAs + Strategy Tester para verificación | Gratis (instalador de tu broker) | $0 |
| 3 | **Paquete Python `MetaTrader5`** | El puente dato↔código: `copy_rates_range`, `copy_ticks_from` — todo el arnés de `backtest/` habla con el terminal por aquí | `pip install MetaTrader5` (Windows) | $0 |
| 4 | **Python + pandas/numpy** | El arnés de backtest: simulación intrabar, estadística (t, IC95, control), familias de tests | python.org | $0 |
| 5 | **MetaEditor CLI** | Compilación automatizada de los EAs desde el agente (`metaeditor64.exe /compile /log`) — sin tocar la GUI | Viene con MT5 | $0 |
| 6 | **Broker: Exness Raw Spread** | El terreno real: spread ~0 en pares JPY (medido de ticks: 0.0 pips incluso en la ventana asiática) + comisión fija $7/lote RT = costo total ~1.1 pips, transparente y modelable | exness.com (demo gratis para todo el caso) | Spread/comisión al operar |
| 7 | **Grok (en X/Twitter)** | La investigación de campo: 3 pasadas sondeando la conversación quant de X — **incluido en japonés** (仲値/五十日), de donde salió la regla ganadora. Prompts exactos en `docs/03` | Cuenta de X | Incluido en X Premium |
| 8 | **Buscador web + papers** | La literatura: NBER (Ito-Yamada, el paper del fixing), JMCB (Breedon-Ranaldo), SSRN (Evans, Melvin-Prins) — el mecanismo causal antes que el patrón | Google Scholar / arXiv / SSRN | $0 |
| 9 | **Dukascopy datafeed** | La réplica independiente: ticks públicos gratuitos de un feed suizo (bid/ask reales desde 2003) — la prueba de fuego de `backtest/dukascopy_replica.py` | URL pública (el script lo hace solo) | $0 |
| 10 | **VPS** (para el forward) | Ejecutar el EA 24/7 con reloj preciso: MQL5 VPS (~$15/mes, cero mantenimiento) o VPS genérico Windows (~$10/mes, corre varios terminales) | mql5.com / Contabo etc. | ~$10-15/mes |
| 11 | **Telemetría del forward** | Registrar cada trade del demo (spread, slippage, motivo de cierre) contra los criterios del corte. En el Instituto usamos un módulo propio + base de datos; empieza con el Diario de MT5 + un CSV | Se enseña en el programa | $0 |
| 12 | **TradingView (+ Pine Script)** | En este caso puntual fue secundario (visualización). En el laboratorio completo del Instituto es central: indicadores propios, datos en vivo y automatización sobre el chart | tradingview.com | Gratis-$ |

## Qué componente hizo qué paso (el flujo real de la jornada)

```
PASO                                 │ COMPONENTES
─────────────────────────────────────┼───────────────────────────────
1. Falsar lo obvio (portabilidad,    │ MT5 + Python (arnés) + agente IA
   salidas, Fib/HA)                  │
2. Investigar mecanismos             │ Buscador (papers) + Grok/X (3 pasadas)
3. Pre-registrar reglas y criterios  │ Un archivo de texto y disciplina (docs/01)
4. Backtest primario + control       │ MT5 M1 (Exness) + Python
5. Endurecer (años, costos, spread   │ MT5 ticks (spread real de la ventana
   real, con/sin stop)               │ exacta) + Python
6. Expandir por declaración externa  │ Grok (reglas japonesas) + Python
7. Construir los EAs v1→v3           │ Agente IA + MetaEditor CLI (0 errores)
8. Verificar fidelidad (R6)          │ Strategy Tester (ticks reales, 100%)
9. Réplica independiente             │ Dukascopy (público) + Python
10. Forward con corte                │ EA v3 + cuenta demo + VPS + telemetría
```

## El presupuesto honesto para replicar TODO

- **Fase de investigación y backtest (pasos 1–9): $0** — demo de broker, datos gratis, Python gratis.
  Lo único de pago es el agente de IA (y X Premium si quieres Grok).
- **Fase forward (paso 10): ~$10–15/mes** de VPS. La demo no arriesga un peso.
- **Fase real (si el forward valida): desde ~$500** en cuenta Raw (con stop de 20 pips, el lote
  mínimo 0.01 ≈ $1.3 de riesgo por pata — la aritmética completa está en el programa).

## Las reglas de la casa al usar este stack

1. **El agente de IA ejecuta; el criterio es tuyo.** Cada regla, umbral y veredicto de este caso
   fue una decisión humana pre-registrada. La IA multiplica la velocidad, no la honestidad.
2. **Nunca backtestees con el LLM "prediciendo"** — los modelos memorizaron la historia financiera
   de su entrenamiento (está documentado en la literatura). El LLM escribe el arnés; los datos
   dictan el resultado.
3. **Mide tu broker, no lo supongas**: el spread de la ventana exacta se midió de ticks reales
   (¿sabías que el Raw de JPY a las 00:55 UTC es 0.0 pips? Nosotros tampoco — por eso se mide).
4. **Dos feeds mínimo** antes de creer un verde. Un feed puede mentir; dos feeds independientes
   con la misma firma temporal, difícilmente.

---
🎓 En **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** montamos este stack completo
contigo, en vivo — del primer `pip install` al forward con telemetría.

# Los prompts — cómo se investigó esto con IA (replicable)

> Caso Tokio Reversal · [Instituto Quant](https://www.InstitutoQuant.com) — **[matricúlate](https://www.InstitutoQuant.com)**

La investigación combinó tres fuentes: literatura académica (buscadores web), la conversación de
la comunidad quant en X (vía Grok, que puede sondear X incluyendo posts EN JAPONÉS), y los propios
datos (backtests). Estos son los prompts reales empleados, para que los adaptes a tu mercado.

## Principios de prompting para investigación de edge

1. **Pide MECANISMOS, prohíbe patrones**: excluye explícitamente "RSI, MACD, velas, smart money
   concepts" — o te enterrarán en folklore técnico.
2. **Pide el ESTADO del edge**: "¿se comenta que sigue vivo o que decayó?" — la anomalía publicada
   suele estar muerta; lo que buscas es el residuo y quién lo reporta.
3. **Pide CUENTAS con nombre**: te da hilos verificables y a quién seguir.
4. **Sondea el idioma LOCAL del mercado**: el oro de este caso salió de posts en japonés
   (仲値トレード, 五十日, 実需フロー) que ningún occidental lee.
5. **Itera en pasadas**: general → profundizar en lo prometedor → microestructura de ejecución.

## Pasada 1 — el mapa general (a Grok, sondeando X)

```
Sondea X (2025-2026, cuentas de quants, desks FX y retail japonés) por anomalías OPERABLES
con mecanismo causal claro en USDJPY: intervenciones BoJ/MoF, fixing de Tokio 9:55 JST y
días gotobi (¿sigue vivo o decayó?), pinning de expiries grandes de opciones al corte NY
10am, repatriación fiscal japonesa y rebalanceo del London fix, carry unwind del yen, u
otros efectos de flujo o calendario. IGNORA señales técnicas genéricas (RSI, MACD, velas,
smart money concepts). Devuélveme una lista de hipótesis concretas, cada una con: el
mecanismo causal, qué cuentas lo discuten, y si reportan que sigue funcionando o se degradó.
```

## Pasada 2 — profundizar (idioma local + detalle de configs + hipótesis hermanas)

```
Segunda pasada, tres frentes: (1) Busca posts EN JAPONÉS 2024-2026 sobre nakane/仲値トレード,
五十日 (gotobi), 実需フロー y ロンドンフィックス: qué reglas concretas usan las cuentas japonesas
(hora de entrada, filtros por día del mes, stop) y si reportan que el edge se degradó.
(2) Profundiza en el hilo de [cuenta que hizo backtest riguroso]: cuál fue exactamente la
configuración superviviente y por qué la terminó rechazando. (3) Quién discute el efecto de
REBALANCEO DE FIN DE MES en el London fix 4pm (Melvin-Prins), ¿hay alguien operándolo con
reglas concretas? Y de paso: ¿alguien documenta drift pre-anuncio del banco central?
```

## Pasada 3 — microestructura de ejecución (cuando ya tienes el candidato)

```
Tercera pasada, ahora MICROESTRUCTURA del trade [descripción exacta de tu regla]. Busca en X
(japonés incluido) 2024-2026: (1) FERIADOS: cómo ajustan el calendario los sistemáticos cuando
el día cae en feriado bancario. (2) CONDICIONANTES del tamaño del efecto: ¿alguien filtra o
dimensiona por [variables candidatas]? (3) EJECUCIÓN fina: segundo exacto de entrada, brokers
que recotizan o ensanchan spread en el momento clave, cuál broker usan los locales. (4) ¿El
lado que operamos se está degradando o masificando (EAs comerciales)? (5) ¿Usan [dato público
del mecanismo] como señal? Lista concreta con cuentas y reglas.
```

## Búsquedas académicas (buscador web normal)

- `Tokyo fix gotobi anomaly 9:55 JST importer flows academic study` → NBER w22820 (Ito & Yamada)
- `[tu mercado] fix benchmark pre-fix run-up post-fix reversal study evidence`
- `look-ahead bias LLM trading backtest training data contamination` → por qué NO backtestear con LLMs
- `Melvin Prins month-end equity hedge rebalancing FX London fix`
- Regla: busca el PAPER, no el blog. Y busca quién lo REFUTÓ después.

## La regla de oro al usar lo que encuentres

**Todo lo que la IA te traiga es HIPÓTESIS, jamás resultado.** Cada regla encontrada se congela
tal como la declaró su fuente (sin "mejorarla"), se pre-registra el criterio de éxito, y se
ejecuta contra TUS datos con TUS costos. En este caso: de ~12 hipótesis traídas por la
investigación, sobrevivieron 2. Las otras 10 muertes están en `02_HALLAZGOS.md` — y valen tanto
como las vivas.

---
🎓 **[www.InstitutoQuant.com](https://www.InstitutoQuant.com)** — el método completo, en vivo, con comunidad.

# Informe de auditoria y validacion — TokioReversal_v3_LABTEST v3.03

Preparado por: laboratorio de EAs de Eduard (agente-ea-lab), 2026-08-12.
Para: revision del mentor (Instituto Quant / caso `github.com/Jumilo098/tokio-reversal-caso`).

## 1. Que es este documento

Este informe resume el trabajo hecho sobre el EA **TokioReversal_v3** (el caso del
fixing de Tokio, cruces JPY, dias gotobi) desde que se recibio el codigo original hasta
la version que esta corriendo ahora mismo en demo. El objetivo es que el mentor pueda
auditar de forma independiente tanto el codigo final como el proceso que llevo hasta el.

**No es un EA propio del laboratorio** — es el EA de terceros del caso de estudio,
copiado y modificado solo para fines de evaluacion (`TokioReversal_v3_LABTEST.mq5`,
adjunto). El archivo original del mentor no se toco.

## 2. Origen

- Repositorio: `github.com/Jumilo098/tokio-reversal-caso` (Instituto Quant).
- Hipotesis: flujo institucional real y recurrente — importadores japoneses liquidan
  facturas en USD en el fixing de Tokio (09:55 JST) en dias de liquidacion "gotobi"
  (5/10/15/20/25/30 de cada mes), generando presion vendedora de USD/compradora de JPY
  insensible al precio. Mecanismo causal explicito: "quien esta obligado a operar,
  cuando, y quien paga por ello".
- Vehiculo original: canasta de 5 patas JPY (USDJPY, EURJPY, GBPJPY, CHFJPY, CADJPY),
  entrada SELL en el fix, salida por tiempo a los 10-15 min, stop de proteccion fijo.

## 3. Auditoria de codigo (`ea-code-auditor`, 2026-08-09)

Se audito el `.mq5` original antes de compilarlo. Veredicto: **REQUIERE CORRECCIONES**.

**3 hallazgos CRITICOS:**
1. Un input nacia en un valor que violaba la propia "regla congelada" declarada en el
   header del autor (desalineacion documentacion vs. codigo).
2. El gate "solo operar en demo hasta validar" era solo un `Print()` de aviso, no un
   bloqueo tecnico — en cuenta real el EA habria operado igual.
3. El calculo de la hora del fix (09:55 JST) usaba un offset servidor->UTC fijo que no
   maneja el horario de verano (DST) del broker — sin corregirlo, buena parte del
   backtest habria estado midiendo una hora real distinta a la pretendida.

**2 hallazgos ALTOS:**
4. `CTrade` enviaba ordenes con modo de llenado FOK fijo, sin verificar que el simbolo
   lo soporte — falla silenciosa en vivo (retcode 10030) que el Strategy Tester no
   detecta porque el tester acepta cualquier modo.
5. El input `MinutosHold` no se usaba realmente: la hora de cierre estaba hardcodeada,
   asi que cambiar ese input no tenia ningun efecto.

Varios hallazgos ALTO/MEDIO adicionales coincidieron con patrones ya catalogados en
nuestro checklist interno de bugs genericos de MQL5 (no exclusivos de este codigo),
confirmando que el catalogo es transferible a cualquier `.mq5` de terceros.

## 4. Correcciones aplicadas (copia `_LABTEST`, no el original)

Todas documentadas linea por linea en el header del `.mq5` adjunto:

- **Fix critico #1 (DST):** hora JST se deriva de `TimeGMT()+9h`, valido tanto en
  cuenta real como en Strategy Tester, sin depender de un offset fijo.
- **Fix critico #2 (regla congelada incompleta):** se verifico con backtest propio que
  el "ultimo dia habil del mes" (fin de mes) tambien aporta valor real y consistente, y
  se declaro explicitamente como parte de la regla congelada (ya no es un default
  silencioso).
- **Fix critico #3 (gate demo no vinculante):** `OnInit()` ahora retorna `INIT_FAILED`
  en cuenta real salvo que el operador ponga a mano `AceptoOperarReal=true`. Sigue
  bloqueado hasta que exista un pre-registro forward firmado.
- **Fix alto #4 (filling mode):** se agrego `PickFilling()` (deriva el modo de llenado
  soportado por el simbolo) y se aplica antes de cada envio/cierre de orden.
- **Fix alto #5 (input muerto + cambio de regla):** `MinutosHold` ahora si determina la
  hora de cierre. Aprovechando la correccion, se corrio un test pareado trade-a-trade
  sobre la "sombra" que el propio EA ya media (cierre a 10:15 sin operarlo) contra la
  regla original (10:10): mejora estadisticamente significativa en las 3 patas (t
  pareado 6.37 / 10.80 / 10.25, n=328-338 pares). Confirmado luego con un backtest REAL
  de la regla 10:15 (no solo la sombra, que sobreestima al no simular el riesgo del
  stop entre 10:10 y 10:15). `MinutosHold` paso de 15 a 20 minutos; la regla congelada
  de esta copia es ahora **cierre a las 10:15 JST**, no 10:10.

## 5. Metodologia de validacion propia

Ademas de auditar el codigo, se corrio un backtest independiente en MetaTrader 5
(terminal de pruebas, cuenta demo, nunca el terminal real) para verificar el hallazgo
con datos propios, no solo confiar en los numeros del caso original:

- **Ventana comun real:** 2021.11.01 a 2026.08.09 (~4.75 anios) en USDJPYm, EURJPYm,
  GBPJPYm. (CHFJPY y CADJPY quedaron fuera: no se validaron con datos propios, no se
  activan en el forward.)
- **Correccion de multiplicidad (evitar falso positivo por comparar series con
  distinta cantidad de muestra):** en una primera pasada, GBPJPY parecia sobrevivir el
  umbral estadistico por tener 3x mas historial acumulado que EURJPY, no por mejor
  edge en el mismo periodo. Al igualar todas las series a la misma ventana de
  calendario, ese efecto desaparecio y las tres patas se evaluaron de forma justa.
  Resultado final con ventana igualada: USDJPY t=4.93, EURJPY t=3.46, GBPJPY t=2.62
  (n=352/355/356), las tres sobreviven correccion tipo Bonferroni.
- **Grupo de control:** el mismo mecanismo (SELL 09:55->10:10 JST, stop 20 pips) se
  corrio tambien en dias habiles SIN gotobi/fin de mes, misma hora, mismo simbolo. El
  grupo de control dio resultado nulo o negativo (USDJPY -0.40 pips t=-1.13, EURJPY
  -1.22 t=-3.63, GBPJPY -1.20 t=-2.29) frente a +2.85/+1.96/+1.75 pips del grupo evento
  — evidencia de que el efecto vive en el CALENDARIO declarado, no en la hora de
  sesion en si. El resultado de control en USDJPY replico casi exacto el -0.4 pips que
  reporto el mentor de forma independiente.
- **Cambio de regla 10:10->10:15:** ver seccion 4, fix alto #5. Edge final con la regla
  10:15: **+3.46 / +2.67 / +2.55 pips/trade** en USDJPY/EURJPY/GBPJPY (mejora sobre
  +2.85/+1.96/+1.75 de la regla 10:10), sin empeorar el drawdown (equity DD <0.16% del
  deposito en ambos casos).
- **Decision de capital y riesgo:** a $800 con riesgo nominal bajo (0.25%/evento), el
  100% de las operaciones habria caido en el lote minimo fijo del broker (0.01) — el
  input de riesgo habria sido decorativo, sin efecto real en el tamano de posicion. Se
  eligio **1.0%/pata** (RiskPorEvento=3.0, PatasActivas=3) tras comparar explicitamente
  contra el default: proyeccion +$306/ano vs. ~$33/ano, con drawdown maximo esperado
  ~1.7% del capital (peor pata, GBPJPY) vs. ~0.5%. Se verifico ademas que el
  apalancamiento (1:100 vs 1:200) no afecta el resultado — el EA dimensiona por riesgo
  contra el stop, no por margen disponible.

## 6. Estado actual: forward test en curso

- **Desplegado en demo** (MT5, cuenta demo [redactada al publicar] en un servidor demo de Exness, terminal separado
  del de pruebas) desde el **2026-08-09**, tres graficos (USDJPYm, EURJPYm, GBPJPYm),
  `MagicNumber=20260808`.
- **Configuracion verificada por captura de pantalla** antes de arrancar el reloj
  (`RiskPorEvento=3.0`, `PatasActivas=3`, `MinutosHold=20`, `AceptoOperarReal=false`).
- **Corte pre-registrado: 60 eventos de calendario** (no 60 trades por pata — los
  eventos son compartidos por las tres patas), cadencia esperada ~7-8/mes, corte
  estimado ~abril-mayo 2027.
- **Criterios PASA/FALLA fijados por adelantado**, evaluados por componente (no un
  veredicto global unico): edge direccional por pata (media > 0, IC95% no cruza cero),
  calidad de ejecucion (slippage < 0.5 pips, 0 fallos de orden por filling mode), y
  fidelidad de la regla (100% de entradas dentro de la ventana 09:55-09:56 JST en dias
  gotobi/fin de mes reales).
- **Incidente registrado:** el 2026-08-10 el terminal local estuvo apagado durante la
  ventana del evento del dia 10 (indisponibilidad de infraestructura, no fallo de la
  estrategia ni del codigo). Ese evento no cuenta contra el corte de 60. Como
  consecuencia, el despliegue se esta migrando a un VPS 24/7 para que esto no se
  repita.
- Nada se toca durante la ventana de evaluacion salvo lo que autoriza la taxonomia de
  conducta pre-registrada (bug de implementacion se corrige ya sin reiniciar el reloj;
  racha mala se anota pero no se actua; falla catastrofica del mecanismo detiene el
  reloj).

## 7. Que se le pide al mentor

Revision independiente de:
1. El codigo adjunto (`TokioReversal_v3_LABTEST.mq5` v3.03) — especialmente si los 5
   fixes de la seccion 4 introducen algun efecto secundario no previsto sobre la logica
   original del caso.
2. El cambio de regla 10:10->10:15 (seccion 4/5) — si el mentor tiene datos propios mas
   alla de 2026-08-09 que confirmen o contradigan esa mejora en un feed independiente.
3. El diseno del forward test (seccion 6) — si el corte de 60 eventos y los criterios
   PASA/FALLA por componente le parecen suficientes, o si recomendaria ajustar algo
   antes de que se acumule mas historial.

## Referencias internas (laboratorio propio, no necesarias para auditar el codigo)

- `conocimiento/pre-registro-forward-tokioreversal.md` — pre-registro completo firmado
  antes del primer trade en demo.
- `conocimiento/herramientas-validacion.md` seccion 3 — tecnicas incorporadas de este
  caso al proceso general del laboratorio (grupo de control, correccion de
  multiplicidad, sondeo de profundidad real de historial).
- `conocimiento/lecciones-aprendidas.md` — bitacora cronologica completa del
  2026-08-09.

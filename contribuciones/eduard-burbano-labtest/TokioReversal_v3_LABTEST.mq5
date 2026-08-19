//+------------------------------------------------------------------+
//|                                   TokioReversal_v3_LABTEST.mq5   |
//|  COPIA DE PRUEBA, NO OFICIAL. Origen: TokioReversal_v3.mq5       |
//|  (github.com/Jumilo098/tokio-reversal-caso, Instituto Quant).    |
//|  Uso: backtest de evaluacion en agente-ea-lab. NO ES un EA del   |
//|  lab, NO se versiona como propio. Ver auditoria ea-code-auditor  |
//|  2026-08-09 (3 CRITICOS) -- este archivo resuelve los 3:         |
//|                                                                  |
//|  FIX CRITICO #1 (DST): HoraJST() usaba offset fijo servidor->UTC |
//|  que no maneja el DST del broker (Exness EET/EEST, CLAUDE.md).   |
//|  Reemplazado por TimeGMT()+9h, DST-safe tambien en Strategy      |
//|  Tester. Sin esto medio anio de backtest media una hora real     |
//|  distinta a 09:55 JST. Input ServerToUTC_Horas se deja declarado |
//|  (no se usa) para minimizar el diff contra el original.          |
//|                                                                  |
//|  FIX CRITICO #2 (fin de mes no declarado en la "regla congelada" |
//|  del header original): la propia auditoria encontro que el       |
//|  header decia "solo gotobi" pero el codigo por defecto (v2)      |
//|  operaba tambien fin de mes -- documentacion vs codigo           |
//|  desalineadas. Ya NO es una laguna: se valido con backtest       |
//|  propio 2026-08-09 (USDJPY/EURJPY/GBPJPY, ventana 2021.11-       |
//|  2026.08, n=352-356) que fin de mes suma valor real y consistente|
//|  (grupo de control confirmo el mecanismo -- ver                  |
//|  herramientas-validacion.md 3.2/3.3), asi que la regla congelada |
//|  de ESTE archivo se redeclara explicitamente para incluirlo:     |
//|                                                                  |
//|  Regla CONGELADA (ORO/docs/07 + validacion propia agente-ea-lab, |
//|  2026-08-09, v3.03):                                             |
//|    SELL USDJPY/EURJPY/GBPJPY en el fix de Tokio (09:55 JST) en   |
//|    dias gotobi (5/10/15/20/25/30; finde -> viernes previo) Y     |
//|    ultimo dia habil del mes (UseFinDeMes=true, YA NO es opcional |
//|    silencioso: es parte de la regla congelada, ver arriba).      |
//|    Cubrir a los 20 min (10:15 JST, no 10:10). Stop proteccion    |
//|    20 pips.                                                      |
//|                                                                  |
//|  FIX CRITICO #3 (gate "solo demo" no vinculante): el original    |
//|  solo imprimia un aviso en cuenta REAL sin bloquear. Aqui         |
//|  OnInit() retorna INIT_FAILED en cuenta real salvo que el        |
//|  operador ponga a mano AceptoOperarReal=true (input nuevo, no    |
//|  existe en el original). Sigue siendo SOLO DEMO hasta que exista |
//|  un pre-registro forward firmado (docs/04 del caso, adaptado).   |
//|                                                                  |
//|  FIX ALTO #4 (v3.02, patron B-01 del catalogo del lab): CTrade   |
//|  usaba FOK por defecto sin verificar SYMBOL_FILLING_MODE. Se     |
//|  agrega PickFilling() (mismo patron ya usado en otros EAs del    |
//|  lab, ver BTC_BREAKOUT_DIAG.mq5) y se aplica con                 |
//|  SetTypeFilling() antes de CADA envio de orden (entrada y        |
//|  cierre). Invisible en el Strategy Tester (acepta cualquier      |
//|  modo); sin esto la entrada podia fallar en silencio en vivo con |
//|  retcode 10030 si el broker no admite FOK en estos simbolos.     |
//|                                                                  |
//|  FIX ALTO #5 + CAMBIO DE REGLA (v3.03, 2026-08-09): MinutosHold  |
//|  era un input muerto (cierre hardcodeado a 10:10, sin usarlo).   |
//|  Se deriva el cierre de MinutosHold de verdad Y se redefine la   |
//|  regla congelada a 10:15 (antes 10:10): test PAREADO propio      |
//|  trade-a-trade (R7) sobre la sombra ya integrada en el EA dio    |
//|  +1.70/+2.80/+3.13 pips/trade de mejora en USDJPY/EURJPY/GBPJPY  |
//|  (t pareado 6.37/10.80/10.25, n=328-338 pares) -- replica el     |
//|  mismo hallazgo que el caso original midio en sus dos feeds.     |
//|  MinutosHold pasa de 15 a 20 (09:55+20=10:15 JST). La sombra se  |
//|  recorre a 10:20 (candidata siguiente, sin pre-registro propio   |
//|  todavia). Ver conocimiento/pre-registro-forward-tokioreversal.md|
//+------------------------------------------------------------------+
#property copyright   "InstitutoQuant - copia de prueba agente-ea-lab, fixes 2026-08-09"
#property version     "3.03-labtest"
#property strict
#property description "COPIA DE PRUEBA - NO DESPLEGAR sin pre-registro forward. Ver TokioReversal_v3.mq5 original."

#include <Trade/Trade.mqh>

#define EA_VERSION "tokioreversal-3.03-labtest"

//==================== INPUTS ====================
input group "=== General ==="
input string PatasCalificadas    = "USDJPY,EURJPY,GBPJPY,CHFJPY,CADJPY"; // v3: SOLO patas con t>=2.5 (AUDJPY excluida, t=1.6)
input long   MagicNumber         = 20260808;   // Magic (fecha del pre-registro)
input int    ServerToUTC_Horas   = 0;          // NO USADO en LABTEST (ver header) - se deja por compatibilidad
input int    SlippagePoints      = 50;         // Desviacion maxima
input bool   PrintDebug          = true;
input bool   AceptoOperarReal    = false;      // FIX CRITICO #3: debe ponerse a mano en TRUE para correr en cuenta REAL. Default false = bloqueado.

input group "=== Regla congelada (docs/07 - NO TOCAR sin nuevo pre-registro) ==="
input int    StopPips            = 20;         // Stop de proteccion (pips)
input int    MinutosHold         = 20;         // 09:55 -> 10:15 JST (cambio 2026-08-09, ver header)
input int    SkipSpreadPoints    = 30;         // Spread >= 3 pips en el fix -> NO operar (skip honesto)

input group "=== Riesgo (demo: 0.25-0.5% hasta el corte) ==="
input double RiskPorEvento       = 0.25;       // % del balance por EVENTO (canasta completa)
input int    PatasActivas        = 1;          // LABTEST: 1 = evaluacion de pata individual (metodologia del caso)
input double MaxLotSize          = 5.0;        // Tope duro (si recorta, se LOGUEA el riesgo real)

//==================== GLOBALES ====================
CTrade   trade;
datetime g_ultimoDiaOperado = 0;   // fecha JST (00:00) del ultimo trade/skip
double   g_entradaHoy       = 0;   // precio de entrada del dia (para la sombra 10:15)
bool     g_sombraPendiente  = false;

double Pt()  { return SymbolInfoDouble(_Symbol, SYMBOL_POINT); }
int    Dig() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }
double Pip() { return (Dig()==3 || Dig()==5) ? 10.0*Pt() : Pt(); }
double ND(const double p) { return NormalizeDouble(p, Dig()); }
double RiesgoPata() { return RiskPorEvento / MathMax(1, PatasActivas); }

// FIX ALTO #4 (auditoria 2026-08-09, patron B-01 del catalogo del lab): CTrade
// usa FOK por defecto; si el broker no lo admite en este simbolo la orden
// falla en vivo con retcode 10030 -- invisible en el Strategy Tester, que
// acepta cualquier modo de llenado. Se deriva del broker en vez de asumir.
ENUM_ORDER_TYPE_FILLING PickFilling()
  {
   long fm = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fm & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((fm & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

//==================== HORA JST (LABTEST: via TimeGMT, DST-safe) ====================
datetime HoraJST() { return TimeGMT() + 9*3600; }

int DiasDelMes(const int y, const int m)
  {
   static const int dm[13] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
   if(m==2 && ((y%4==0 && y%100!=0) || y%400==0)) return 29;
   return dm[m];
  }

// La fecha JST de hoy es dia de LIQUIDACION gotobi?
// (dia divisible por 5; si cae sabado/domingo, la liquidacion pasa al viernes previo)
bool EsGotobiJST(const datetime jstAhora)
  {
   MqlDateTime hoy; TimeToStruct(jstAhora, hoy);
   if(hoy.day_of_week==0 || hoy.day_of_week==6) return false;
   static const int gs[6] = {5,10,15,20,25,30};
   for(int k=0; k<6; k++)
     {
      int g = gs[k];
      if(g > DiasDelMes(hoy.year, hoy.mon)) continue;
      datetime d = StringToTime(StringFormat("%04d.%02d.%02d 12:00", hoy.year, hoy.mon, g));
      MqlDateTime t; TimeToStruct(d, t);
      while(t.day_of_week==0 || t.day_of_week==6) { d -= 86400; TimeToStruct(d, t); }
      if(t.day==hoy.day && t.mon==hoy.mon) return true;
     }
   return false;
  }

// Ultimo dia habil del mes (JST)? (fin de mes = dia fuerte del nakane segun las cuentas japonesas)
input bool UseFinDeMes = true;    // FIX CRITICO #1: parte de la regla congelada (ver header), no opcional silencioso
bool EsFinDeMesJST(const datetime jstAhora)
  {
   MqlDateTime hoy; TimeToStruct(jstAhora, hoy);
   if(hoy.day_of_week==0 || hoy.day_of_week==6) return false;
   int dm = DiasDelMes(hoy.year, hoy.mon);
   for(int d = hoy.day+1; d <= dm; d++)
     {
      datetime f = StringToTime(StringFormat("%04d.%02d.%02d 12:00", hoy.year, hoy.mon, d));
      MqlDateTime t; TimeToStruct(f, t);
      if(t.day_of_week != 0 && t.day_of_week != 6) return false;   // queda un habil despues -> no es el ultimo
     }
   return true;
  }

bool EsEventoJST(const datetime jstAhora)
  { return EsGotobiJST(jstAhora) || (UseFinDeMes && EsFinDeMesJST(jstAhora)); }

//==================== POSICIONES ====================
ulong TicketMio()
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk > 0 && PositionSelectByTicket(tk))
         if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
            (long)PositionGetInteger(POSITION_MAGIC)==MagicNumber) return tk;
     }
   return 0;
  }

//==================== ENTRADA ====================
void IntentarEntrada()
  {
   datetime jst = HoraJST();
   MqlDateTime t; TimeToStruct(jst, t);

   // ventana de entrada: 09:55:00 - 09:56:59 JST (gracia de 2 min por lag)
   if(t.hour != 9 || t.min < 55) return;
   if(!EsEventoJST(jst)) return;

   datetime diaJST = jst - (jst % 86400);
   if(diaJST == g_ultimoDiaOperado) return;          // 1 trade por dia
   if(TicketMio() != 0) return;

   long spread = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread >= SkipSpreadPoints)
     {
      g_ultimoDiaOperado = diaJST;                    // skip honesto: consume el dia
      Print("SKIP por spread en el fix: ", spread, " pts (limite ", SkipSpreadPoints, ")");
      return;
     }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   double entry = tick.bid;                           // SELL al bid
   double sl    = ND(entry + StopPips * Pip());       // stop 20 pips arriba
   double dist  = sl - entry;

   // sizing por riesgo contra el stop
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiesgoPata() / 100.0;
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(dist <= 0 || tickSize <= 0 || tickValue <= 0) return;
   double lossPerLot = (dist / tickSize) * tickValue;
   if(lossPerLot <= 0) return;

   double lot     = riskMoney / lossPerLot;
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   if(riskMoney < lossPerLot * minLot * 0.95)
     {
      double riesgoRealPata = lossPerLot * minLot / balance * 100.0;
      Print("AVISO: presupuesto (", DoubleToString(RiesgoPata(),3), "%/pata) < lote minimo. ",
            "Riesgo REAL por pata: ", DoubleToString(riesgoRealPata,3), "% (evento ~",
            DoubleToString(riesgoRealPata*PatasActivas,2), "%). Sube equity o baja PatasActivas.");
     }
   if(lot > MaxLotSize)
     {
      // LECCION del caso TrendFilter: si el tope recorta, el riesgo real ya no es el declarado.
      double riesgoReal = MaxLotSize * lossPerLot / balance * 100.0;
      Print("AVISO: lote recortado por MaxLotSize (", DoubleToString(lot,2), " -> ",
            DoubleToString(MaxLotSize,2), "). Riesgo REAL: ", DoubleToString(riesgoReal,2),
            "% (no ", DoubleToString(RiesgoPata(),3), "%)");
      lot = MaxLotSize;
     }
   if(lot < minLot) return;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFilling(PickFilling());   // FIX ALTO #4: derivado del broker, no FOK por defecto
   bool ok = trade.Sell(lot, _Symbol, tick.bid, sl, 0.0);   // SIN take profit: salida por TIEMPO
   uint rc = trade.ResultRetcode();
   if(ok && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL))
     {
      g_ultimoDiaOperado = diaJST;
      g_entradaHoy = entry; g_sombraPendiente = true;   // v2: armar la sombra 10:15
      if(PrintDebug)
         Print("SELL fix Tokio: ", DoubleToString(lot,2), " lotes | entrada=",
               DoubleToString(entry, Dig()), " SL=", DoubleToString(sl, Dig()),
               " | spread=", spread, " pts | cierre programado 10:15 JST");
     }
   else
      Print("OrderSend fallo: retcode=", rc, " (", trade.ResultRetcodeDescription(), ")");
  }

//==================== SALIDA POR TIEMPO ====================
// FIX ALTO #5 + CAMBIO DE REGLA (2026-08-09): MinutosHold era un input muerto
// (el cierre estaba hardcodeado a las 10:10, sin usarlo). Se deriva el cierre
// de MinutosHold de verdad, Y se redefine la regla congelada a 10:15 (antes
// 10:10) tras el test pareado propio: +1.70/+2.80/+3.13 pips/trade de mejora
// en USDJPY/EURJPY/GBPJPY (t pareado 6.37/10.80/10.25, n=328-338), replicando
// el mismo hallazgo del caso original. MinutosHold pasa de 15 a 20 (09:55+20
// = 10:15 JST). Ver pre-registro-forward-tokioreversal.md.
void IntentarSalida()
  {
   ulong tk = TicketMio();
   if(tk == 0) return;
   datetime jst = HoraJST();
   MqlDateTime t; TimeToStruct(jst, t);

   int totalMin  = 55 + MinutosHold;         // minutos desde las 09:00 JST
   int cierreHr  = 9 + totalMin / 60;
   int cierreMin = totalMin % 60;
   // cierre desde cierreHr:cierreMin JST (failsafe: tambien cierra si ya paso esa hora)
   bool horaDeCerrar = (t.hour==cierreHr && t.min >= cierreMin) || (t.hour > cierreHr) || (t.hour < 9);
   if(!horaDeCerrar) return;

   trade.SetTypeFilling(PickFilling());   // FIX ALTO #4: tambien en el cierre
   if(trade.PositionClose(tk, SlippagePoints))
     { if(PrintDebug) Print("Cierre por TIEMPO (", cierreHr, ":", (cierreMin<10?"0":""), cierreMin, " JST) ejecutado."); }
   else
      Print("PositionClose fallo: ", trade.ResultRetcode(), " - reintenta el proximo tick/timer");
  }

//==================== SOMBRA 10:20 (medida SIN operarla) ====================
// 2026-08-09: la salida real paso de 10:10 a 10:15 (test pareado propio, ver
// header). La sombra se recorre a 10:20 -- medir 10:15 contra si misma ya no
// aporta nada. Candidata siguiente a validar si el patron de "mas tiempo,
// mas resaca" continua, con el mismo criterio: nunca se opera sin su propio
// pre-registro y test pareado, aunque la sombra salga verde.
void IntentarSombra()
  {
   if(!g_sombraPendiente || g_entradaHoy <= 0) return;
   datetime jst = HoraJST();
   MqlDateTime t; TimeToStruct(jst, t);
   bool hora = (t.hour==10 && t.min >= 20) || (t.hour > 10);
   if(!hora) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double sombraPips = (g_entradaHoy - tick.bid) / Pip();
   Print("SOMBRA_1020: ", DoubleToString(sombraPips, 1), " pips (no operada)");
   g_sombraPendiente = false; g_entradaHoy = 0;
  }

//==================== CICLO ====================
void OnTick()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
   IntentarSalida();     // primero salidas (failsafe)
   IntentarSombra();
   IntentarEntrada();
  }

void OnTimer()
  {
   // timer de 1s: precision del 09:55/10:10 aunque no lleguen ticks (mercado asiatico quieto)
   IntentarSalida();
   IntentarSombra();
   IntentarEntrada();
  }

int OnInit()
  {
   // v3: lista blanca de patas CALIFICADAS (regla de inclusion: t>=2.5 individual, docs/07)
   string partes[];
   int nP = StringSplit(PatasCalificadas, ',', partes);
   bool calificada = false;
   for(int i = 0; i < nP; i++)
      if(StringLen(partes[i]) > 0 && StringFind(_Symbol, partes[i]) >= 0) { calificada = true; break; }
   if(!calificada)
     {
      Print("ERROR: ", _Symbol, " NO es pata calificada (", PatasCalificadas,
            "). AUDJPY quedo EXCLUIDA por t=1.6 - no montar por intuicion, solo por medicion.");
      return INIT_FAILED;
     }

   // FIX CRITICO #3 (auditoria 2026-08-09): el gate "solo demo" del original
   // era solo un Print, no un bloqueo. Aqui SI bloquea: en cuenta REAL fuera
   // del tester, exige que el operador ponga AceptoOperarReal=true a mano.
   if(!MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
     {
      if(!AceptoOperarReal)
        {
         Print("*** BLOQUEADO: cuenta REAL detectada y AceptoOperarReal=false. ",
               "Esta copia es SOLO DEMO hasta que exista un pre-registro forward firmado. ",
               "Si de verdad quieres operar real, pon AceptoOperarReal=true a mano. ***");
         return INIT_FAILED;
        }
      Print("*** ATENCION: CUENTA REAL con AceptoOperarReal=true. Confirmando que esto ",
            "es una decision deliberada, no el default. ***");
     }

   EventSetTimer(1);
   Print("TokioReversal v3.03-LABTEST en ", _Symbol, " | docs/07 + validacion propia 2026-08-09 | riesgo/evento=",
         DoubleToString(RiskPorEvento,2), "% repartido en ", PatasActivas, " patas (",
         DoubleToString(RiesgoPata(),3), "%/pata) | sombra 10:20 ON | HoraJST via TimeGMT (DST-safe)");
   Print("  SELL 09:55 JST gotobi+finmes (regla congelada, incluye finmes explicito) -> cubrir 10:15 (MinutosHold=",
         MinutosHold, ") | stop ", StopPips,
         " pips | riesgo ", DoubleToString(RiesgoPata(),3), "% | skip spread>=", SkipSpreadPoints, " pts");
   Print("  COPIA DE PRUEBA - NO DESPLEGAR sin pre-registro forward (docs/04 del caso, adaptado).");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }
//+------------------------------------------------------------------+

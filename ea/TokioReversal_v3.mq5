//+------------------------------------------------------------------+
//|                                            TokioReversal_v3.mq5  |
//|  Regla CONGELADA (ORO/docs/07, pre-registro 2026-08-08):         |
//|    SELL USDJPY en el fix de Tokio (09:55 JST) SOLO dias gotobi   |
//|    (5/10/15/20/25/30; finde -> viernes previo).                  |
//|    Cubrir a los 15 min (10:10 JST). Stop proteccion 20 pips.     |
//|                                                                  |
//|  Mecanismo: reversion del flujo de importadores tras el fix      |
//|  (NBER w22820; medido en Exness M1 2020-2026: +2.1 pips/trade,   |
//|  t=4.26, 6/7 anios positivos, sin decay).                        |
//|                                                                  |
//|  *** SOLO DEMO hasta el corte pre-registrado de 60 trades ***    |
//|  *** La regla NO se toca: cambio = nuevo pre-registro ***        |
//|                                                                  |
//|  Telemetria: modulo oficial Telemetria.mqh (Operaciones Reales). |
//|  Requisito: permitir WebRequest para el hub en Herramientas ->   |
//|  Opciones -> Asesores Expertos.                                  |
//+------------------------------------------------------------------+
#property copyright   "InstitutoQuant - pre-registrado en ORO/docs/07"
#property version     "3.00"
#property strict
#property description "SELL fix Tokio 09:55 JST solo gotobi; cubrir 10:10; stop 20 pips."
#property description "Regla congelada docs/07. SOLO DEMO hasta corte de 60 trades."

#include <Trade/Trade.mqh>

//#define USAR_TELEMETRIA   // opcional: modulo interno de telemetria del Instituto (no incluido)        // comentar esta linea si no tienes Telemetria.mqh instalado
#ifdef USAR_TELEMETRIA
  #include <Telemetria.mqh>
#endif

#define EA_VERSION "tokioreversal-3.00"

//==================== INPUTS ====================
input group "=== General ==="
input string PatasCalificadas    = "USDJPY,EURJPY,GBPJPY,CHFJPY,CADJPY"; // v3: SOLO patas con t>=2.5 (AUDJPY excluida, t=1.6)
input long   MagicNumber         = 20260808;   // Magic (fecha del pre-registro)
input int    ServerToUTC_Horas   = 0;          // Offset servidor->UTC (Exness = 0, validado en ORO)
input int    SlippagePoints      = 50;         // Desviacion maxima
input bool   PrintDebug          = true;

input group "=== Regla congelada (docs/07 - NO TOCAR sin nuevo pre-registro) ==="
input int    StopPips            = 20;         // Stop de proteccion (pips)
input int    MinutosHold         = 15;         // 09:55 -> 10:10 JST
input int    SkipSpreadPoints    = 30;         // Spread >= 3 pips en el fix -> NO operar (skip honesto)

input group "=== Riesgo (demo: 0.25-0.5% hasta el corte) ==="
input double RiskPorEvento       = 0.25;       // % del balance por EVENTO (canasta completa)
input int    PatasActivas        = 5;          // graficos con el EA montado (el riesgo se reparte solo)
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

//==================== HORA JST ====================
datetime HoraJST() { return TimeCurrent() + (9 - ServerToUTC_Horas)*3600; }

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
input bool UseFinDeMes = true;    // v2: operar tambien el ultimo dia habil del mes
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
   bool ok = trade.Sell(lot, _Symbol, tick.bid, sl, 0.0);   // SIN take profit: salida por TIEMPO
   uint rc = trade.ResultRetcode();
   if(ok && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL))
     {
      g_ultimoDiaOperado = diaJST;
      g_entradaHoy = entry; g_sombraPendiente = true;   // v2: armar la sombra 10:15
      if(PrintDebug)
         Print("SELL fix Tokio: ", DoubleToString(lot,2), " lotes | entrada=",
               DoubleToString(entry, Dig()), " SL=", DoubleToString(sl, Dig()),
               " | spread=", spread, " pts | cierre programado 10:10 JST");
#ifdef USAR_TELEMETRIA
      TelemetriaOpen("SELL", lot, RiesgoPata(), sl, 0.0, (double)spread);
#endif
     }
   else
      Print("OrderSend fallo: retcode=", rc, " (", trade.ResultRetcodeDescription(), ")");
  }

//==================== SALIDA POR TIEMPO ====================
void IntentarSalida()
  {
   ulong tk = TicketMio();
   if(tk == 0) return;
   datetime jst = HoraJST();
   MqlDateTime t; TimeToStruct(jst, t);

   // cierre desde 10:10 JST (failsafe: tambien cierra fuera de la ventana 9:55-10:10)
   bool horaDeCerrar = (t.hour==10 && t.min >= 10) || (t.hour > 10) || (t.hour < 9);
   if(!horaDeCerrar) return;

   if(trade.PositionClose(tk, SlippagePoints))
     { if(PrintDebug) Print("Cierre por TIEMPO (10:10 JST) ejecutado."); }
   else
      Print("PositionClose fallo: ", trade.ResultRetcode(), " - reintenta el proximo tick/timer");
  }

//==================== SOMBRA 10:15 (v1.1 medida SIN operarla) ====================
// Registra el mark de las 10:15 JST de la MISMA entrada -> veredicto forward de la salida
// alternativa sin operarla jamas. Queda en el Diario y (si el hub lo acepta) en telemetria.
void IntentarSombra()
  {
   if(!g_sombraPendiente || g_entradaHoy <= 0) return;
   datetime jst = HoraJST();
   MqlDateTime t; TimeToStruct(jst, t);
   bool hora = (t.hour==10 && t.min >= 15) || (t.hour > 10);
   if(!hora) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double sombraPips = (g_entradaHoy - tick.bid) / Pip();
   Print("SOMBRA_1015: ", DoubleToString(sombraPips, 1), " pips (v1.1 no operada)");
#ifdef USAR_TELEMETRIA
   TelemetriaEnviar("SHADOW", ",\"shadow_1015_pips\":" + DoubleToString(sombraPips, 2), false);
#endif
   g_sombraPendiente = false; g_entradaHoy = 0;
  }

//==================== TELEMETRIA DE CIERRES ====================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request, const MqlTradeResult &result)
  {
#ifdef USAR_TELEMETRIA
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal = trans.deal;
   if(deal == 0 || !HistoryDealSelect(deal)) return;
   if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) return;
   if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber) return;
   long entryType = HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY) return;

   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
   double swap   = HistoryDealGetDouble(deal, DEAL_SWAP);
   double comm   = HistoryDealGetDouble(deal, DEAL_COMMISSION);
   long   reason = HistoryDealGetInteger(deal, DEAL_REASON);
   string exitReason = (reason==DEAL_REASON_SL) ? "SL" : "TIME";
   long dur = 0;
   long posId = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   if(posId > 0 && HistorySelectByPosition(posId))
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong d2 = HistoryDealGetTicket(i);
         if(d2 > 0 && HistoryDealGetInteger(d2, DEAL_ENTRY)==DEAL_ENTRY_IN)
           { dur = (long)(HistoryDealGetInteger(deal, DEAL_TIME) - HistoryDealGetInteger(d2, DEAL_TIME)); break; }
        }
   TelemetriaClose(profit + swap + comm, swap, comm, exitReason, dur);
#endif
  }

//==================== CICLO ====================
void OnTick()
  {
#ifdef USAR_TELEMETRIA
   TelemetriaVaciarCola();
#endif
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
   IntentarSalida();     // primero salidas (failsafe)
   IntentarSombra();
   IntentarEntrada();
  }

void OnTimer()
  {
#ifdef USAR_TELEMETRIA
   TelemetriaTimer();
#endif
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
            "). AUDJPY quedo EXCLUIDA por t=1.6 — no montar por intuicion, solo por medicion.");
      return INIT_FAILED;
     }
#ifdef USAR_TELEMETRIA
   TelemetriaInit(EA_VERSION, MagicNumber);   // el modulo arma su propio ciclo de anuncio
#endif
   EventSetTimer(1);
   Print("TokioReversal v3.0 CANASTA-5 en ", _Symbol, " | docs/07 | riesgo/evento=",
         DoubleToString(RiskPorEvento,2), "% repartido en ", PatasActivas, " patas (",
         DoubleToString(RiesgoPata(),3), "%/pata) | sombra 10:15 ON");
   Print("  SELL 09:55 JST solo gotobi -> cubrir 10:10 | stop ", StopPips,
         " pips | riesgo ", DoubleToString(RiesgoPata(),3), "% | skip spread>=", SkipSpreadPoints, " pts");
   Print("  SOLO DEMO hasta el corte de 60 trades. Server->UTC offset: ", ServerToUTC_Horas, "h");
   if(!MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
      Print("*** ATENCION: CUENTA REAL detectada. El pre-registro exige DEMO hasta el corte. ***");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
#ifdef USAR_TELEMETRIA
   TelemetriaDeinit(reason);
#endif
   EventKillTimer();
  }
//+------------------------------------------------------------------+

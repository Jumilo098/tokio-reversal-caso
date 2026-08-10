//+------------------------------------------------------------------+
//|                                            TokioReversal_v1.mq5  |
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
//|                                                                  |
//|  == v1.10 EXNESS (robustez de EJECUCION, la REGLA no cambia) ==  |
//|   * Reloj: TimeTradeServer() (avanza sin ticks -> salida 10:10  |
//|     puntual aunque el mercado asiatico este quieto).             |
//|   * Filling: SetTypeFillingBySymbol (evita rechazo 10030 en      |
//|     Exness por "unsupported filling mode").                      |
//+------------------------------------------------------------------+
#property copyright   "InstitutoQuant - pre-registrado en ORO/docs/07"
#property version     "1.10"
#property strict
#property description "SELL fix Tokio 09:55 JST solo gotobi; cubrir 10:10; stop 20 pips."
#property description "Regla congelada docs/07. SOLO DEMO hasta corte de 60 trades."

#include <Trade/Trade.mqh>

//#define USAR_TELEMETRIA   // opcional: modulo interno de telemetria del Instituto (no incluido)        // comentar esta linea si no tienes Telemetria.mqh instalado
#ifdef USAR_TELEMETRIA
  #include <Telemetria.mqh>
#endif

#define EA_VERSION "tokioreversal-1.00"

//==================== INPUTS ====================
input group "=== General ==="
input string SymbolLock          = "USDJPY";   // Candado de simbolo (el chart debe contenerlo)
input long   MagicNumber         = 20260808;   // Magic (fecha del pre-registro)
input int    ServerToUTC_Horas   = 0;          // Offset servidor->UTC (Exness = 0, validado en ORO)
input int    SlippagePoints      = 50;         // Desviacion maxima
input bool   PrintDebug          = true;

input group "=== Regla congelada (docs/07 - NO TOCAR sin nuevo pre-registro) ==="
input int    StopPips            = 20;         // Stop de proteccion (pips)
input int    MinutosHold         = 15;         // 09:55 -> 10:10 JST
input int    SkipSpreadPoints    = 30;         // Spread >= 3 pips en el fix -> NO operar (skip honesto)

input group "=== Riesgo (demo: 0.25-0.5% hasta el corte) ==="
input double RiskPercent         = 0.25;       // % del balance por trade
input double MaxLotSize          = 5.0;        // Tope duro (si recorta, se LOGUEA el riesgo real)

//==================== GLOBALES ====================
CTrade   trade;
datetime g_ultimoDiaOperado = 0;   // fecha JST (00:00) del ultimo trade/skip

double Pt()  { return SymbolInfoDouble(_Symbol, SYMBOL_POINT); }
int    Dig() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }
double Pip() { return (Dig()==3 || Dig()==5) ? 10.0*Pt() : Pt(); }
double ND(const double p) { return NormalizeDouble(p, Dig()); }

//==================== HORA JST ====================
// TimeTradeServer() = hora de servidor calculada (avanza SIN ticks). Clave para que
// la salida 10:10 y la entrada 09:55 disparen puntuales aunque el mercado este quieto.
datetime HoraJST() { return TimeTradeServer() + (9 - ServerToUTC_Horas)*3600; }

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

   // ventana de entrada: 09:55:00 - 09:56:59 JST (gracia de ~2 min por lag)
   if(t.hour != 9 || t.min < 55 || t.min > 56) return;  // FIX M1: cierra la ventana (antes llegaba a 09:59:59)
   if(!EsGotobiJST(jst)) return;

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
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * Pt();
   if(sl - entry < minStop) sl = ND(entry + minStop + Pt());  // FIX M3: respeta stops level (evita retcode 10016)
   double dist  = sl - entry;

   // sizing por riesgo contra el stop
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;
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
   if(lot > MaxLotSize)
     {
      // LECCION del caso TrendFilter: si el tope recorta, el riesgo real ya no es RiskPercent.
      double riesgoReal = MaxLotSize * lossPerLot / balance * 100.0;
      Print("AVISO: lote recortado por MaxLotSize (", DoubleToString(lot,2), " -> ",
            DoubleToString(MaxLotSize,2), "). Riesgo REAL: ", DoubleToString(riesgoReal,2),
            "% (no ", DoubleToString(RiskPercent,2), "%)");
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
      if(PrintDebug)
         Print("SELL fix Tokio: ", DoubleToString(lot,2), " lotes | entrada=",
               DoubleToString(entry, Dig()), " SL=", DoubleToString(sl, Dig()),
               " | spread=", spread, " pts | cierre programado 10:10 JST");
#ifdef USAR_TELEMETRIA
      TelemetriaOpen("SELL", lot, RiskPercent, sl, 0.0, (double)spread);
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
   IntentarEntrada();
  }

void OnTimer()
  {
#ifdef USAR_TELEMETRIA
   TelemetriaTimer();
#endif
   // timer de 1s: precision del 09:55/10:10 aunque no lleguen ticks (mercado asiatico quieto)
   IntentarSalida();
   IntentarEntrada();
  }

int OnInit()
  {
   if(StringLen(SymbolLock) > 0 && StringFind(_Symbol, SymbolLock) < 0)
     {
      Print("ERROR: SymbolLock=", SymbolLock, " pero el chart es ", _Symbol);
      return INIT_FAILED;
     }
#ifdef USAR_TELEMETRIA
   TelemetriaInit(EA_VERSION, MagicNumber);   // el modulo arma su propio ciclo de anuncio
#endif
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);   // Exness: filling que el simbolo soporta (evita retcode 10030)
   trade.SetDeviationInPoints(SlippagePoints);
   EventSetTimer(1);
   Print("TokioReversal v1.10 EXNESS en ", _Symbol, " | regla congelada docs/07 (2026-08-08)");
   Print("  SELL 09:55 JST solo gotobi -> cubrir 10:10 | stop ", StopPips,
         " pips | riesgo ", DoubleToString(RiskPercent,2), "% | skip spread>=", SkipSpreadPoints, " pts");
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

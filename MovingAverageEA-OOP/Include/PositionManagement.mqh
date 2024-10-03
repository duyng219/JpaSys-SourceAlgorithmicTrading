//+------------------------------------------------------------------+
//|                                           PositionManagement.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property version   "1.00"

#include "Trade.mqh"
//AdjustStopLevel is used by SL, TP, TSL & BE functions

//+------------------------------------------------------------------+
//| CPM Class - Stop Loss, Take Profit, TSL & BE                     |
//+------------------------------------------------------------------+

class CPM
{
    private:
        /* data */
    public:
        MqlTradeRequest request;
        MqlTradeResult  result;
        
        CPM(void);

        double CalculateStopLoss(string pSymbol, string pEntrySignal, int pSLFixedPoints, int pSLFixedPointsMA, double pMA);
        double CalculateTakeProfit(string pSymbol, string pEntrySignal, int pTPFixedPoints);

        void TrailingStopLoss(string pSymbol, ulong pMagic, int pTSLFixedPoints);   //Hedging
        void TrailingStopLoss(string pSymbol, int pTSLFixedPoints);                 //Netting
        void BreakEven(string pSymbol, ulong pMagic, int pBEFixedPoints);            //Hedging
        void BreakEven(string pSymbol, int pBEFixedPoints);                          //Netting
};

//+------------------------------------------------------------------+
//| CPM Class Methods                                                |
//+------------------------------------------------------------------+

CPM::CPM(void)
{
    ZeroMemory(request);
    ZeroMemory(result);
}

double CPM::CalculateStopLoss(string pSymbol, string pEntrySignal, int pSLFixedPoints, int pSLFixedPointsMA, double pMA)
{
    double stoploss = 0.0;
    double askPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);
    double tickSize = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(pSymbol,SYMBOL_POINT);

    if(pEntrySignal == "LONG")
    {
        if(pSLFixedPoints > 0) stoploss = askPrice - (pSLFixedPoints * point); //1.11125 - (100 * 0.00001)
        else if(pSLFixedPointsMA > 0) stoploss = pMA - (pSLFixedPointsMA * point);

        if(stoploss > 0) stoploss = AdjustBelowStopLevel(pSymbol,askPrice,stoploss);
    }
    else if(pEntrySignal == "SHORT")
    {
        if(pSLFixedPoints > 0) stoploss = bidPrice + (pSLFixedPoints * point); //1.11125 + (100 * 0.00001)
        else if(pSLFixedPointsMA > 0) stoploss = pMA + (pSLFixedPointsMA * point);

        if(stoploss > 0) stoploss = AdjustAboveStopLevel(pSymbol,bidPrice,stoploss);
    }

    stoploss = round(stoploss/tickSize) * tickSize;
    return stoploss;
}

double CPM::CalculateTakeProfit(string pSymbol, string pEntrySignal, int pTPFixedPoints)
{
    double takeprofit = 0.0;
    double askPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);
    double tickSize = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(pSymbol,SYMBOL_POINT);

    if(pEntrySignal == "LONG")
    {
        if(pTPFixedPoints > 0) takeprofit = askPrice + (pTPFixedPoints * point); //1.11125 + (100 * 0.00001)

        if(takeprofit > 0) takeprofit = AdjustAboveStopLevel(pSymbol,askPrice,takeprofit);
    }
    else if(pEntrySignal == "SHORT")
    {
        if(pTPFixedPoints > 0) takeprofit = bidPrice - (pTPFixedPoints * point); //1.11125 - (100 * 0.00001)

        if(takeprofit > 0) takeprofit = AdjustBelowStopLevel(pSymbol,bidPrice,takeprofit);
    }

    takeprofit = round(takeprofit/tickSize) * tickSize;
    return takeprofit;
}

//HEDGING
void CPM::TrailingStopLoss(string pSymbol, ulong pMagic, int pTSLFixedPoints)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        //Reset of request and result values
        ZeroMemory(request);
        ZeroMemory(result);

        ulong positionTicket = PositionGetTicket(i);
        PositionSelectByTicket(positionTicket);

        string  posSymbol        = PositionGetString(POSITION_SYMBOL);
        ulong   posMagic         = PositionGetInteger(POSITION_MAGIC);
        ulong   posType          = PositionGetInteger(POSITION_TYPE);
        double  currentStopLoss  = PositionGetDouble(POSITION_SL);
        double  tickSize         = SymbolInfoDouble(posSymbol,SYMBOL_TRADE_TICK_SIZE);
        double  point            = SymbolInfoDouble(posSymbol,SYMBOL_POINT);

        double bidPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);  
        double askPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);       
        double newStopLoss;

        if(posSymbol == pSymbol && posMagic == pMagic && posType == ORDER_TYPE_BUY)
        {
            newStopLoss = askPrice - (pTSLFixedPoints * point);
            newStopLoss = AdjustBelowStopLevel(pSymbol,askPrice,newStopLoss);
            newStopLoss = round(newStopLoss/tickSize) * tickSize;

            if(newStopLoss > currentStopLoss)
            // if(NormalizeDouble(newStopLoss-currentStopLoss,_Digits) > 0 || currentStopLoss==0)
            {
                request.action   = TRADE_ACTION_SLTP;
                request.position = positionTicket;
                request.comment  = "TSL. " + " | " + pSymbol + " | " + string(pMagic);
                request.sl       = newStopLoss;
                request.tp       = PositionGetDouble(POSITION_TP);
            }
        }
        else if(posSymbol == pSymbol && posMagic == pMagic && posType == ORDER_TYPE_SELL)
        {
            newStopLoss = bidPrice + (pTSLFixedPoints * point);
            newStopLoss = AdjustAboveStopLevel(pSymbol,askPrice,newStopLoss);
            newStopLoss = round(newStopLoss/tickSize) * tickSize;

            if(newStopLoss < currentStopLoss)
            // if(NormalizeDouble(newStopLoss-currentStopLoss,_Digits) < 0 || currentStopLoss==0)
            {
                request.action = TRADE_ACTION_SLTP;
                request.position = positionTicket;
                request.comment = "TSL. " + " | " + pSymbol + " | " + string(pMagic);
                request.sl = newStopLoss;
                request.tp = PositionGetDouble(POSITION_TP);
            }
        }

        if(request.sl > 0)
        {
            bool sent = OrderSend(request,result);
            if(!sent) Print("OrderSend TSL error: ", GetLastError());
        }
    }
}

//NETTING
void CPM::TrailingStopLoss(string pSymbol, int pTSLFixedPoints)
{
    if(!PositionSelect(pSymbol)) return;

    //Reset of request and result values
    ZeroMemory(request);
    ZeroMemory(result);

    string posSymbol        = PositionGetString(POSITION_SYMBOL);
    ulong posMagic          = PositionGetInteger(POSITION_MAGIC);
    ulong posType           = PositionGetInteger(POSITION_TYPE);
    double currentStopLoss  = PositionGetDouble(POSITION_SL);
    double tickSize         = SymbolInfoDouble(posSymbol,SYMBOL_TRADE_TICK_SIZE);
    double  point            = SymbolInfoDouble(posSymbol,SYMBOL_POINT);

    double bidPrice = SymbolInfoDouble(posSymbol,SYMBOL_BID);  
    double askPrice = SymbolInfoDouble(posSymbol,SYMBOL_ASK);       
    double newStopLoss;

    if(posSymbol == pSymbol && posType == ORDER_TYPE_BUY)
    {
        newStopLoss = askPrice - (pTSLFixedPoints * point);
        newStopLoss = AdjustBelowStopLevel(posSymbol,askPrice,newStopLoss);
        newStopLoss = round(newStopLoss/tickSize) * tickSize;

        if(newStopLoss > currentStopLoss)
        {
            request.action = TRADE_ACTION_SLTP;
            request.symbol = posSymbol;
            request.comment = "TSL. " + " | " + posSymbol;
            request.sl = newStopLoss;
            request.tp = PositionGetDouble(POSITION_TP);
        }
    }
    else if(posSymbol == pSymbol && posType == ORDER_TYPE_SELL)
    {
        newStopLoss = bidPrice + (pTSLFixedPoints * point);
        newStopLoss = AdjustAboveStopLevel(posSymbol,askPrice,newStopLoss);
        newStopLoss = round(newStopLoss/tickSize) * tickSize;

        if(newStopLoss < currentStopLoss)
        {
            request.action = TRADE_ACTION_SLTP;
            request.symbol = posSymbol;
            request.comment = "TSL. " + " | " + pSymbol;
            request.sl = newStopLoss;
            request.tp = PositionGetDouble(POSITION_TP);
        }
    }

    if(request.sl > 0)
    {
        bool sent = OrderSend(request,result);
        if(!sent) Print("OrderSend TSL error: ", GetLastError());
    }
}

//HEDGING
void CPM::BreakEven(string pSymbol, ulong pMagic, int pBEFixedPoints)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        //Reset of request and result values
        ZeroMemory(request);
        ZeroMemory(result);

        ulong positionTicket = PositionGetTicket(i);
        PositionSelectByTicket(positionTicket);

        string posSymbol         = PositionGetString(POSITION_SYMBOL);
        ulong posMagic           = PositionGetInteger(POSITION_MAGIC);
        ulong posType            = PositionGetInteger(POSITION_TYPE);
        double currentStopLoss   = PositionGetDouble(POSITION_SL);
        double tickSize          = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
        double openPrice         = PositionGetDouble(POSITION_PRICE_OPEN);
        double point             = SymbolInfoDouble(pSymbol,SYMBOL_POINT);
        double newStopLoss       = round(openPrice/tickSize) * tickSize;

        if(posSymbol == pSymbol && posMagic == pMagic && posType == ORDER_TYPE_BUY)
        {
            double bidPrice      = SymbolInfoDouble(pSymbol,SYMBOL_BID);
            double BEThreshould  = openPrice + (pBEFixedPoints*point);

            if(newStopLoss > currentStopLoss && bidPrice > BEThreshould)
            {
                request.action   = TRADE_ACTION_SLTP;
                request.position = positionTicket;
                request.comment  = "BE. " + " | " + pSymbol + " | " + string(pMagic);
                request.sl       = newStopLoss;
                request.tp       = PositionGetDouble(POSITION_TP);
            }
        }
        else if(posSymbol == pSymbol && posMagic == pMagic && posType == ORDER_TYPE_SELL)
        {
            double askPrice      = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
            double BEThreshould  = openPrice - (pBEFixedPoints*point);

            if(newStopLoss < currentStopLoss && askPrice < BEThreshould)
            {
                request.action   = TRADE_ACTION_SLTP;
                request.position = positionTicket;
                request.comment  = "BE. " + " | " + pSymbol + " | " + string(pMagic);
                request.sl       = newStopLoss;
                request.tp       = PositionGetDouble(POSITION_TP);
            }
        }

        if(request.sl > 0)
        {
            bool sent = OrderSend(request,result);
            if(!sent) Print("OrderSend TSL error: ", GetLastError());
        }
    }
}

//NETTING
void CPM::BreakEven(string pSymbol, int pBEFixedPoints)
{
    if(!PositionSelect(pSymbol)) return;

    //Reset of request and result values
    ZeroMemory(request);
    ZeroMemory(result);

    string posSymbol         = PositionGetString(POSITION_SYMBOL);
    ulong posMagic           = PositionGetInteger(POSITION_MAGIC);
    ulong posType            = PositionGetInteger(POSITION_TYPE);
    double currentStopLoss   = PositionGetDouble(POSITION_SL);
    double tickSize          = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    double openPrice         = PositionGetDouble(POSITION_PRICE_OPEN);
    double point             = SymbolInfoDouble(pSymbol,SYMBOL_POINT);
    double newStopLoss       = round(openPrice/tickSize) * tickSize;

    if(posSymbol == pSymbol && posType == ORDER_TYPE_BUY)
    {
        double bidPrice      = SymbolInfoDouble(pSymbol,SYMBOL_BID);
        double BEThreshould  = openPrice + (pBEFixedPoints*point);

        if(newStopLoss > currentStopLoss && bidPrice > BEThreshould)
        {
            request.action   = TRADE_ACTION_SLTP;
            request.symbol   = pSymbol;
            request.comment  = "BE. " + " | " + pSymbol;
            request.sl       = newStopLoss;
            request.tp       = PositionGetDouble(POSITION_TP);
        }
    }
    else if(posSymbol == pSymbol && posType == ORDER_TYPE_SELL)
    {
        double askPrice      = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
        double BEThreshould  = openPrice - (pBEFixedPoints*point);

        if(newStopLoss < currentStopLoss && askPrice < BEThreshould)
        {
            request.action   = TRADE_ACTION_SLTP;
            request.symbol   = pSymbol;
            request.comment  = "BE. " + " | " + pSymbol;
            request.sl       = newStopLoss;
            request.tp       = PositionGetDouble(POSITION_TP);
        }
    }

    if(request.sl > 0)
    {
        bool sent = OrderSend(request,result);
        if(!sent) Print("OrderSend TSL error: ", GetLastError());
    }
}
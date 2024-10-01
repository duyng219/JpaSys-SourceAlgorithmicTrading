//+------------------------------------------------------------------+
//|                                                        Trade.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CcTrade Class - Send Orders To Open, Close and Modify Positions  |
//+------------------------------------------------------------------+

class CTrade 
{
    protected:
        ulong                       OpenPosition(string pSymbol, ENUM_ORDER_TYPE pType, double pVolume, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL);

        ulong                       magicNumber;
        ulong                       deviation;
        ENUM_ORDER_TYPE_FILLING     fillingType;
        ENUM_ACCOUNT_MARGIN_MODE    marginMode;

    public:
        MqlTradeRequest             request;
        MqlTradeResult              result;

                                    CTrade(void);

    // Trade Methods
        ulong                       Buy(string pSymbol, double pVolume, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL);
        ulong                       Sell(string pSymbol, double pVolume, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL);
        
        void                        ModifyPosition(string pSymbol, ulong pTicket, double pStopLoss=0, double pTakeProfit=0);
        void                        CloseTrades(string pSymbol, string pExitSignal);

     // trade auxiliary methods
        void                        SetMarginMode(void) {marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);}
        bool                        IsHedging(void) { return(marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);}

        void                        SetMagicNumber(ulong pMagicNumber)  {   magicNumber = pMagicNumber;                 }
        void                        SetDeviation(ulong pDeviation )     {   deviation = pDeviation;                     }
        void                        SetFillingType(ENUM_ORDER_TYPE_FILLING pFillingType) {  fillingType = pFillingType; }

        bool                        SelectPosition(string pSymbol);

};

//+------------------------------------------------------------------+
//| CTrade Class Methods
//+------------------------------------------------------------------+

CTrade::CTrade(void)
{
    SetMarginMode();

    ZeroMemory(request);
    ZeroMemory(result);
}

ulong CTrade::OpenPosition(string pSymbol, ENUM_ORDER_TYPE pType, double pVolume, double pStopLoss=0.000000, double pTakeProfit=0.000000, string pComment=NULL)
{
    ZeroMemory(request);
    ZeroMemory(result);

    //Request Parameters
    request.action       = TRADE_ACTION_DEAL;
    request.symbol       = pSymbol;
    request.volume       = pVolume;
    request.type         = pType;
    request.deviation    = deviation;
    request.magic        = magicNumber;
    request.comment      = pComment;
    request.type_filling = fillingType;
    request.sl           = pStopLoss;
    request.tp           = pTakeProfit; 

    //Request Send
    if(!OrderSend(request,result))
      Print("OrderSend trade placement error: ", GetLastError()); //if request was not send, print error code

    //Trade Information - result.price not used for market orders
    Print("Order #",result.order," sent: ",result.retcode,", Volume: ",result.volume,", Price: ",result.price,", Bid: ",result.bid,", Ask: ",result.ask);

    if( result.retcode == TRADE_RETCODE_DONE         || 
        result.retcode == TRADE_RETCODE_DONE_PARTIAL ||
        result.retcode == TRADE_RETCODE_PLACED       || 
        result.retcode == TRADE_RETCODE_NO_CHANGES )
    {
      return result.order;
    }
    else return 0;
}

ulong CTrade::Buy(string pSymbol, double pVolume, double pStopLoss=0.000000, double pTakeProfit=0.000000, string pComment=NULL)
{
    pComment = "BUY" + " | " + pSymbol + " | " + string(magicNumber);

    ulong ticket = OpenPosition(pSymbol,ORDER_TYPE_BUY,pVolume,pStopLoss,pTakeProfit,pComment);
    return(ticket);
}

ulong CTrade::Sell(string pSymbol, double pVolume, double pStopLoss=0.000000, double pTakeProfit=0.000000, string pComment=NULL)
{
    pComment = "SELL" + " | " + pSymbol + " | " + string(magicNumber);

    ulong ticket = OpenPosition(pSymbol,ORDER_TYPE_SELL,pVolume,pStopLoss,pTakeProfit,pComment);
    return(ticket);
}

void CTrade::ModifyPosition(string pSymbol, ulong pTicket, double pStopLoss=0.000000, double pTakeProfit=0.000000)
{
    if(!SelectPosition(pSymbol)) return;

    ZeroMemory(request);
    ZeroMemory(result);

    double tickSize = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    int digits      = (int)SymbolInfoInteger(pSymbol,SYMBOL_DIGITS);

    if(pStopLoss>0) pStopLoss       = round(pStopLoss/tickSize) * tickSize;
    if(pTakeProfit>0) pTakeProfit   = round(pTakeProfit/tickSize) * tickSize;

    if(IsHedging()) request.position = pTicket;

    request.action   = TRADE_ACTION_SLTP;
    request.symbol   = pSymbol;
    request.sl       = pStopLoss;
    request.tp       = pTakeProfit;
    request.comment  = "MOD. " + " | " + pSymbol + " | " + string(magicNumber) + ", SL: " + DoubleToString(request.sl,digits) + ", TP: " + DoubleToString(request.tp,digits);

    if(request.sl > 0 || request.tp > 0)
    {
        Sleep(1000);
        bool send = OrderSend(request,result);
        Print(result.comment);

        if(!send){
        Print("OrderSend Modification error: ", GetLastError());
        Sleep(3000);

        send = OrderSend(request,result);
        Print(result.comment);
        if(!send) Print("OrderSend Modification error: ", GetLastError());
        }
    }
}

void CTrade::CloseTrades(string pSymbol, string pExitSignal)
{
    if(!SelectPosition(pSymbol)) return;
    
    bool isHedging = IsHedging();

    //Reset of request and result values
    ZeroMemory(request);
    ZeroMemory(result);

    ulong posMagic    = PositionGetInteger(POSITION_MAGIC);
    ulong posType     = PositionGetInteger(POSITION_TYPE);
    ulong posTicket   = PositionGetInteger(POSITION_TICKET);
    string posSymbol  = PositionGetString(POSITION_SYMBOL);

    if(posSymbol == pSymbol && posMagic == magicNumber && pExitSignal == "EXIT_LONG" && posType == ORDER_TYPE_BUY)
    {
      request.action        = TRADE_ACTION_DEAL;
      request.type          = ORDER_TYPE_SELL;
      request.symbol        = pSymbol;
      request.volume        = PositionGetDouble(POSITION_VOLUME);
      request.price         = SymbolInfoDouble(pSymbol,SYMBOL_BID);
      request.deviation     = deviation;
      request.type_filling  = fillingType;

      if(isHedging) request.position = posTicket;
    }
    else if(posSymbol == pSymbol &&posMagic == magicNumber && pExitSignal == "EXIT_SHORT" && posType == ORDER_TYPE_SELL)
    {
      request.action        = TRADE_ACTION_DEAL;
      request.type          = ORDER_TYPE_BUY;
      request.symbol        = pSymbol;
      request.volume        = PositionGetDouble(POSITION_VOLUME);
      request.price         = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
      request.deviation     = deviation;
      request.type_filling  = fillingType;

      if(isHedging) request.position = posTicket;
    }

     //Request Send
    if(!OrderSend(request,result))
      Print("OrderSend trade close error: ", GetLastError()); //if request was not send, print error code

    if( result.retcode == TRADE_RETCODE_DONE         || 
        result.retcode == TRADE_RETCODE_DONE_PARTIAL ||
        result.retcode == TRADE_RETCODE_PLACED       || 
        result.retcode == TRADE_RETCODE_NO_CHANGES )
    {
      Print(pSymbol, " #", posTicket, " closed");
    }
}

// Func kiểm tra tài khoản là Hedging or Netting & Kiểm tra có vị thế đang mở ở Symbol hiện tại hay không? if no => false
bool CTrade::SelectPosition(string pSymbol)
{
    bool res = false;

    if(IsHedging())
    {
        int total = PositionsTotal();
        for(int i = total -1; i >= 0; i--)
        {
            string positionSymbol = PositionGetSymbol(i);

            if(positionSymbol == pSymbol && magicNumber == PositionGetInteger(POSITION_MAGIC))
            {
                res = true;
                break;
            }
        }
    }
    else
        res = PositionSelect(pSymbol);

    return(res);
}


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
        bool                        OpenPending(string pSymbol, ENUM_ORDER_TYPE pType, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, double pStopLimit=0, datetime pExpiration=0, string pComment=NULL);
        
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

        bool                        BuyStop(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL);
        bool                        SellStop(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL);

        bool                        BuyLimit(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL);
        bool                        SellLimit(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL);

        bool                        BuyStopLimit(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, double pStopLimit=0, datetime pExpiration=0, string pComment=NULL);
        bool                        SellStopLimit(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, double pStopLimit=0, datetime pExpiration=0, string pComment=NULL);
        
        void                        ModifyPosition(string pSymbol, ulong pTicket, double pStopLoss=0, double pTakeProfit=0);
        void                        ModifyPending(ulong pTicket, double pPrice=0, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0);

        void                        CloseTrades(string pSymbol, string pExitSignal);
        void                        Delete(ulong pTicket);

      datetime           GetExpirationTime(ushort pOrderExpirationMinutes);	
      ulong              GetPendingTicket(string pSymbol,ulong pMagic);

     // trade auxiliary methods
        void                        SetMarginMode(void) {marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);}
        bool                        IsHedging(void) { return(marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);}

        void                        SetMagicNumber(ulong pMagicNumber)  {   magicNumber = pMagicNumber;                 }
        void                        SetDeviation(ulong pDeviation )     {   deviation = pDeviation;                     }
        void                        SetFillingType(ENUM_ORDER_TYPE_FILLING pFillingType) {  fillingType = pFillingType; }

        bool                        SelectPosition(string pSymbol);

};

//+------------------------------------------------------------------+
//| CTrade Class Methods                                             |
//+------------------------------------------------------------------+

CTrade::CTrade(void)
{
    SetMarginMode();

    ZeroMemory(request);
    ZeroMemory(result);
}

ulong CTrade::OpenPosition(string pSymbol, ENUM_ORDER_TYPE pType, double pVolume, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL)
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

bool CTrade::OpenPending(string pSymbol, ENUM_ORDER_TYPE pType, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, double pStopLimit=0, datetime pExpiration=0, string pComment=NULL)
{
    ZeroMemory(request);
    ZeroMemory(result);

    //Request Parameters
    request.action       = TRADE_ACTION_PENDING;
    request.symbol       = pSymbol;
    request.volume       = pVolume;
    request.type         = pType;
    request.deviation    = deviation;
    request.magic        = magicNumber;
    request.comment      = pComment;
    request.type_filling = fillingType;
    request.sl           = pStopLoss;
    request.tp           = pTakeProfit;
    request.stoplimit    = pStopLimit;

    double tickSize      = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    request.price        = round(pPrice/tickSize) * tickSize;

    if(pExpiration > 0)
    {
      request.expiration   = pExpiration;
      request.type_time    = ORDER_TIME_SPECIFIED;
    }
    else request.type_time = ORDER_TIME_GTC;

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
      return true;
    }
    else return false;
}

ulong CTrade::Buy(string pSymbol, double pVolume, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL)
{
    pComment = "BUY" + " | " + pSymbol + " | " + string(magicNumber);

    ulong ticket = OpenPosition(pSymbol,ORDER_TYPE_BUY,pVolume,pStopLoss,pTakeProfit,pComment);
    return(ticket);
}

ulong CTrade::Sell(string pSymbol, double pVolume, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL)
{
    pComment = "SELL" + " | " + pSymbol + " | " + string(magicNumber);

    ulong ticket = OpenPosition(pSymbol,ORDER_TYPE_SELL,pVolume,pStopLoss,pTakeProfit,pComment);
    return(ticket);
}

bool CTrade::BuyStop(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL)
{
    pComment = "BUY S" + " | " + pSymbol + " | " + string(magicNumber);

    bool success = OpenPending(pSymbol,ORDER_TYPE_BUY_STOP,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
    return(success);  
}

bool CTrade::SellStop(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL)
{
    pComment = "SELL S" + " | " + pSymbol + " | " + string(magicNumber);

    bool success = OpenPending(pSymbol,ORDER_TYPE_SELL_STOP,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
    return(success);
}

bool CTrade::BuyLimit(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL)
{
    pComment = "BUY L" + " | " + pSymbol + " | " + string(magicNumber);

    bool success = OpenPending(pSymbol,ORDER_TYPE_BUY_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
    return(success);
}

bool CTrade::SellLimit(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0, string pComment=NULL)
{
    pComment = "SELL L" + " | " + pSymbol + " | " + string(magicNumber);

    bool success = OpenPending(pSymbol,ORDER_TYPE_SELL_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
    return(success);
}

bool CTrade::BuyStopLimit(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, double pStopLimit=0, datetime pExpiration=0, string pComment=NULL)
{
    pComment = "BUY S-L" + " | " + pSymbol + " | " + string(magicNumber);

    bool success = OpenPending(pSymbol,ORDER_TYPE_BUY_STOP_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,pStopLimit,pExpiration,pComment);
    return(success);
}

bool CTrade::SellStopLimit(string pSymbol, double pVolume,double pPrice, double pStopLoss=0, double pTakeProfit=0, double pStopLimit=0, datetime pExpiration=0, string pComment=NULL)
{
    pComment = "SELL S-L" + " | " + pSymbol + " | " + string(magicNumber);

    bool success = OpenPending(pSymbol,ORDER_TYPE_SELL_STOP_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,pStopLimit,pExpiration,pComment);
    return(success);
}

void CTrade::ModifyPosition(string pSymbol, ulong pTicket, double pStopLoss=0, double pTakeProfit=0)
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
        if(!send) Print("OrderSend 2nd Try Modification error: ", GetLastError());
        }

      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_NO_CHANGES) 
      {
         Print(pSymbol, " #",pTicket, " modified");
      }			
    }
}

void CTrade::ModifyPending(ulong pTicket, double pPrice=0, double pStopLoss=0, double pTakeProfit=0, datetime pExpiration=0)
{
    if(!OrderSelect(pTicket)) {
      Print("Error selecting order ", pTicket); return;}
    
    if(pPrice == 0 && pStopLoss == 0 && pTakeProfit == 0 && pExpiration == 0) return;

    ZeroMemory(request);
    ZeroMemory(result);
      
    string orderSymbol   = OrderGetString(ORDER_SYMBOL);
    ulong orderMagic     = OrderGetInteger(ORDER_MAGIC);
    double tickSize      = SymbolInfoDouble(orderSymbol,SYMBOL_TRADE_TICK_SIZE);
    int digits           = (int)SymbolInfoInteger(orderSymbol,SYMBOL_DIGITS);
    
    if(pPrice > 0)       request.price        = pPrice;
    if(pStopLoss > 0)    request.sl           = pStopLoss;
    if(pTakeProfit > 0)  request.tp           = pTakeProfit;	
    
    if(pExpiration > 0) 
    {
      request.expiration = pExpiration;
      request.type_time = ORDER_TIME_SPECIFIED;
    }

    request.action    = TRADE_ACTION_MODIFY;
    request.order     = pTicket;
    request.comment  = "MOD.P" + " | " + orderSymbol + " | " + string(orderMagic); 
    
    bool sent = OrderSend(request,result);
    Print(result.comment);
    
    if(!sent) 
    {
      Print("OrderSend Modification error: ", GetLastError());
      Sleep(3000);
      
      sent = OrderSend(request,result);
      Print(result.comment);
      if(!sent) Print("OrderSend 2nd Try Modification error: ", GetLastError());
    }
    
    if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_NO_CHANGES) 
    {
        Print(orderSymbol, " #",pTicket, " modified");
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

void CTrade::Delete(ulong pTicket)
{
	if(!OrderSelect(pTicket)) {
	   Print("Error selecting order ", pTicket); return;}
	  	
	ZeroMemory(request);
	ZeroMemory(result);

	string orderSymbol = OrderGetString(ORDER_SYMBOL);
	
	request.action    = TRADE_ACTION_REMOVE;
	request.order     = pTicket;
  request.comment   = "DELETED O#" + string(pTicket) + " | " + orderSymbol;
   
   if(!OrderSend(request,result))
      Print("OrderSend delete pending error: ", GetLastError());     //if request was not send, print error code
	   		
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_NO_CHANGES) 
	{
      Print(orderSymbol, " #",pTicket, " deleted");
   }
}	

//Get expiration time for pending orders on seconds
datetime CTrade::GetExpirationTime(ushort pOrderExpirationMinutes)
{
   datetime orderExpirationSeconds = TimeCurrent() + pOrderExpirationMinutes * 60;
   
   return(orderExpirationSeconds); 
}

ulong CTrade::GetPendingTicket(string pSymbol, ulong pMagic)
{
	int total=OrdersTotal(); 
	   
   for(int i=total-1; i>=0; i--)
   {
      ulong orderTicket = OrderGetTicket(i);                   
      ulong magic       = OrderGetInteger(ORDER_MAGIC);              
      string symbol     = OrderGetString(ORDER_SYMBOL);
      
      if(magic==pMagic && symbol == pSymbol) return(orderTicket);
   }
   
   return 0; 
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

//+------------------------------------------------------------------+
//| NON-CLASS TRADE FUNCTIONS                                        |
//+------------------------------------------------------------------+

double AdjustAboveStopLevel(string pSymbol ,double pCurrentPrice, double pPriceToAdjust, int pPointsToAdd = 10)
{
  double adjustedPrice = pPriceToAdjust;

  double point = SymbolInfoDouble(pSymbol,SYMBOL_POINT);
  long stopsLevel = SymbolInfoInteger(pSymbol,SYMBOL_TRADE_STOPS_LEVEL);

  if(stopsLevel > 0)
  {
    double stopsLevelPrice = stopsLevel * point;        //stops level points in price
    stopsLevelPrice = pCurrentPrice + stopsLevelPrice;  //stops price level - distance from bid/ask

    double addPoints = pPointsToAdd * point;            // Points that will be added/substracted to stops level price to make sure we respect the distance fixed by stops level

    if(adjustedPrice <= stopsLevelPrice + addPoints)
    {
      adjustedPrice = stopsLevelPrice + addPoints;
      Print("Price adjusted above stop level to " + string(adjustedPrice));
    }
  }
  return adjustedPrice;
}

double AdjustBelowStopLevel(string pSymbol ,double pCurrentPrice, double pPriceToAdjust, int pPointsToAdd = 10)
{
  double adjustedPrice = pPriceToAdjust;

  double point = SymbolInfoDouble(pSymbol,SYMBOL_POINT);
  long stopsLevel = SymbolInfoInteger(pSymbol,SYMBOL_TRADE_STOPS_LEVEL);

  if(stopsLevel > 0)
  {
    double stopsLevelPrice = stopsLevel * point;        //stops level points in price
    stopsLevelPrice = pCurrentPrice - stopsLevelPrice;  //stops price level - distance from bid/ask

    double addPoints = pPointsToAdd * point;            // Points that will be added/substracted to stops level price to make sure we respect the distance fixed by stops level

    if(adjustedPrice >= stopsLevelPrice - addPoints)
    {
      adjustedPrice = stopsLevelPrice - addPoints;
      Print("Price adjusted below stop level to " + string(adjustedPrice));
    }
  }
  return adjustedPrice;
}

//Delay program execution when market is closed
void DelayOnMarketClosed(ENUM_TIMEFRAMES pTimeframe)
{
  //Current time
  MqlDateTime time;
  TimeCurrent(time);

  if(MQLInfoInteger(MQL_TESTER) && time.hour==0)
  {
    if(pTimeframe >= PERIOD_H4) Sleep(1800000); //300000 5 min  1800000 30 min  3600000 60 min
    else                        Sleep(300000);
  }
}

bool IsMarketOpen()
{
   MqlDateTime time;
   TimeCurrent(time);

   // Giả sử thị trường mở từ 9 giờ sáng đến 5 giờ chiều
   if(time.hour >= 10 && time.hour < 19)
      return true;
   else
      return false;
}
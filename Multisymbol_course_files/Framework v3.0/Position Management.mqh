//+------------------------------------------------------------------+
//|                                          Position Management.mqh |
//|                                          Jose Martinez Hernandez |
//|                                         https://greaterwaves.com |
//+------------------------------------------------------------------+
#property copyright "Jose Martinez Hernandez"
#property link      "https://greaterwaves.com"

#include "Trade.mqh"
//AdjustStopLvl is used by SL,TP, TSL & BE functions


//+------------------------------------------------------------------+
//| CPM Class - Stop Loss, Take Profit, TSL & BE                     |
//+------------------------------------------------------------------+

class CPM
{
	private:
      ulong             TrailingStopLoss(string pSymbol,int pTSLFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit);   //Hedging
      bool              TrailingStopLoss(string pSymbol,int pTSLFixedPoints,double &pStopLoss,double &pTakeProfit);                //Netting   

      ulong             BreakEven(string pSymbol,int pBEFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit);           //Hedging
      bool              BreakEven(string pSymbol,int pBEFixedPoints,double &pStopLoss,double &pTakeProfit);                        //Netting
	
	public:                                 
      //-- SL & TP
      double            CalculateStopLoss(string pSymbol,string pEntrySignal,int pSLFixedPoints,int pSLFixedPointsMA,double pMA);
      double            CalculateTakeProfit(string pSymbol,string pEntrySignal,int pTPFixedPoints);
      
      //-- TSL & BE (return ticket/true and the SL and TP in the variables passed by reference)
      ulong             TrailingStopLoss(ENUM_ACCOUNT_MARGIN_MODE pMarginMode,string pSymbol,int pTSLFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit);    
      ulong             BreakEven(ENUM_ACCOUNT_MARGIN_MODE pMarginMode,string pSymbol,int pBEFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit);
};

//+------------------------------------------------------------------+
//| CPM Class Methods                                                |
//+------------------------------------------------------------------+

double CPM::CalculateStopLoss(string pSymbol, string pEntrySignal, int pSLFixedPoints, int pSLFixedPointsMA, double pMA)
{
   double stopLoss = 0.0;
   double askPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);
   double tickSize = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(pSymbol,SYMBOL_POINT);
   
   if(pEntrySignal == "LONG")
   {
      if(pSLFixedPoints > 0)        stopLoss = askPrice - (pSLFixedPoints * point);
      else if(pSLFixedPointsMA > 0) stopLoss = pMA - (pSLFixedPointsMA * point);
      
      if(stopLoss > 0) stopLoss = AdjustBelowStopLevel(pSymbol,askPrice,stopLoss);      
   }
   
   else if(pEntrySignal == "SHORT")
   {
      if(pSLFixedPoints > 0)        stopLoss = bidPrice + (pSLFixedPoints * point);
      else if(pSLFixedPointsMA > 0) stopLoss = pMA + (pSLFixedPointsMA * point); 
         
      if(stopLoss > 0) stopLoss = AdjustAboveStopLevel(pSymbol,bidPrice,stopLoss);      
   }
   
   stopLoss = round(stopLoss/tickSize) * tickSize;
   return stopLoss;   
}

double CPM::CalculateTakeProfit(string pSymbol, string pEntrySignal, int pTPFixedPoints)
{
   double takeProfit = 0.0;
   double askPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);
   double tickSize = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(pSymbol,SYMBOL_POINT);

   if(pEntrySignal == "LONG")
   {
      if(pTPFixedPoints > 0)  takeProfit = askPrice + (pTPFixedPoints * point);     
      if(takeProfit > 0)      takeProfit = AdjustAboveStopLevel(pSymbol,askPrice,takeProfit);   
   }
   else if(pEntrySignal == "SHORT")
   {
      if(pTPFixedPoints > 0)  takeProfit = bidPrice - (pTPFixedPoints * point);      
      if(takeProfit > 0)      takeProfit = AdjustBelowStopLevel(pSymbol,bidPrice,takeProfit); 
   }
   
   takeProfit = round(takeProfit/tickSize) * tickSize;
   return takeProfit;   
}

ulong CPM::TrailingStopLoss(ENUM_ACCOUNT_MARGIN_MODE pMarginMode,string pSymbol,int pTSLFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit)
{
   ulong posTicket = 0;   //0 (false) informs the EA not to change the SL
   
   if(pMarginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) posTicket = TrailingStopLoss(pSymbol,pTSLFixedPoints,pMagic,pStopLoss,pTakeProfit); 
   else                                                  posTicket = TrailingStopLoss(pSymbol,pTSLFixedPoints,pMagic,pStopLoss,pTakeProfit);
   
   return posTicket;
}

//HEDGING
ulong CPM::TrailingStopLoss(string pSymbol,int pTSLFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit)
{	
	for(int i = PositionsTotal() - 1; i >= 0; i--)
	{         	   
	   ulong positionTicket = PositionGetTicket(i);
	   PositionSelectByTicket(positionTicket);
   
      string posSymbol        = PositionGetString(POSITION_SYMBOL);   
	   ulong posMagic          = PositionGetInteger(POSITION_MAGIC);
	   ulong posType           = PositionGetInteger(POSITION_TYPE);
      double currentStopLoss  = PositionGetDouble(POSITION_SL);
      double tickSize         = SymbolInfoDouble(posSymbol,SYMBOL_TRADE_TICK_SIZE);
      double point            = SymbolInfoDouble(posSymbol,SYMBOL_POINT);   

      double bidPrice         = SymbolInfoDouble(posSymbol,SYMBOL_BID);  
      double askPrice         = SymbolInfoDouble(posSymbol,SYMBOL_ASK);                  
      int digits              = (int)SymbolInfoInteger(posSymbol,SYMBOL_DIGITS);
      	   
	   double newStopLoss;
	   
	   if(posSymbol == pSymbol && posMagic == pMagic && posType == POSITION_TYPE_BUY)
	   {        
         newStopLoss = askPrice - (pTSLFixedPoints * point);
         newStopLoss = AdjustBelowStopLevel(posSymbol,askPrice,newStopLoss);         
         newStopLoss = round(newStopLoss/tickSize) * tickSize;
         
         if(NormalizeDouble(newStopLoss-currentStopLoss,digits) > 0 || currentStopLoss==0)
         {
            pStopLoss   = newStopLoss;
            pTakeProfit = PositionGetDouble(POSITION_TP);
            return positionTicket; 
         }               
	   }
	   
	   else if(posSymbol == pSymbol && posMagic == pMagic && posType == POSITION_TYPE_SELL)
	   {                 
         newStopLoss = bidPrice + (pTSLFixedPoints * point);
         newStopLoss = AdjustAboveStopLevel(posSymbol,bidPrice,newStopLoss);
         newStopLoss = round(newStopLoss/tickSize) * tickSize;
         
         if(NormalizeDouble(newStopLoss-currentStopLoss,digits) < 0 || currentStopLoss==0)         
         {
            pStopLoss   = newStopLoss;
            pTakeProfit = PositionGetDouble(POSITION_TP);            
            return positionTicket; 
         }
      } 
	}
	
	return 0;
}

//NETTING
bool CPM::TrailingStopLoss(string pSymbol,int pTSLFixedPoints,double &pStopLoss,double &pTakeProfit)
{	  	   
   if(!PositionSelect(pSymbol)) return false;
   
   string posSymbol        = PositionGetString(POSITION_SYMBOL);   
   ulong posType           = PositionGetInteger(POSITION_TYPE);
   double currentStopLoss  = PositionGetDouble(POSITION_SL);
   double tickSize         = SymbolInfoDouble(posSymbol,SYMBOL_TRADE_TICK_SIZE);	
   double point            = SymbolInfoDouble(posSymbol,SYMBOL_POINT);   

   double bidPrice         = SymbolInfoDouble(posSymbol,SYMBOL_BID);  
   double askPrice         = SymbolInfoDouble(posSymbol,SYMBOL_ASK);                  
   int digits              = (int)SymbolInfoInteger(posSymbol,SYMBOL_DIGITS);
   
   double newStopLoss;
   
   if(posSymbol == pSymbol && posType == POSITION_TYPE_BUY)
   {     
      newStopLoss = askPrice - (pTSLFixedPoints * point);
      newStopLoss = AdjustBelowStopLevel(posSymbol,askPrice,newStopLoss);         
      newStopLoss = round(newStopLoss/tickSize) * tickSize;
      
      if(NormalizeDouble(newStopLoss-currentStopLoss,digits) > 0 || currentStopLoss==0)
      {
         pStopLoss   = newStopLoss;
         pTakeProfit = PositionGetDouble(POSITION_TP);            
         return true; 
      }                  
   }
   
   else if(posSymbol == pSymbol && posType == POSITION_TYPE_SELL)
   {                 
      newStopLoss = bidPrice + (pTSLFixedPoints * point);
      newStopLoss = AdjustAboveStopLevel(posSymbol,bidPrice,newStopLoss);
      newStopLoss = round(newStopLoss/tickSize) * tickSize;
      
      if(NormalizeDouble(newStopLoss-currentStopLoss,digits) < 0 || currentStopLoss==0)         
      {
         pStopLoss   = newStopLoss;
         pTakeProfit = PositionGetDouble(POSITION_TP);            
         return true; 
      }                   
   } 
   
   return false;
}

ulong CPM::BreakEven(ENUM_ACCOUNT_MARGIN_MODE pMarginMode,string pSymbol,int pBEFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit)
{
   ulong posTicket = 0;   //0 (false) informs the EA not to change the SL
   
   if(pMarginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) posTicket = BreakEven(pSymbol,pBEFixedPoints,pMagic,pStopLoss,pTakeProfit); 
   else                                                  posTicket = BreakEven(pSymbol,pBEFixedPoints,pMagic,pStopLoss,pTakeProfit);
   
   return posTicket;
}

//HEDGING
ulong CPM::BreakEven(string pSymbol,int pBEFixedPoints,ulong pMagic,double &pStopLoss,double &pTakeProfit)
{	         	
	for(int i = PositionsTotal() - 1; i >= 0; i--)
	{         	   
	   ulong positionTicket = PositionGetTicket(i);
	   PositionSelectByTicket(positionTicket);
	   
      string posSymbol        = PositionGetString(POSITION_SYMBOL);   
	   ulong posMagic          = PositionGetInteger(POSITION_MAGIC);
	   ulong posType           = PositionGetInteger(POSITION_TYPE);   
      double currentStopLoss  = PositionGetDouble(POSITION_SL);   
      double tickSize         = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);	
	   double openPrice        = PositionGetDouble(POSITION_PRICE_OPEN);    
      double point            = SymbolInfoDouble(pSymbol,SYMBOL_POINT);   	     	   
	   double newStopLoss      = round(openPrice/tickSize) * tickSize;
      int digits              = (int)SymbolInfoInteger(posSymbol,SYMBOL_DIGITS);
	   
	   if(posSymbol == pSymbol && posMagic == pMagic && posType == POSITION_TYPE_BUY)
	   {        
         double bidPrice      = SymbolInfoDouble(pSymbol,SYMBOL_BID);         
         double BEThreshold   = openPrice + (pBEFixedPoints*point);
         
         if((NormalizeDouble(newStopLoss-currentStopLoss,digits) > 0 || currentStopLoss==0) && bidPrice > BEThreshold)
         {
            pStopLoss   = newStopLoss;
            pTakeProfit = PositionGetDouble(POSITION_TP);            
            return positionTicket; 
         }        
	   }
	   
	   else if(posSymbol == pSymbol && posMagic == pMagic && posType == POSITION_TYPE_SELL)
	   {                 
         double askPrice      = SymbolInfoDouble(pSymbol,SYMBOL_ASK);                  
         double BEThreshold   = openPrice - (pBEFixedPoints*point);
         
         if((NormalizeDouble(newStopLoss-currentStopLoss,digits) < 0 || currentStopLoss==0) && askPrice < BEThreshold)                  
         {
            pStopLoss   = newStopLoss;
            pTakeProfit = PositionGetDouble(POSITION_TP);            
            return positionTicket; 
         }        
	   }           
	}
	
	return 0;
}

//NETTING
bool CPM::BreakEven(string pSymbol,int pBEFixedPoints,double &pStopLoss,double &pTakeProfit)
{	         	
   if(!PositionSelect(pSymbol)) return false;
   
   string posSymbol        = PositionGetString(POSITION_SYMBOL);   
   ulong posMagic          = PositionGetInteger(POSITION_MAGIC);
   ulong posType           = PositionGetInteger(POSITION_TYPE);   
   double currentStopLoss  = PositionGetDouble(POSITION_SL);   
   double tickSize         = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);	
   double openPrice        = PositionGetDouble(POSITION_PRICE_OPEN);    
   double point            = SymbolInfoDouble(pSymbol,SYMBOL_POINT);   	     	   
   double newStopLoss      = round(openPrice/tickSize) * tickSize;
   
   if(posSymbol == pSymbol && posType == POSITION_TYPE_BUY)
   {        
      double bidPrice      = SymbolInfoDouble(pSymbol,SYMBOL_BID);         
      double BEThreshold   = openPrice + (pBEFixedPoints*point);
      
      if(newStopLoss > currentStopLoss && bidPrice > BEThreshold) 
      {
         pStopLoss   = newStopLoss;
         pTakeProfit = PositionGetDouble(POSITION_TP);            
         return true; 
      }        
   }
   
   else if(posSymbol == pSymbol && posType == POSITION_TYPE_SELL)
   {                 
      double askPrice      = SymbolInfoDouble(pSymbol,SYMBOL_ASK);                  
      double BEThreshold   = openPrice - (pBEFixedPoints*point);
      
      if(newStopLoss < currentStopLoss && askPrice < BEThreshold) 
      {
         pStopLoss   = newStopLoss;
         pTakeProfit = PositionGetDouble(POSITION_TP);            
         return true; 
      }        
   } 
   
   return false;           
}


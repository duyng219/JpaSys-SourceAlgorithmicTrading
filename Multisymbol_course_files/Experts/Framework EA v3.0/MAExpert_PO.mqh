//+------------------------------------------------------------------+
//|                                                  MAExpert PO.mqh |
//|                                          José Martínez Hernández |
//|                                         https://greaterwaves.com |
//+------------------------------------------------------------------+
#property copyright "José Martínez Hernández"
#property link      "https://greaterwaves.com"

#include <MQL5 Advanced Courses\Framework v3.0\Framework.mqh>


class CMAExpert_PO
{
   private:
      string               mSymbol;
      ENUM_TIMEFRAMES      mTimeframe;
      ulong                mMagic;
      
      ushort               mPOExpirationMinutes;
      double               mFixedVolume;
      
      paramPM              mParamPM;
      paramMA              mParamMA;
      
      datetime             mTimeBarOpen;  

      CcTrade              Trade;
      CPM                  PM;
      CBar                 Bar;
      CiMA                 MA;
       
   public:
                           CMAExpert_PO(string pSymbol,ENUM_TIMEFRAMES pTimeframe,ulong pMagic,ushort pPOExpirationMinutes,double pFixedVolume,paramPM &pParamPM,paramMA &pParamMA);
                           
      int                  OnInitEvent();
      void                 OnTickEvent();
};

void CMAExpert_PO::CMAExpert_PO(string pSymbol,ENUM_TIMEFRAMES pTimeframe,ulong pMagic,ushort pPOExpirationMinutes,double pFixedVolume,paramPM &pParamPM,paramMA &pParamMA)
{
   mSymbol              = pSymbol;
   mTimeframe           = pTimeframe;
   mMagic               = pMagic;
   
   mPOExpirationMinutes = pPOExpirationMinutes;
   mFixedVolume         = pFixedVolume;
   
   ZeroMemory(mParamPM);
   mParamPM             = pParamPM;
   
   ZeroMemory(mParamMA);
   mParamMA             = pParamMA;
   
   mTimeBarOpen         = D'1971.01.01 00:00';   
}

int CMAExpert_PO::OnInitEvent(void)
{
   //SET VARIABLES  
   //Filling policy is selected automatically by Trade class when sending an order, but we can use SetTypeFilling() and SetTypeFillingBySymbol() to set it beforehand   
   Trade.SetSymbol(mSymbol);
   Trade.SetDeviationInPoints(30);
   Trade.SetExpertMagicNumber(mMagic);
   Trade.SetMarginMode();
   Trade.LogLevel(LOG_LEVEL_ERRORS);
   
   
   //INITIALIZE METHODS  
   
   int MAHandle = MA.Init(mSymbol,mTimeframe,mParamMA.MAPeriod,mParamMA.MAShift,mParamMA.MAMethod,mParamMA.MAPrice); 
   
   if(MAHandle == -1){
      return(INIT_FAILED);}
      
   return(INIT_SUCCEEDED);
}

void CMAExpert_PO::OnTickEvent(void)
{
   //--------------------//   
   // CHECK OF NEW BAR   
   //--------------------//
   
   bool newBar = false;
   
   //Check for New Bar
   if(mTimeBarOpen != iTime(mSymbol,mTimeframe,0))
   {
      newBar = true;
      mTimeBarOpen = iTime(mSymbol,mTimeframe,0);   
   }   
   
   if(newBar == true)
   {  
      DelayOnMarketClose(mTimeframe);
      
      //--------------------------//
      // PRICE & INDICATORS 
      //--------------------------//
      
      //Price
      Bar.Refresh(mSymbol,mTimeframe,3);
      double close1 = Bar.Close(1);    
      double close2 = Bar.Close(2);  
      
      //Normalization of close price to tick size 
      double tickSize = SymbolInfoDouble(mSymbol,SYMBOL_TRADE_TICK_SIZE);
      close1 = round(close1/tickSize) * tickSize;
      close2 = round(close2/tickSize) * tickSize;     
      
      //Moving Average
      MA.RefreshMain();
      double ma1 = MA.main[1];
      double ma2 = MA.main[2];
   
      //--------------------------//
      // EXIT SIGNALS AND TRADE EXIT 
      //--------------------------//
         
      //Exit Signals & Close Trades Execution
      string exitSignal = MA_ExitSignal(close1,close2,ma1,ma2);
        
      if(exitSignal == "EXIT_LONG" || exitSignal == "EXIT")  Trade.PositionClose(POSITION_TYPE_BUY);
      if(exitSignal == "EXIT_SHORT" || exitSignal == "EXIT") Trade.PositionClose(POSITION_TYPE_SELL);
      
      Sleep(1000);   
   
      //--------------------------//
      // ENTRY SIGNALS 
      //--------------------------//
         
      //Strategy Entry Signals
      string entrySignal = MA_EntrySignal(close1,close2,ma1,ma2);
      Comment("EA #", mMagic, " | ", exitSignal, " | ",entrySignal, " SIGNALS DETECTED");

      //Check entry signals and trade placement            
      if(Trade.SelectPositionBySymbolAndMagic() == false && (entrySignal == "LONG" || entrySignal == "SHORT"))
      {
         //--------------------------//
         // TRADE PLACEMENT
         //--------------------------//
         
         //we delete currently placed pending orders thus preventing multiple orders from being opened at same time
         //we delete instead of modifying because we might want to change the order type
         ulong ticket = Trade.GetPendingTicket();       
         if(ticket > 0) Trade.OrderDelete(ticket);
         
         //SL & TP calculation
         double stopLoss   = PM.CalculateStopLoss(mSymbol,entrySignal,mParamPM.SLFixedPoints,mParamPM.SLFixedPointsMA,ma1);
         double takeProfit = PM.CalculateTakeProfit(mSymbol,entrySignal,mParamPM.TPFixedPoints);           
         
         //PO parameters
         double POPrice          = 0;
         datetime expiration     = Trade.GetExpirationTime(mPOExpirationMinutes); 
          
         ENUM_ORDER_TYPE_TIME orderTime = ORDER_TIME_GTC;  
         if(expiration > 0)   orderTime = ORDER_TIME_SPECIFIED;
         
         //Order send
         if(entrySignal == "LONG")
         {
            //Pending Order Price - For this example, we just place the pending order 100 points above close of previous bar
            POPrice = close1 + (100 * SymbolInfoDouble(mSymbol,SYMBOL_POINT));            
            POPrice = AdjustAboveStopLevel(mSymbol,SymbolInfoDouble(mSymbol,SYMBOL_ASK),POPrice);
            
            Trade.BuyStop(mFixedVolume,POPrice,mSymbol,stopLoss,takeProfit,orderTime,expiration);
         }        
         
         else if(entrySignal == "SHORT")
         {
            //Pending Order Price - For this example, we just place the pending order 100 points below close of previous bar
            POPrice = close1 - (100 * SymbolInfoDouble(mSymbol,SYMBOL_POINT));            
            POPrice = AdjustBelowStopLevel(mSymbol,SymbolInfoDouble(mSymbol,SYMBOL_BID),POPrice);
                        
            Trade.SellStop(mFixedVolume,POPrice,mSymbol,stopLoss,takeProfit,orderTime,expiration);
         }       
      }
        
      //--------------------------//
      // POSITION MANAGEMENT 
      //--------------------------//
      double sl=0, tp= 0;
      
      if(mParamPM.TSLFixedPoints > 0) {
         ulong ticket = PM.TrailingStopLoss(Trade.GetMarginMode(),mSymbol,mParamPM.TSLFixedPoints,mMagic,sl,tp);
         if(ticket > 0 && sl > 0) Trade.PositionModify(ticket,sl,tp);
      }
         
      if(mParamPM.BEFixedPoints > 0) {
         ulong ticket = PM.BreakEven(Trade.GetMarginMode(),mSymbol,mParamPM.BEFixedPoints,mMagic,sl,tp);
         if(ticket > 0 && sl > 0) Trade.PositionModify(ticket,sl,tp);         
      }        
   }
}
//+------------------------------------------------------------------+
//|                         Simple Moving Average EA v2.00 (+RM).mq5 |
//|                                          Jose Martinez Hernandez |
//|                                         https://greaterwaves.com |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DISCLAIMER                                                       |
//+------------------------------------------------------------------+

//THE SOFTWARE IS DELIVERED “AS IS” AND “AS AVAILABLE”, WITHOUT WARRANTY OF ANY KIND. 
//YOU EXPRESSLY ACKNOWLEDGE AND AGREE THAT THE ENTIRE RISK AS TO THE USE, RESULTS AND 
//PERFORMANCE OF THE SOFTWARE IS ASSUMED SOLELY BY YOU. 
//TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE AUTHOR EXPRESSLY DISCLAIMS ALL 
//WARRANTIES, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO,  THE IMPLIED 
//WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND 
//NON-INFRINGEMENT, OR ANY WARRANTY ARISING OUT OF ANY PROPOSAL, 
//SPECIFICATION OR SAMPLE WITH RESPECT TO THE SOFTWARE, AND WARRANTIES THAT MAY ARISE 
//OUT OF COURSE OF DEALING, COURSE OF PERFORMANCE, USAGE OR TRADE PRACTICE. 
//WITHOUT LIMITATION OF THE FOREGOING, THE AUTHOR PROVIDES NO WARRANTY OR UNDERTAKING, 
//AND MAKE NO REPRESENTATION OF ANY KIND THAT THE SOFTWARE, WILL MEET YOUR REQUIREMENTS, 
//ACHIEVE ANY INTENDED RESULTS, BE COMPATIBLE OR WORK WITH ANY OTHER SOFTWARE, SYSTEMS 
//OR SERVICES, OPERATE WITHOUT INTERRUPTION, MEET ANY PERFORMANCE OR RELIABILITY STANDARDS 
//OR BE ERROR FREE OR THAT ANY ERRORS OR DEFECTS CAN OR WILL BE CORRECTED. 
//NO ORAL OR WRITTEN INFORMATION OR ADVICE GIVEN BY THE AUTHOR SHALL CREATE 
//A WARRANTY OR IN ANY WAY AFFECT THE SCOPE AND OPERATION OF THIS DISCLAIMER. 
//THIS DISCLAIMER OF WARRANTY CONSTITUTES AN ESSENTIAL PART OF THIS LICENSE.

//+------------------------------------------------------------------+
//| Expert information                                               |
//+------------------------------------------------------------------+

#property copyright     "Jose Martinez Hernandez"
#property description   "Moving Average Expert Advisor provided as template as part of the Algorithmic Trading Course"
#property link          "https://greaterwaves.com"
#property version       "2.00"

//+------------------------------------------------------------------+
//| Expert Notes                                                     |
//+------------------------------------------------------------------+
// Expert Advisor that codes a Moving Average strategy
// It is designed to trade in direction of the trend, placing buy positions when last bar closes above the moving average and short sell positions when last bar closes below the moving average 
// It incorporates two different alternative stop-loss that consists of fixed points below the open price or moving average, for long trades, or above the open price or moving average, for short trades
// It incorporates settings for placing profit taking, as well as break-even and trailing stop loss

//Version Log
//v1.1   Added Check Stop Levels Function
//v1.2   Added Filling Policy
//v1.3   Fixed a bug in TSL and BE functions that modified take profit to 0 when the stop loss was modified
//v1.4   Changed position management input variables data type from ushort to int (necessary for larger market cap assets like BTC)
//v2.0   Changed framework to OOP

//+------------------------------------------------------------------+
//| Objects & Include Files                                          |
//+------------------------------------------------------------------+
//#include <MQL5Course\Framework v2.0\Framework.mqh>
#include "Framework v2.0/Framework.mqh"

CTrade   Trade;
CPM      PM;
CBar     Bar;
CiMA     MA;
CRM      RM;



//+------------------------------------------------------------------+
//| EA Enumerations                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Input & Global Variables                                         |
//+------------------------------------------------------------------+

sinput group                              "EA GENERAL SETTINGS"
input ulong                               MagicNumber             = 101;
input int                                 Deviation               = 30;
input ENUM_ORDER_TYPE_FILLING             FillingPolicy           = ORDER_FILLING_FOK;

sinput group                              "MOVING AVERAGE SETTINGS"
input int                                 MAPeriod                = 30;
input ENUM_MA_METHOD                      MAMethod                = MODE_SMA;
input int                                 MAShift                 = 0;
input ENUM_APPLIED_PRICE                  MAPrice                 = PRICE_CLOSE;

sinput group                              "RISK MANAGEMENT"
sinput string                             strMM;                                                // :::::   MONEY MANAGEMENT   :::::  
input ENUM_MONEY_MANAGEMENT               MoneyManagement         = MM_MIN_LOT_SIZE;
input double                              MinLotPerEquitySteps    = 500;
input double                              FixedVolume             = 0.01;
input double                              RiskPercent             = 1;

sinput string                             strMaxLoss;                                           // :::::   MAX LOSS   :::::  
input double                              MaxLossPercent          = 0;
input ENUM_TIMEFRAMES                     ProfitPeriod            = PERIOD_D1;             
input uchar                               NumberOfPeriods         = 0;      
input bool                                IncludeFloating         = false;

sinput group                              "POSITION MANAGEMENT"
input int                                 SLFixedPoints           = 0;
input int                                 SLFixedPointsMA         = 200;  
input int                                 TPFixedPoints           = 0;
input int                                 TSLFixedPoints          = 0;
input int                                 BEFixedPoints           = 0;

datetime    glTimeBarOpen;

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+

int OnInit()
{   
   //SET VARIABLES
   
   Trade.SetFillingType(FillingPolicy);     
   Trade.SetDeviation(Deviation);
   Trade.SetMagicNumber(MagicNumber);
   
   glTimeBarOpen = D'1971.01.01 00:00';
   
   
   //INITIALIZE METHODS  
   
   int MAHandle = MA.Init(_Symbol,PERIOD_CURRENT,MAPeriod,MAShift,MAMethod,MAPrice); 
   
   if(MAHandle == -1){
      return(INIT_FAILED);}
      
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("Expert removed");
}

void OnTick()
{ 
   //--------------------//
   //  NEW BAR CONTROL   
   //--------------------//
   
   bool newBar = false;
   
   //Check for New Bar
   if(glTimeBarOpen != iTime(Symbol(),PERIOD_CURRENT,0))
   {
      newBar = true;
      glTimeBarOpen = iTime(Symbol(),PERIOD_CURRENT,0);   
   }   
   
   if(newBar == true)
   {  
      DelayOnMarketClose(_Period);
      
      string report = "";
      bool maxLossExceeded = RM.MaxLoss(MaxLossPercent,_Period,ProfitPeriod,NumberOfPeriods,IncludeFloating,report);
      //--------------------------//
      // PRICE & INDICATORS 
      //--------------------------//
      
      //Price
      Bar.Refresh(_Symbol,PERIOD_CURRENT,3);
      double close1 = Bar.Close(1);    
      double close2 = Bar.Close(2);  
      
      //Normalization of close price to tick size 
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
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
        
      if(exitSignal == "EXIT_LONG" || exitSignal == "EXIT_SHORT")
         Trade.CloseTrades(_Symbol,exitSignal);
      
      Sleep(1000);   
   
      //--------------------------//
      // ENTRY SIGNALS 
      //--------------------------//
         
      //Strategy Entry Signals
      string entrySignal = MA_EntrySignal(close1,close2,ma1,ma2);
      Comment("EA #", MagicNumber, " | ", exitSignal, " | ",entrySignal, " SIGNALS DETECTED", "\n", report);

      //Check entry signals and trade placement            
      if(Trade.SelectPosition(_Symbol) == false && maxLossExceeded == false && (entrySignal == "LONG" || entrySignal == "SHORT"))
      {
        //--------------------------//
        // TRADE PLACEMENT
        //--------------------------//
        
        ulong ticket = 0;

        //SL & TP Calculation
        double stopLoss   = PM.CalculateStopLoss(_Symbol,entrySignal,SLFixedPoints,SLFixedPointsMA,ma1);
        double takeProfit = PM.CalculateTakeProfit(_Symbol,entrySignal,TPFixedPoints);  
        
        if(entrySignal == "LONG") 
        {
            //Calculate volume
            double volume = RM.MoneyManagement(_Symbol,MoneyManagement,MinLotPerEquitySteps,RiskPercent,MathAbs(stopLoss-close1),FixedVolume,ORDER_TYPE_BUY);
            
            if(volume > 0) ticket = Trade.Buy(_Symbol,volume);
        }

        else if(entrySignal == "SHORT") 
        {
            //Calculate volume
            double volume = RM.MoneyManagement(_Symbol,MoneyManagement,MinLotPerEquitySteps,RiskPercent,MathAbs(stopLoss-close1),FixedVolume,ORDER_TYPE_SELL);

            if(volume > 0) ticket = Trade.Sell(_Symbol,volume);
        }
    
        //SL & TP Trade Modification
        Trade.ModifyPosition(_Symbol,ticket,stopLoss,takeProfit);                             
      }
        
      //--------------------------//
      //POSITION MANAGEMENT 
      //--------------------------//
      
      if(Trade.IsHedging())
      {
         if(TSLFixedPoints > 0)  PM.TrailingStopLoss(_Symbol,MagicNumber,TSLFixedPoints);
         if(BEFixedPoints > 0)   PM.BreakEven(_Symbol,MagicNumber,BEFixedPoints);      
      }
      else
      {
         if(TSLFixedPoints > 0)  PM.TrailingStopLoss(_Symbol,TSLFixedPoints);
         if(BEFixedPoints > 0)   PM.BreakEven(_Symbol,BEFixedPoints);            
      }      
   }
}
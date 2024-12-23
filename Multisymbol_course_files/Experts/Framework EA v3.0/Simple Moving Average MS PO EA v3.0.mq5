//+------------------------------------------------------------------+
//|                            Simple Moving Average PO EA v3.00.mq5 |
//|                     Copyright 2022-2024, Jose Martinez Hernandez |
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

#property copyright     "Copyright 2022-2024, José Martínez Hernández"
#property description   "Moving Average Expert Advisor provided as template as part of the Algorithmic Trading Course"
#property link          "https://greaterwaves.com"
#property version       "3.00"

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
//v2.1   Replaced Trade header file by Metaquotes' library Trade file
//       Updated TSL and break-even methods to work with the new framework

//v3.0   Moved Expert code to MAExpert_PO class
//       Added Enum.mqh with structures for inputs
//       Added Multisymbol.mqh
//       Magic number and deviation now assigned during expert code

//+------------------------------------------------------------------+
//| Objects & Include Files                                          |
//+------------------------------------------------------------------+
#include <MQL5 Advanced Courses\Framework v3.0\Framework.mqh>
#include "MAExpert_PO.mqh"


//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

sinput group                              "EA GENERAL SETTINGS"
input ENUM_SYMBOLS                        TradeSymbols            = SYMBOLS_CURRENT;
input ulong                               MagicNumberSeed         = 100;
input ushort                              POExpirationMinutes     = 60;

sinput group                              "MOVING AVERAGE SETTINGS"
input int                                 MAPeriod                = 30;
input ENUM_MA_METHOD                      MAMethod                = MODE_SMA;
input int                                 MAShift                 = 0;
input ENUM_APPLIED_PRICE                  MAPrice                 = PRICE_CLOSE;

sinput group                              "MONEY MANAGEMENT"
input double                              FixedVolume             = 0.01;

sinput group                              "POSITION MANAGEMENT"
input int                                 SLFixedPoints           = 0;
input int                                 SLFixedPointsMA         = 200;  
input int                                 TPFixedPoints           = 0;
input int                                 TSLFixedPoints          = 0;
input int                                 BEFixedPoints           = 0;

//+------------------------------------------------------------------+
//| Object Structures                                                |
//+------------------------------------------------------------------+

paramMA     ParamMA = {
               MAPeriod,MAMethod,MAShift,MAPrice
            };

paramPM     ParamPM = {
               SLFixedPoints,SLFixedPointsMA,TPFixedPoints,TSLFixedPoints,BEFixedPoints
            };

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+

//Object Pointers
CMAExpert_PO   *MAExpert_PO[];
CMultiSymbol   *MS;

int            glNumberOfSymbols = 0;

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+

int OnInit()
{   
   int ret = INIT_SUCCEEDED;
   
   //####################
   // MULTI-SYMBOL (creates symbol array and fills asset info structure)
   //####################
   
   MS = new CMultiSymbol(TradeSymbols,MagicNumberSeed);
   ret = MS.OnInitEvent();
   
   if(ret != INIT_SUCCEEDED) return ret;
   
   //Get total of symbols from MS variable
   glNumberOfSymbols = MS.GetNumberOfSymbols();
   

   //####################
   // EXPERT CREATION
   //####################

   ArrayResize(MAExpert_PO,glNumberOfSymbols);

   for(int i = 0 ; i < glNumberOfSymbols ; i++)
   {
      MAExpert_PO[i] = new CMAExpert_PO(MS.GetSymbol(i),PERIOD_CURRENT,MS.GetMagic(i),POExpirationMinutes,FixedVolume,ParamPM,ParamMA);      
      ret = MAExpert_PO[i].OnInitEvent();  
         
      if(ret != INIT_SUCCEEDED) return ret;
   }

   Print(__FILE__ + " initialized succesfully");
           
   return ret;
}

void OnDeinit(const int reason)
{
   for(int i = 0 ; i < glNumberOfSymbols ; i++)
   {
      if(CheckPointer(MAExpert_PO[i])==POINTER_DYNAMIC)
      {
         delete(MAExpert_PO[i]);
         Print(__FUNCTION__, " MAExpert_PO object removed");
      }
      else
         Print(__FUNCTION__, " MAExpert_PO object isn't defined");
   }
   
   if(CheckPointer(MS)==POINTER_DYNAMIC)
   {
      delete(MS);
      Print(__FUNCTION__, " MS object removed");
   }
   else
      Print(__FUNCTION__, " MS object isn't defined");   
   
   Print("Objects removed");
}

void OnTick()
{ 
   //MAExpert_PO loop
   for(int i = 0 ; i < glNumberOfSymbols ; i++)
      MAExpert_PO[i].OnTickEvent(); 
}

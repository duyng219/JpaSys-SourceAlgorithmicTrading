//+------------------------------------------------------------------+
//|                                              MovingAverageEA.mq5 |
//|                                                            duyng |
//|                                              github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property description "Moving Average Expert Advisor"
#property link "github.com/duyng219"
#property version "2.00"
//#include <stdDirectoryFunctions.mqh>

// EA mã hóa chiến lược Trung bình động
// Nó được thiết kế để giao dịch theo hướng của xu hướng, đặt các vị thế mua khi thanh cuối cùng đóng trên đường trung bình động và các vị thế bán khống khi thanh cuối cùng đóng dưới đường trung bình động
// Nó kết hợp hai mức dừng lỗ thay thế khác nhau bao gồm các điểm cố định bên dưới giá mở cửa hoặc đường trung bình động đối với các giao dịch dài hạn hoặc trên giá mở cửa hoặc đường trung bình động đối với các giao dịch ngắn hạn.
// Nó kết hợp các cài đặt để đặt chốt lời, cũng như điểm hòa vốn và điểm dừng lỗ cuối cùng

//+------------------------------------------------------------------+
//| Object & Include Files                                           |
//+------------------------------------------------------------------+
#include "Library v2.0/Library.mqh"

CTrade Trade;
CPM PM;
CBar Bar;
CiMA MA;

//+------------------------------------------------------------------+
//| EA Enumerations / Bảng liệt kê EA                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Input & Global Variables | Biến đầu vào và biến toàn cục         |
//+------------------------------------------------------------------+
sinput group                              "EA GENERAL SETTINGS" // Biến đầu vào giới hạn (Title)
input ulong                               MagicNumber             = 101;
input int                                 Deviation               = 30;
input ENUM_ORDER_TYPE_FILLING             FillingPolicy           = ORDER_FILLING_FOK;

sinput group                              "MOVING AVERAGE SETTINGS"
input int                                 MAPeriod                = 30;
input int                                 MAShift                 = 0;
input ENUM_MA_METHOD                      MAMethod                = MODE_SMA; 
input ENUM_APPLIED_PRICE                  MAPrice                 = PRICE_CLOSE;

sinput group                              "MONEY MANAGEMENT"
input double                              FixedVolume             = 0.1;

sinput group                              "POSITION MANAGEMENT"
input int                                 SLFixedPoints           = 0;
input int                                 SLFixedPointsMA         = 200;  
input int                                 TPFixedPoints           = 0;
input int                                 TSLFixedPoints          = 0;
input int                                 BEFixedPoints           = 0;

datetime                                  glTimeBarOpen;
int                                       MAHandle;

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Trade.SetFillingType(FillingPolicy);
  Trade.SetDeviation(Deviation);
  Trade.SetMagicNumber(MagicNumber);

  //-- Initialization of variables
  glTimeBarOpen = D'1971.01.01 00:00';

  int marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  if(Trade.IsHedging() && marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
  {
    Print("Tài khoản đang ở chế độ Hedging.");
  } 
  else
  {
    Print("Tài khoản đang ở chế độ Netting.");
  } 
  
  //-- Indicator handles
  MAHandle = MA.Init(_Symbol,PERIOD_CURRENT,MAPeriod,MAShift,MAMethod,MAPrice);

  if(MAHandle == -1) return(INIT_FAILED);

  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  Print("Expert removed");
}

void OnTick()
{
  //--------------------//
  //  NEW BAR CONTROL   //
  //--------------------//
  bool newBar = false;

  // Check for New Bar
  if (glTimeBarOpen != iTime(_Symbol, PERIOD_CURRENT, 0))
  {
    newBar = true;
    glTimeBarOpen = iTime(_Symbol, PERIOD_CURRENT, 0);
  }

  if (newBar == true  && IsMarketOpen())
  {
    DelayOnMarketClosed(_Period);
    //--------------------//
    // PRICE & INDICATORS //
    //--------------------//

    //Price
    Bar.Refresh(_Symbol,PERIOD_CURRENT,3);
    double close1 = Bar.Close(1);
    double close2 = Bar.Close(2);

    //Normalization of close price to tick size | Bình thường hóa giá đóng theo kích thước đánh dấu
    double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); //USDJPY 100.185 -- > 0.001 TSL 85.54 --> 0.01
    close1 = round(close1/tickSize) * tickSize;
    close2 = round(close2/tickSize) * tickSize;

    //Moving Average
    MA.RefreshMain();
    double ma1 = MA.main[1];
    double ma2 = MA.main[2];
         
    //--------------------//
    //     TRADE EXIT     //
    //--------------------//

    //Exit Signals & Close Trades Execution
    string exitSignal = MA_ExitSignal(close1,close2,ma1,ma2);

    if(exitSignal == "EXIT_LONG" || exitSignal == "EXIT_SHORT"){
      Trade.CloseTrades(_Symbol,exitSignal);}

    Sleep(1000);

    //--------------------//
    //   TRADE PLACEMENT  //
    //--------------------//

    //Entry Signals & Order Placement Execution
    string entrySignal = MA_EntrySignal(close1,close2,ma1,ma2);
    Comment("EA #", MagicNumber, " | ", exitSignal, " | ", entrySignal, " SIGNALS DETECTED");

    if(Trade.SelectPosition(_Symbol) == false && (entrySignal == "LONG" || entrySignal == "SHORT"))
    {
      ulong ticket = 0;

      if(entrySignal == "LONG")         ticket = Trade.Buy(_Symbol,FixedVolume);
      else if(entrySignal == "SHORT")   ticket = Trade.Sell(_Symbol,FixedVolume);

      //SL & TP Trade Modification
      if(ticket > 0)
      {
        double stopLoss = PM.CalculateStopLoss(_Symbol,entrySignal,SLFixedPoints,SLFixedPointsMA,ma1);
        double takeProfit = PM.CalculateTakeProfit(_Symbol,entrySignal,TPFixedPoints);
        Trade.ModifyPosition(_Symbol,ticket,stopLoss,takeProfit);
      }
    } 

    //--------------------//
    //POSITION MANAGEMENT //
    //--------------------//
    if(Trade.IsHedging())
    {
      if(TSLFixedPoints > 0) PM.TrailingStopLoss(_Symbol,MagicNumber,TSLFixedPoints);
      if(BEFixedPoints > 0) PM.BreakEven(_Symbol,MagicNumber,BEFixedPoints);
    }
    else
    {
      if(TSLFixedPoints > 0) PM.TrailingStopLoss(_Symbol,TSLFixedPoints);
      if(BEFixedPoints > 0) PM.BreakEven(_Symbol,BEFixedPoints);
    }
  }
}

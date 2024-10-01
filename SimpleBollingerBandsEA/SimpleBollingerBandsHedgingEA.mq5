//+------------------------------------------------------------------+
//|                                SimpleBollingerBandsHedgingEA.mq5 |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link "https://github.com/duyng219"
#property version "1.00"
#include <CustomFunctions.mqh>

//+------------------------------------------------------------------+
//| Input & Global Variables | Biến đầu vào và biến toàn cục         |
//+------------------------------------------------------------------+
sinput group                              "EA GENERAL SETTINGS" // Biến đầu vào giới hạn (Title)
input ulong                               MagicNumber             = 102;

sinput group                              "BOLLINGER BANDS SETTINGS"
input int                                 bbPeriod                = 20;
input int                                 band1Std                = 1;
input int                                 band2Std                = 4;

sinput group                              "MONEY MANAGEMENT" // % số tiền rủi ro tối đa (0.01 = 1%)
input double                              maxRiskPrc              = 0.01; 

int                                       BBHandle1;
int                                       BBHandle2;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // Khoi tao BB
  BBHandle1 = BB_Init(bbPeriod, 0, band1Std, PRICE_CLOSE);
  BBHandle2 = BB_Init(bbPeriod, 0, band2Std, PRICE_CLOSE);

  if(BBHandle1 == -1 || BBHandle2 == -1) return(INIT_FAILED);

  return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
  double bbUpper1 = BB(BBHandle1, 1, 0);
  double bbLower1 = BB(BBHandle1, 2, 0);
  double bbMid = BB(BBHandle1, 0, 0);

  double bbUpper2 = BB(BBHandle2, 1, 0);
  double bbLower2 = BB(BBHandle2, 2, 0);

  double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  MqlTradeRequest request = {};
  MqlTradeResult result = {};

  // if(askPrice < bbLower1)
  if ((askPrice < bbLower1) && CheckPlacedPositions(MagicNumber) == false) // buying
  {
    Print("Price is bellow bbLower1, Sending buy order");
    Print("");
    double stopLossPrice = NormalizeDouble(bbLower2, _Digits);
    double takeProfitPrice = NormalizeDouble(bbMid, _Digits);
    ;
    double volumeLots = VolumeLotSize(maxRiskPrc, askPrice, stopLossPrice);
    Print("volumeLots: ", volumeLots);

    // Send buy order
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.type = ORDER_TYPE_BUY;
    request.volume = volumeLots;
    request.price = askPrice;
    request.sl = stopLossPrice;
    request.tp = takeProfitPrice;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = "LONG TYPE";

    if (!OrderSend(request, result))
      PrintFormat("OrderSend error %d", GetLastError());
    PrintFormat("retcode=%u  deal=%I64u  order=%I64u", result.retcode, result.deal, result.order);
  }
  // else if (bidPrice > bbUpper1) // shorting
  else if ((bidPrice > bbUpper1)&& CheckPlacedPositions(MagicNumber) == false) // shorting
  {
    Print("Price is above bbUpper1, Sending short order");
    Print("");
    double stopLossPrice = NormalizeDouble(bbUpper2, _Digits);
    double takeProfitPrice = NormalizeDouble(bbMid, _Digits);
    double volumeLots = VolumeLotSize(maxRiskPrc, bidPrice, stopLossPrice);
    Print("volumeLots: ", volumeLots);

    // Send short order
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.type = ORDER_TYPE_SELL;
    request.volume = volumeLots;
    request.price = bidPrice;
    request.sl = stopLossPrice;
    request.tp = takeProfitPrice;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = "SHORT TYPE";

    if (!OrderSend(request, result))
      PrintFormat("OrderSend error %d", GetLastError());
    PrintFormat("retcode=%u  deal=%I64u  order=%I64u", result.retcode, result.deal, result.order);
  }
  else
  {
    Print("Khong tim thay tin hieu vao lenh");
  }
}

int BB_Init(int pBBPeriod, int pBBShift, double pBBDeviation, ENUM_APPLIED_PRICE pBBPrice)
{
  ResetLastError();
  int Hanlde = iBands(_Symbol, PERIOD_CURRENT, pBBPeriod, pBBShift, pBBDeviation, pBBPrice);

  if (Hanlde == INVALID_HANDLE)
  {
    return -1;
    Print("Đã xảy ra lỗi khi tạo BB Indicator Hanlde: ", GetLastError());
  }

  Print("BB Indicator Hanlde đã được khởi tạo thành công!");

  return Hanlde;
}
double BB(int pBBHandle, int pBBLineBuffer, int pShift)
{
  // pBBLineBuffer:   0 - BASE_LINE, 1 - UPPER_BAND, 2 - LOWER_BAND
  // pShift: 0 - Nen dau tien, 1 - Nen thu hai, 2 - Nen thu 3
  ResetLastError();

  double BB[];
  ArraySetAsSeries(BB, true);

  bool fillResult = CopyBuffer(pBBHandle, pBBLineBuffer, 0, 3, BB);
  if (fillResult == false)
  {
    Print("FILL_ERROR: ", GetLastError());
  }

  double BBValue = BB[pShift];

  BBValue = NormalizeDouble(BBValue, _Digits);

  return BBValue;
}

bool CheckPlacedPositions(ulong pMagic)
{
  bool placedPosition = false;

  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong positionTicket = PositionGetTicket(i);
    PositionSelectByTicket(positionTicket);

    ulong posMagic = PositionGetInteger(POSITION_MAGIC);

    if(posMagic == pMagic)
    {
      placedPosition = true;
      break;
    }
  }
  return placedPosition;
}
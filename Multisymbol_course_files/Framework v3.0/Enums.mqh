//+------------------------------------------------------------------+
//|                                                        Enums.mqh |
//|                                          José Martínez Hernández |
//|                                         https://greaterwaves.com |
//+------------------------------------------------------------------+
#property copyright "José Martínez Hernández"
#property link      "https://greaterwaves.com"

enum ENUM_SYMBOLS
{
   SYMBOLS_CURRENT,
   SYMBOLS_FX_MAJORS,
};

struct paramPM
{
   int                  SLFixedPoints;
   int                  SLFixedPointsMA;  
   int                  TPFixedPoints;
   int                  TSLFixedPoints;
   int                  BEFixedPoints;
};

struct paramMA
{
   int                  MAPeriod;
   ENUM_MA_METHOD       MAMethod;
   int                  MAShift;
   ENUM_APPLIED_PRICE   MAPrice;
};

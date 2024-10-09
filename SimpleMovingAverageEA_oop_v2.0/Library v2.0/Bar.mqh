//+------------------------------------------------------------------+
//|                                                          Bar.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CBar Class - Bar Data (OHLC, Time, Volume, Spread)               |
//+------------------------------------------------------------------+

class CBar
{
    private:
        /* data */
    
    public:
        MqlRates    bar[];

                    CBar(void);

        void        Refresh(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pBarsToRefresh);
        datetime    Time(int pShirt)            { return(bar[pShirt].time);         }
        double      Open(int pShirt)            { return(bar[pShirt].open);         }
        double      High(int pShirt)            { return(bar[pShirt].high);         }
        double      Low(int pShirt)             { return(bar[pShirt].low);          }
        double      Close(int pShirt)           { return(bar[pShirt].close);        }
        long        TickVolume(int pShirt)      { return(bar[pShirt].tick_volume);  }
        int         Spread(int pShirt)          { return(bar[pShirt].spread);       }
        long        Volume(int pShirt)          { return(bar[pShirt].real_volume);  }

        
};

CBar::CBar(void)
{
    ArraySetAsSeries(bar,true);
}

void CBar::Refresh(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pBarsToRefresh)
{
    CopyRates(pSymbol,pTimeframe,0,pBarsToRefresh,bar);
}
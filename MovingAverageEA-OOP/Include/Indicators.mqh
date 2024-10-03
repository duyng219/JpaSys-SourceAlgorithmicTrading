//+------------------------------------------------------------------+
//|                                                   Indicators.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property version   "1.00"

#define VALUES_TO_COPY 10 // Constant passed to coppybuffer function to specify how much data we want to copy to our array
//+------------------------------------------------------------------+
//| Base Class                                                       |
//+------------------------------------------------------------------+

class CIndicator
{
    protected:
        int             handle;

    public:
    double              main[];
            
                        CIndicator(void);

    virtual int         Init(void) { return(handle); }
    void                RefreshMain(void);

};

CIndicator::CIndicator(void)
{
    ArraySetAsSeries(main,true);
}

void CIndicator::RefreshMain(void)
{
    ResetLastError();

    if(CopyBuffer(handle,0,0,VALUES_TO_COPY,main) < 0)
        Print("FILL_ERROR: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Moving Average                                                   |
//+------------------------------------------------------------------+

class CiMA : public CIndicator
{
    public:
        int Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pMAPeriod, int pMAShift, ENUM_MA_METHOD pMAMethod, ENUM_APPLIED_PRICE pMAPrice);
};

int CiMA::Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pMAPeriod, int pMAShift, ENUM_MA_METHOD pMAMethod, ENUM_APPLIED_PRICE pMAPrice)
{
    //Trong th lỗi khi khởi tạo MA, GetLastError() sẽ lấy mã lỗi và lưu trữ trong _lastError
    //ResetLastError sẽ thay đổi biến _lastError thành 0
    ResetLastError();

    //Một định danh duy nhất cho chỉ báo. Được sử dụng cho tất cả các hành động liên quan đến chỉ báo, chẳng hạn như sao chép dữ liệu và xóa chỉ báo
    handle = iMA(pSymbol,pTimeframe,pMAPeriod,pMAShift,pMAMethod,pMAPrice);

    if(handle == INVALID_HANDLE)
    {
        return -1;
        Print("Đã xảy ra lỗi khi tạo MA Indicator Hanlde: ", GetLastError());
    }

    Print("MA Indicator Hanlde đã được khởi tạo thành công!");
    
    return handle;
}

//+--------+// Moving Average Signal Functions //+--------+//

string MA_EntrySignal(double pPrice1, double pPrice2, double pMA1, double pMA2)
{
    string str = "";
    string indicatorValues;

    if(pPrice1 > pMA1 && pPrice2 <= pMA2) {str = "LONG";}
    else if(pPrice1 < pMA1 && pPrice2 >= pMA2) {str = "SHORT";}
    else{str = "NO_TRADE";}

    if(str == "LONG" || str == "SHORT")
    {
        StringConcatenate(indicatorValues,"MA 1: ", DoubleToString(pMA1,_Digits), " | ","MA 2: ", DoubleToString(pMA2,_Digits), " | ", "Close 1: ", DoubleToString(pPrice1,_Digits), " | ","Close 2: ", DoubleToString(pPrice2,_Digits));

        Print("");
        Print(str," SIGNAL DETECTED", " | ", " Inditator Values: ", indicatorValues);
    }

    return str;
}

string MA_ExitSignal(double pPrice1, double pPrice2, double pMA1, double pMA2)
{
    string str = "";
    string indicatorValues;

    if(pPrice1 > pMA1 && pPrice2 <= pMA2) {str = "EXIT_SHORT";}
    else if(pPrice1 < pMA1 && pPrice2 >= pMA2) {str = "EXIT_LONG";}
    else{str = "NO_EXIT";}

    if(str == "EXIT_LONG" || str == "EXIT_SHORT")
    {
        StringConcatenate(indicatorValues,"MA 1: ", DoubleToString(pMA1,_Digits), " | ","MA 2: ", DoubleToString(pMA2,_Digits), " | ", "Close 1: ", DoubleToString(pPrice1,_Digits), " | ","Close 2: ", DoubleToString(pPrice2,_Digits));

        Print("");
        Print(str," SIGNAL DETECTED", " | ", " Inditator Values: ", indicatorValues);
    }

    return str;
}

//+------------------------------------------------------------------+
//| Bolliger Bands                                                   |
//+------------------------------------------------------------------+

class CiBands : public CIndicator
{
    public:
        double upper[], lower[];

        CiBands(void);

        int Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe,int pBBPeriod, int pBBShift, double pBBDeviation, ENUM_APPLIED_PRICE pBBPrice);
        void RefreshUpper(void);
        void RefreshLower(void);
};

CiBands::CiBands(void)
{
    ArraySetAsSeries(upper,true);
    ArraySetAsSeries(lower,true);
}

int CiBands::Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe,int pBBPeriod, int pBBShift, double pBBDeviation, ENUM_APPLIED_PRICE pBBPrice)
{
    //Trong th lỗi khi khởi tạo BB, GetLastError() sẽ lấy mã lỗi và lưu trữ trong _lastError
    //ResetLastError sẽ thay đổi biến _lastError thành 0
    ResetLastError();

    //Một định danh duy nhất cho chỉ báo. Được sử dụng cho tất cả các hành động liên quan đến chỉ báo, chẳng hạn như sao chép dữ liệu và xóa chỉ báo
    handle = iBands(pSymbol,pTimeframe,pBBPeriod,pBBShift,pBBDeviation,pBBPrice);

    if(handle == INVALID_HANDLE)
    {
        return -1;
        Print("Đã xảy ra lỗi khi tạo BB Indicator Hanlde: ", GetLastError());
    }

    Print("BB Indicator Hanlde đã được khởi tạo thành công!");

    return handle;
}

void CiBands::RefreshUpper()
{
    ResetLastError();

    if(CopyBuffer(handle,1,0,VALUES_TO_COPY,upper) < 0)
        Print("FILL_ERROR: ", GetLastError());
}

void CiBands::RefreshLower()
{
    ResetLastError();

    if(CopyBuffer(handle,2,0,VALUES_TO_COPY,lower) < 0)
        Print("FILL_ERROR: ", GetLastError());
}
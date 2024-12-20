//+------------------------------------------------------------------+
//|                                              Risk Management.mqh |
//|                                          José Martínez Hernández |
//|                                         https://greaterwaves.com |
//+------------------------------------------------------------------+
#property copyright "José Martínez Hernández"
#property link      "https://greaterwaves.com"

//+------------------------------------------------------------------+
//| CRM Class - Risk Management Methods                              |
//+------------------------------------------------------------------+

//sinput group                              "RISK MANAGEMENT"
//sinput string                             strMM;                                                // :::::   MONEY MANAGEMENT   :::::  
//input ENUM_MONEY_MANAGEMENT               MoneyManagement         = MM_MIN_LOT_SIZE;
//input double                              MinLotPerEquitySteps    = 500;
//input double                              FixedVolume             = 0.01;
//input double                              RiskPercent             = 1;



enum ENUM_MONEY_MANAGEMENT
{
   //kích thước khối lượng tối thiếu của một symbol (lấy giá trị nhỏ nhất -> ví dụ EURUSD min lot là 0.01)
   MM_MIN_LOT_SIZE,     

   //kích thước khối lượng tối thiếu trên vốn chủ sở hữu (vd: vốn 1500 500(3 lần)    3*0.01(giá trị min của symbol)=0.03) -> cách này khá linh hoạt      
   MM_MIN_LOT_PER_EQUITY,     

    //kích thước khối lượng cố định (0.01 -> 0.01)
   MM_FIXED_LOT_SIZE,      

   //kích thước khối lượng cố định trên vốn chủ sở hữu (vd: vốn 1500 500(3 lần)    3*0.01(giá trị truyền vào)=0.03) -> cách này khá linh hoạt  
   MM_FIXED_LOT_PER_EQUITY,  

    //tỷ lệ rủi ro trên vốn
   MM_EQUITY_RISK_PERCENT    
};

class CRM
{
	private:      
      double            CalculateVolumeRiskPerc(string pSymbol,double pRiskPercent,double pSLInPricePoints);
	
	
	public:
      
      //-- Methods for position sizing                           
      double            MoneyManagement(string pSymbol,ENUM_MONEY_MANAGEMENT pMoneyManagement,double pMinLotPerEquitySteps,double pRiskPercent,double pSLInPricePoints,double pFixedVol,ENUM_ORDER_TYPE pOrderType,double pOpenPrice=0.0);

      double            VerifyVolume(string pSymbol,double pVolume);            
      bool              VerifyMargin(string pSymbol,double pVolume,ENUM_ORDER_TYPE pOrderType,double pOpenPrice=0.0);      
      
      //-- Methods to limit the loss during a specific time range (hours, days...)
      double            GetEquityChange(ENUM_TIMEFRAMES pPeriod,ENUM_TIMEFRAMES pProfitPeriod,uchar pNumberOfPeriods,bool pIncludeFloating,string &pReport);
      bool              MaxLoss(double pMaxLossPercent,ENUM_TIMEFRAMES pPeriod,ENUM_TIMEFRAMES pProfitPeriod,uchar pNumberOfPeriods,bool pIncludeFloating,string &pReport);

};

double CRM::MoneyManagement(string pSymbol,ENUM_MONEY_MANAGEMENT pMoneyManagement,double pMinLotPerEquitySteps,double pRiskPercent,double pSLInPricePoints,double pFixedVol,ENUM_ORDER_TYPE pOrderType,double pOpenPrice=0.0)
{
   double volume = 0;
   
   switch(pMoneyManagement)
   {
      case MM_MIN_LOT_SIZE: 
         volume = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MIN);
         break;
      
      case MM_MIN_LOT_PER_EQUITY:
         if(pMinLotPerEquitySteps == 0) Print(__FUNCTION__ + "() - Minimum lots per equity steps is expected");
         volume = AccountInfoDouble(ACCOUNT_EQUITY) / pMinLotPerEquitySteps * SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MIN);//5000 1000 - 5*0.01=0.05
         break;
            
      case MM_FIXED_LOT_SIZE:
         if(pFixedVol == 0) Print(__FUNCTION__ + "() - Fixed volume is expected");
         volume = pFixedVol; 
         break;    
         
      case MM_FIXED_LOT_PER_EQUITY:
         if(pMinLotPerEquitySteps == 0 || pFixedVol == 0) Print(__FUNCTION__ + "() - Fixed lots per equity steps is expected");
         volume = AccountInfoDouble(ACCOUNT_EQUITY) / pMinLotPerEquitySteps * pFixedVol;
         break; 
         
      case MM_EQUITY_RISK_PERCENT:
         volume = CalculateVolumeRiskPerc(pSymbol,pRiskPercent,pSLInPricePoints);
         break;                              
   }
   
   if(volume > 0) 
   {
      //Volume normalization
      volume = VerifyVolume(pSymbol,volume);      
      
      //Margin check - volume changed to 0 if no free margin available      
      if(!VerifyMargin(pSymbol,volume,pOrderType,pOpenPrice)) volume = 0;
   }    
   
   return volume;  
}


double CRM::CalculateVolumeRiskPerc(string pSymbol,double pRiskPercent,double pSLInPricePoints) // 1.13550  SL 1.13400  SL Points 150  SL PricePoints 0.00150
{
   if(pRiskPercent == 0 || pSLInPricePoints == 0)
   {
      Print(__FUNCTION__ + "() - Error calculating volume risk perc, please check RiskPercent and SL");
      return 0;
   }
   
   //Maximum monetary amount of our equity that we are willing to lose in a single trade
   double maxRisk = pRiskPercent * 0.01 * AccountInfoDouble(ACCOUNT_EQUITY);

   //Value of 1 tick movement for 1 LOT in your account deposit currency - use with caution: can be incorrect for some assets (i.e. some stocks or indices)
   double tickValue = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_VALUE);
      
   //max risk amount divided by SL in points - it gives the money risked per point
   double riskPerPoint = maxRisk / (pSLInPricePoints / SymbolInfoDouble(pSymbol,SYMBOL_POINT));
   
   //Money that we risk per point divided by the value of 1 tick movement 
   //it reduces lots to the amount required to hit the desired loss per point
   double lotsRisked = riskPerPoint / tickValue;
   
   return lotsRisked;
}


//Verify and adjust volume
double CRM::VerifyVolume(string pSymbol,double pVolume)
{
	double minVolume  = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MIN);
	double maxVolume  = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MAX);
	double stepVolume = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_STEP);
	
	double verifiedVol;
	
	if(pVolume < minVolume)       verifiedVol = minVolume;
	else if(pVolume > maxVolume)  verifiedVol = maxVolume;
	else                          verifiedVol = MathRound(pVolume / stepVolume) * stepVolume;    //0.057785  MathRound(0.057785 / 0.01) * 0.01 -> 0.06
	
	return verifiedVol;
}

//Verify margin
bool CRM::VerifyMargin(string pSymbol,double pVolume,ENUM_ORDER_TYPE pOrderType,double pOpenPrice=0.0) //pOpenPrice==0.0 su dung voi lenh cho Pending Order
{
   if(pOpenPrice == 0)
   {
      if(pOrderType == ORDER_TYPE_BUY)       pOpenPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
      else if(pOrderType == ORDER_TYPE_SELL) pOpenPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);
   }
   
   double margin;
   if(!OrderCalcMargin(pOrderType,pSymbol,pVolume,pOpenPrice,margin)) Print(__FUNCTION__ + "(): Error calculating margin");
   
   if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE)) 
   {
      Print("No margin available to open a trade");
      return false;
   }   
   else return true;
}


//pNumberOfPeriods = số thanh của khung thời gian đã chọn
//pPeriod và pProfitPeriod: Các khung thời gian để xác định khoảng thời gian tính toán.
//pNumberOfPeriods: Số lượng khoảng thời gian để tính toán (ví dụ: số ngày, tuần, hoặc tháng của khung thời gian).
//pIncludeFloating: Xác định xem có tính lợi nhuận chưa thực hiện hay không (floating profit).
   //Lợi nhuận chưa thực hiện (floating profit) là lợi nhuận hoặc lỗ hiện tại của các giao dịch đang mở, chưa được đóng lại.
	//Nếu pIncludeFloating được đặt là true, thì lợi nhuận hiện tại (ACCOUNT_PROFIT) của các lệnh đang mở sẽ được cộng vào tổng lợi nhuận đã tính. Điều này giúp phản ánh chính xác hơn giá trị tài khoản thực tế tại thời điểm đó.
	//Nếu pIncludeFloating là false, chỉ có lợi nhuận của các giao dịch đã đóng mới được tính, và các giao dịch đang mở sẽ không ảnh hưởng đến kết quả tính toán.
//pReport: Chuỗi để lưu trữ báo cáo kết quả tính toán.
double CRM::GetEquityChange(ENUM_TIMEFRAMES pPeriod,ENUM_TIMEFRAMES pProfitPeriod,uchar pNumberOfPeriods,bool pIncludeFloating,string &pReport)
{
   //startTime: Thời gian bắt đầu tính toán được xác định bằng cách lấy thời điểm theo khung thời gian pProfitPeriod và số lượng pNumberOfPeriods chỉ định.
   //endTime: Thời gian kết thúc được xác định dựa trên pPeriod (thường là thời gian hiện tại).
   datetime startTime   = iTime(NULL,pProfitPeriod,pNumberOfPeriods);
   datetime endTime     = iTime(NULL,pPeriod,0); 

   StringAdd(pReport,"TIME RANGE: " + TimeToString(startTime) + " - " + TimeToString(endTime) + "\n");
      
   //Retrieves the history of deals and orders for the specified period of server time.
   //HistorySelect(startTime, endTime): Lọc các giao dịch đã thực hiện trong khoảng thời gian từ startTime đến endTime.
   HistorySelect(startTime,endTime);

   //total = HistoryDealsTotal(): Đếm tổng số giao dịch trong lịch sử đã lọc.
   uint     total    = HistoryDealsTotal(); 
   ulong    ticket   = 0; 
   double   profit   = 0;
   ulong    type     = 0; 
   
   //--- for all deals 
   //HistoryDealGetTicket(i): Lấy số vé giao dịch tại vị trí i. Nếu giá trị này lớn hơn 0 (giao dịch tồn tại), nó sẽ tiếp tục.
   //HistoryDealGetInteger(ticket, DEAL_TYPE): Kiểm tra loại giao dịch. Nếu loại giao dịch là DEAL_TYPE_BALANCE, thì tiếp tục sang giao dịch tiếp theo mà không tính vào lợi nhuận (điều này là do các giao dịch này chỉ liên quan đến tiền nạp/rút, không phải lợi nhuận từ giao dịch).
   //HistoryDealGetDouble(ticket, DEAL_PROFIT): Nếu không phải là DEAL_TYPE_BALANCE, lợi nhuận của giao dịch được cộng vào biến profit.
   //Nếu pIncludeFloating là true, giá trị lợi nhuận hiện tại (ACCOUNT_PROFIT) sẽ được cộng thêm vào biến profit.
   for(uint i=0 ; i<total ; i++) 
   { 
      //--- try to get deals ticket and add profit to variable
      if((ticket = HistoryDealGetTicket(i)) > 0) 
      { 
         type = HistoryDealGetInteger(ticket,DEAL_TYPE);
         if(type == DEAL_TYPE_BALANCE) continue;
         
         profit += HistoryDealGetDouble(ticket,DEAL_PROFIT); 
      } 
   } 

   //-- take into account floating profit
   if(pIncludeFloating) profit += AccountInfoDouble(ACCOUNT_PROFIT);
   
   return profit;    
}

bool CRM::MaxLoss(double pMaxLossPercent,ENUM_TIMEFRAMES pPeriod,ENUM_TIMEFRAMES pProfitPeriod,uchar pNumberOfPeriods,bool pIncludeFloating,string &pReport)
{
   //Nếu giá trị pMaxLossPercent (phần trăm lỗ tối đa) bằng 0, hàm sẽ ngay lập tức trả về false, bởi vì không có ngưỡng lỗ tối đa nào được thiết lập.
   if(pMaxLossPercent == 0) return false;
   
   //Hàm GetEquityChange được sử dụng để tính toán mức thay đổi vốn trong khoảng thời gian xác định, và nó có thể bao gồm cả lợi nhuận chưa thực hiện (floating profit) nếu pIncludeFloating được đặt là true.
   double currentChange = GetEquityChange(pPeriod,pProfitPeriod,pNumberOfPeriods,pIncludeFloating,pReport);

   //maxLoss là số tiền lỗ tối đa mà tài khoản có thể chịu được. Nó được tính bằng cách lấy phần trăm lỗ tối đa (pMaxLossPercent) nhân với -0.01 (để chuyển đổi thành giá trị âm) và nhân với số vốn hiện tại của tài khoản (ACCOUNT_EQUITY).
   double maxLoss = pMaxLossPercent * -0.01 * AccountInfoDouble(ACCOUNT_EQUITY);
   
   //Nếu mức lỗ hiện tại (currentChange) lớn hơn maxLoss (ít lỗ hơn hoặc lợi nhuận dương), hàm sẽ thêm thông tin vào chuỗi pReport và trả về false, nghĩa là mức lỗ chưa vượt quá ngưỡng.
	//Nếu ngược lại, mức lỗ hiện tại nhỏ hơn hoặc bằng maxLoss, nghĩa là đã vượt quá ngưỡng lỗ cho phép, hàm sẽ cập nhật chuỗi pReport với thông báo “LOSS EXCEEDED” và trả về true:
   if(currentChange > maxLoss)
   {
      StringAdd(pReport,"CURRENT CHANGE: " + DoubleToString(currentChange,2) + " | MAX LOSS: " + DoubleToString(maxLoss,2) + "\n"); 
      return false;
   }
   
   else 
   {
      StringAdd(pReport,"CURRENT CHANGE: " + DoubleToString(currentChange,2) + " | MAX LOSS: " + DoubleToString(maxLoss,2) + " - LOSS EXCEEDED" + "\n"); 
      return true; 
   }  
}
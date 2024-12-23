//+------------------------------------------------------------------+
//|                                                  Multisymbol.mqh |
//|                                          José Martínez Hernández |
//|                                         https://greaterwaves.com |
//+------------------------------------------------------------------+
#property copyright "José Martínez Hernández"
#property link      "https://greaterwaves.com"

#include "Enums.mqh"

class CMultiSymbol
{
   private:
      ENUM_SYMBOLS      mSymbols;
      ulong             mMagicNumberSeed;
      
      int               SetSymbols();
      int               SetMagicNumbers();

      int               mNumberOfTradeSymbols; 
      string            mTradeSymbols[];
      ulong             mMagicNumbers[];
   
   public:
      
      int               GetNumberOfSymbols()       {     return mNumberOfTradeSymbols;    }
      string            GetSymbol(int pIndex)      {     return mTradeSymbols[pIndex];    }
      ulong             GetMagic(int pIndex)       {     return mMagicNumbers[pIndex];    }     
                            
      int               OnInitEvent();
                     
                        CMultiSymbol(ENUM_SYMBOLS pSymbols,ulong pMagicNumberSeed);  
};

CMultiSymbol::CMultiSymbol(ENUM_SYMBOLS pSymbols,ulong pMagicNumberSeed)
{
   ZeroMemory(mSymbols);
   mSymbols          = pSymbols; 
   
   mMagicNumberSeed  = pMagicNumberSeed; 
}

int CMultiSymbol::OnInitEvent(void)
{
   //Order is important   
   //1st we set the array of symbols
   int ret = SetSymbols();
   if(ret != INIT_SUCCEEDED)  return ret;
   
   //Next we check if symbols exist and set magic numbers for each one
   ret = SetMagicNumbers();
   if(ret != INIT_SUCCEEDED)  return ret;
   
   return INIT_SUCCEEDED;  
}

int CMultiSymbol::SetSymbols(void)
{
   string symbolList = "";
   
   if(mSymbols == SYMBOLS_CURRENT)
   {
      mNumberOfTradeSymbols = 1;
      
      ArrayResize(mTradeSymbols, 1);
      mTradeSymbols[0] = Symbol();         
   }
   
   else if(mSymbols == SYMBOLS_FX_MAJORS)
   {
      symbolList = "USDJPY|GBPUSD|EURUSD|USDCHF";
      
      //Split the string SymbolList by  the character | and assign each split element to an element of the array
      mNumberOfTradeSymbols = StringSplit(symbolList, '|', mTradeSymbols);   
   }
      
   Print(__FUNCTION__ + " >> EA will process the following symbols: "); 
   ArrayPrint(mTradeSymbols);
   
   if(mNumberOfTradeSymbols > 0 ) return INIT_SUCCEEDED;
   else
   {
      PrintFormat("%s >> There was an error constructing symbols array. A total of %s symbols were selected", __FUNCTION__,(string)mNumberOfTradeSymbols);
      return INIT_FAILED;
   }
}

//We assign magic numbers and check if symbols exist
int CMultiSymbol::SetMagicNumbers(void)
{
   ArrayResize(mMagicNumbers,mNumberOfTradeSymbols);
   
   bool  symbolIsCustom = false;
   ulong magic          = mMagicNumberSeed;
   
   for(int i = 0 ; i < mNumberOfTradeSymbols ; i++)
   {
      if(!SymbolExist(mTradeSymbols[i],symbolIsCustom))
      {
         PrintFormat("%s >> %s does not exist",__FUNCTION__,mTradeSymbols[i]);
         return INIT_PARAMETERS_INCORRECT;
      }
      
      mMagicNumbers[i] = magic;
      magic++;
   }
   
   return INIT_SUCCEEDED;
}
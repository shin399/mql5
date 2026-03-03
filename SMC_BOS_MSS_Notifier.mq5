#property copyright "OpenAI"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

input int    SwingStrength      = 3;     // Bars to the left/right for swing confirmation
input int    MaxBarsToScan      = 500;   // Maximum bars scanned for recent swings
input bool   EnablePush         = true;  // Send push notification to MT5 mobile app
input bool   EnableAlertPopup   = true;  // Show terminal popup alert
input bool   EnableChartArrows  = true;  // Draw signal arrows on chart
input string NotificationPrefix = "SMC"; // Prefix in alert/notification text

struct SwingPoint
{
   bool     found;
   int      index;
   datetime time;
   double   price;
};

bool IsSwingHigh(const int i,const int rates_total,const double &high[])
{
   if(i < SwingStrength || i > rates_total - SwingStrength - 1)
      return false;

   for(int k=1; k<=SwingStrength; k++)
   {
      if(high[i] <= high[i-k] || high[i] <= high[i+k])
         return false;
   }
   return true;
}

bool IsSwingLow(const int i,const int rates_total,const double &low[])
{
   if(i < SwingStrength || i > rates_total - SwingStrength - 1)
      return false;

   for(int k=1; k<=SwingStrength; k++)
   {
      if(low[i] >= low[i-k] || low[i] >= low[i+k])
         return false;
   }
   return true;
}

void GetRecentSwings(const int rates_total,
                     const datetime &time[],
                     const double &high[],
                     const double &low[],
                     SwingPoint &lastHigh,
                     SwingPoint &prevHigh,
                     SwingPoint &lastLow,
                     SwingPoint &prevLow)
{
   lastHigh.found=false; prevHigh.found=false;
   lastLow.found=false;  prevLow.found=false;

   int upperBound = rates_total - SwingStrength - 1;
   int searchLimit = MathMin(upperBound, MaxBarsToScan);

   for(int i=SwingStrength+1; i<=searchLimit; i++)
   {
      if(!lastHigh.found && IsSwingHigh(i, rates_total, high))
      {
         lastHigh.found = true;
         lastHigh.index = i;
         lastHigh.time  = time[i];
         lastHigh.price = high[i];
         continue;
      }
      if(lastHigh.found && !prevHigh.found && IsSwingHigh(i, rates_total, high))
      {
         prevHigh.found = true;
         prevHigh.index = i;
         prevHigh.time  = time[i];
         prevHigh.price = high[i];
      }

      if(!lastLow.found && IsSwingLow(i, rates_total, low))
      {
         lastLow.found = true;
         lastLow.index = i;
         lastLow.time  = time[i];
         lastLow.price = low[i];
         continue;
      }
      if(lastLow.found && !prevLow.found && IsSwingLow(i, rates_total, low))
      {
         prevLow.found = true;
         prevLow.index = i;
         prevLow.time  = time[i];
         prevLow.price = low[i];
      }

      if(lastHigh.found && prevHigh.found && lastLow.found && prevLow.found)
         break;
   }
}

void SendSignal(const string signalType,
                const datetime barTime,
                const double price,
                const bool bullish)
{
   string tf = EnumToString((ENUM_TIMEFRAMES)_Period);
   string direction = bullish ? "BUY" : "SELL";

   string message = StringFormat("%s | %s %s | %s | Price: %.5f | Time: %s",
                                 NotificationPrefix,
                                 _Symbol,
                                 tf,
                                 signalType + " " + direction,
                                 price,
                                 TimeToString(barTime, TIME_DATE|TIME_MINUTES));

   Print(message);
   if(EnableAlertPopup)
      Alert(message);

   if(EnablePush)
   {
      if(!SendNotification(message))
         PrintFormat("SendNotification failed. Error: %d", GetLastError());
   }
}

void DrawSignalArrow(const datetime barTime,
                     const double price,
                     const bool bullish,
                     const string label)
{
   if(!EnableChartArrows)
      return;

   string name = StringFormat("SMC_%s_%I64d", label, (long)barTime);
   if(ObjectFind(0, name) >= 0)
      return;

   ObjectCreate(0, name, bullish ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, barTime, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bullish ? clrLime : clrTomato);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, name, OBJPROP_TEXT, label);
}

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "SMC BOS/MSS Notifier");
   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < (SwingStrength*4 + 20))
      return rates_total;

   static datetime lastProcessedBar = 0;

   // Process only once when a new candle appears (using last closed candle time)
   if(time[1] == lastProcessedBar)
      return rates_total;

   lastProcessedBar = time[1];

   SwingPoint lastHigh, prevHigh, lastLow, prevLow;
   GetRecentSwings(rates_total, time, high, low, lastHigh, prevHigh, lastLow, prevLow);

   if(!(lastHigh.found && prevHigh.found && lastLow.found && prevLow.found))
      return rates_total;

   bool upTrend   = (lastHigh.price > prevHigh.price && lastLow.price > prevLow.price);
   bool downTrend = (lastHigh.price < prevHigh.price && lastLow.price < prevLow.price);

   double closePrice = close[1];

   // Smart Money Concepts interpretation:
   // - BOS: continuation break in trend direction
   // - MSS: break against current trend (potential shift)
   if(upTrend)
   {
      if(closePrice > lastHigh.price)
      {
         SendSignal("BOS", time[1], closePrice, true);
         DrawSignalArrow(time[1], low[1], true, "BOS_BUY");
      }
      else if(closePrice < lastLow.price)
      {
         SendSignal("MSS", time[1], closePrice, false);
         DrawSignalArrow(time[1], high[1], false, "MSS_SELL");
      }
   }
   else if(downTrend)
   {
      if(closePrice < lastLow.price)
      {
         SendSignal("BOS", time[1], closePrice, false);
         DrawSignalArrow(time[1], high[1], false, "BOS_SELL");
      }
      else if(closePrice > lastHigh.price)
      {
         SendSignal("MSS", time[1], closePrice, true);
         DrawSignalArrow(time[1], low[1], true, "MSS_BUY");
      }
   }
   else
   {
      // Neutral structure fallback: treat breakouts as BOS
      if(closePrice > lastHigh.price)
      {
         SendSignal("BOS", time[1], closePrice, true);
         DrawSignalArrow(time[1], low[1], true, "BOS_BUY");
      }
      else if(closePrice < lastLow.price)
      {
         SendSignal("BOS", time[1], closePrice, false);
         DrawSignalArrow(time[1], high[1], false, "BOS_SELL");
      }
   }

   return rates_total;
}

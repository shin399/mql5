# MT5 SMC BOS/MSS Notifier

This repository contains an MT5 indicator (`SMC_BOS_MSS_Notifier.mq5`) that sends BUY/SELL notifications based on Smart Money Concepts structure events:

- **BOS (Break of Structure)**
- **MSS (Market Structure Shift)**

## Features

- Push notifications to MetaTrader mobile app (`SendNotification`)
- Optional terminal popup alerts
- Optional chart arrows for each signal
- Works on closed candles only (avoids intra-candle noise)

## Install

1. Open **MetaEditor**.
2. Create a new custom indicator and replace its code with `SMC_BOS_MSS_Notifier.mq5`.
3. Compile and attach to a chart.
4. In MT5 terminal, enable push notifications:
   - `Tools -> Options -> Notifications`
   - Enter your MetaQuotes ID and test.

## Inputs

- `SwingStrength`: bars left/right used to confirm swing highs/lows
- `MaxBarsToScan`: how many bars to scan for recent structure
- `EnablePush`: enable mobile push notifications
- `EnableAlertPopup`: enable popup alerts in terminal
- `EnableChartArrows`: draw arrows where signals happen

## Notes

- BOS is treated as continuation in trend direction.
- MSS is treated as break against current trend (potential shift).
- Tune `SwingStrength` by timeframe:
  - Lower values for faster/more frequent signals.
  - Higher values for cleaner/slower signals.

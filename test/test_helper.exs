prices = Oanda.Interface.get_prices("H1", "CAD_CHF", 100, %{ts_to: 1603797589})
prices = prices |> Sansa.TradingUtils.atr
Sansa.Patterns.check_pattern(:shooting_star, prices, Sansa.ZonePuller.get_zones("CAD_CHF"))


prices = Oanda.Interface.get_prices("H1", "USD_CHF", 100, %{ts_to: 1603844389})
prices = prices |> Sansa.TradingUtils.atr
Sansa.Patterns.check_pattern(:engulfing, prices, Sansa.ZonePuller.get_zones("USD_CHF"))

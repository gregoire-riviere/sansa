prices = Oanda.Interface.get_prices("H1", "CAD_CHF", 100, %{ts_to: 1603682389})
prices = prices |> Sansa.TradingUtils.atr
Sansa.Patterns.check_pattern(:shooting_star, prices, Sansa.ZonePuller.get_zones("CAD_CHF"))

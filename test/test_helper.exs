prices = Oanda.Interface.get_prices("H1", "CAD_CHF", 100, %{ts_to: 1603797589})
prices = prices |> Sansa.TradingUtils.atr
Sansa.Patterns.check_pattern(:shooting_star, prices, Sansa.ZonePuller.get_zones("CAD_CHF"))


prices = Oanda.Interface.get_prices("H1", "EUR_USD", 100, %{ts_to: 1600096789})
prices = prices |> Sansa.TradingUtils.atr
Sansa.Patterns.check_pattern(:shooting_star, prices, Sansa.ZonePuller.get_zones("EUR_USD"))

start_ts = 1600071589
0..100 |> Enum.map(& &1*3600 + start_ts) |> Enum.each(fn t ->
  IO.inspect(t |> DateTime.from_unix!(:seconds))
  Sansa.Price.Watcher.test_loop("EUR_USD", t)
end)

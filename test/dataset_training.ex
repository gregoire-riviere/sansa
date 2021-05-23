defmodule Toto do
  def smart_round(k, n) do
    Float.round(k * 1.0, n)
  end
end

require Logger
paire="AUD_JPY"
dataset = Oanda.Interface.get_prices("H1", paire, 4999)
dataset_augmented = dataset |> Enum.split(250) |> elem(1) |>
Sansa.TradingUtils.atr |>
Sansa.TradingUtils.ema(50, :close, :ema_50) |>
Sansa.TradingUtils.ema(200, :close, :ema_200) |>
Sansa.TradingUtils.schaff_tc() |>
Sansa.TradingUtils.rsi |>
Sansa.TradingUtils.ichimoku |>
Enum.drop(203) |>
Enum.map(fn price ->
  Map.put(price, :candle_color, price.close < price.open && :red || :green) |>
  Map.put(:candle_size, Toto.smart_round((price.close - price.open)/ price.atr, 1)) |>
  Map.put(:kj_tk, price.kj < price.tk && :up || :down) |>
  Map.put(:rsi, Toto.smart_round(price.rsi, 1)) |>
  Map.put(:schaff_tc, Toto.smart_round(price.schaff_tc, 1)) |>
  Map.put(:ema_200_pr_50, price.ema_200 > price.ema_50 && :above || :under) |>
  Map.put(:price_ema_200, Toto.smart_round(abs((price.close - price.ema_200) / Sansa.TradingUtils.pip_position(paire)), 1))
end)
ts = dataset_augmented |> Enum.map(& &1.time)

stop_atr = 1.5
rrp = 2.5

# Buy
ts_classified = ts |> Task.async_stream(fn t ->
  data = dataset |> Enum.sort_by(& &1.time) |>
  Enum.filter(& &1.time > t)
  candle = dataset_augmented |> Enum.find(& &1.time == t)
  stop_price = candle.close - candle.atr * stop_atr
  tp_price = candle.close + abs(candle.close - stop_price)*rrp
  Enum.reduce_while(data, {t, nil}, fn x, acc ->
    cond do
      x.low <= stop_price ->
        Logger.debug("ok")
        {:halt, {t, :no}}
      x.high > tp_price ->
        Logger.debug("ok - yes")
        {:halt, {t, :yes}}
      true -> {:cont, {t, nil}}
    end
  end)
end, max_concurrency: 150, timeout: :infinity) |> Enum.to_list

example = ts_classified |> Enum.count(fn
  {k, {t, r}} -> r == :yes
  {k, nil} -> false
end)

ts_classified = ts_classified |> Enum.map(fn {k, v} ->
  v
end) |> Enum.into(%{})
dataset_final = Enum.map(dataset_augmented, & &1 |> put_in([:outcome], ts_classified[&1.time]))

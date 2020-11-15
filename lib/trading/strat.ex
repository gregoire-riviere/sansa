defmodule Sansa.Strat do

  require Logger

  def run_strat(name, paire, new_prices, rrp, stop_placement) do
    case evaluate_strat(name, new_prices) do
      :buy ->
        Sansa.Orders.new_order(paire, new_prices, :buy, rrp, stop_placement)
        :long_position
      :sell ->
        Sansa.Orders.new_order(paire, new_prices, :buy, rrp, stop_placement)
        :short_position
      _ -> :ok
    end
  end

  def evaluate_strat(:ema_cross, new_prices) do
    new_prices = new_prices
    |> Sansa.TradingUtils.ema(200, :close, :long_trend_200)
    |> Sansa.TradingUtils.ema(9, :close, :ema_9)
    |> Sansa.TradingUtils.ema(20, :close, :ema_20)
    current_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)
    corps_candle = abs(current_price.close - current_price.open)

    cond do
      current_price.ema_9 >= current_price.ema_20 && price_before.ema_9 < price_before.ema_20 && current_price.close > current_price.long_trend_200 && current_price.low > current_price.ema_20 && corps_candle < 2*current_price.atr ->
        :buy
      current_price.ema_9 <= current_price.ema_20 && price_before.ema_9 > price_before.ema_20 && current_price.close < current_price.long_trend_200 && current_price.high < current_price.ema_20 && corps_candle < 2*current_price.atr->
        :sell
      true ->
        :nothing
    end
  end

  def evaluate_strat(:macd_cross, new_prices) do
    new_prices = new_prices
    |> Sansa.TradingUtils.ema(200, :close, :long_trend_200)
    |> Sansa.TradingUtils.macd
    current_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)

    cond do
      current_price.macd_histo >= 0 && price_before.macd_histo <= 0 && current_price.close > current_price.long_trend_200 && current_price.macd_value < 0 ->
        :buy
      current_price.macd_histo <= 0 && price_before.macd_histo >= 0 && current_price.close < current_price.long_trend_200 && current_price.macd_value > 0 ->
        :sell
      true ->
        :nothing
    end
  end

  def evaluate_strat(:ss_ema, new_prices) do
    new_prices = new_prices |> Sansa.TradingUtils.ema(100, :close, :long_trend_100)
    last_price = new_prices |> Enum.reverse |> hd
    whole_candle = last_price[:high] - last_price[:low]
    min_o_c = Enum.min([last_price[:close], last_price[:open]])
    max_o_c = Enum.max([last_price[:close], last_price[:open]])
    bot_wick = abs(min_o_c - last_price[:low])
    top_wick = abs(max_o_c - last_price[:high])

    cond do
      bot_wick >= 0.666 * whole_candle && whole_candle >= 0.5*last_price[:atr] &&
      whole_candle < 2.5 * last_price[:atr]  && last_price.low <= last_price.long_trend_100 &&
      last_price.close > last_price.long_trend_100 && last_price.rsi < 50 ->
        :buy
      top_wick >= 0.666 * whole_candle && whole_candle >= 0.5 * last_price[:atr] &&
      whole_candle < 2.5 * last_price[:atr] && last_price.high >= last_price.long_trend_100 &&
      last_price.close < last_price.long_trend_100 && last_price.rsi > 50 ->
        :sell
      true ->
        :nothing
    end
  end

  def evaluate_strat(:ich_cross, new_prices) do
    new_prices = new_prices |> Sansa.TradingUtils.ichimoku
    last_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)

    cond do
      last_price.close > last_price.ssa && last_price.close > last_price.ssb &&
      price_before.tk < price_before.kj && last_price.tk > last_price.kj ->
        :buy
      last_price.close < last_price.ssa && last_price.close < last_price.ssb &&
      price_before.tk > price_before.kj && last_price.tk < last_price.kj ->
        :sell
      true ->
        :nothing
    end
  end

end

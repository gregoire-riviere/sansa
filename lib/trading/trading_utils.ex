defmodule Sansa.TradingUtils do

  require Logger

  defp init_first(list_prices, nb_prices, key, value) do
    {first_prices, _last_prices} = Enum.split(list_prices, nb_prices)
    Enum.map(first_prices, & put_in(&1, [key], value))
  end

  def sma(list_price, nb_periods, key \\ :close, dest_key \\ :sma) do
    if Enum.count(list_price) <= nb_periods do
        Logger.error("Nb of periods too large!")
        :error
    else
        {first_prices, _} = Enum.split(list_price, nb_periods - 1)
        first_prices = Enum.map(first_prices, & put_in(&1, [dest_key], 0))
        last_prices  = Enum.chunk_every(list_price, nb_periods, 1, :discard) |> Enum.map(fn chunck ->
            put_in(Enum.reverse(chunck) |> hd, [dest_key], (Enum.sum(Enum.map(chunck, & &1[key]))/nb_periods))
        end)
        first_prices ++ last_prices
    end
  end

  def ema(list_price, nb_periods, key \\ :close, dest_key \\ :ema) do
    if Enum.count(list_price) <= nb_periods do
        Logger.error("Nb of periods too large!")
        list_price
    else
        {first_prices, last_prices} = Enum.split(list_price, nb_periods)
        init_state = %{
            previous_ema: (Enum.map(first_prices, & &1[key]) |> Enum.sum)/nb_periods,
            prices: []
        }
        result = Enum.reduce(last_prices, init_state, fn p, acc ->
            previous_ema = acc.previous_ema
            current_ema = (p[key] - previous_ema)*(2/(nb_periods + 1)) + previous_ema
            %{
                previous_ema: current_ema,
                prices: acc.prices ++ [put_in(p, [dest_key], current_ema)]
            }
        end)
        last_prices = result.prices
        first_prices = Enum.map(first_prices, & put_in(&1, [dest_key], 0))
        first_prices ++ last_prices
    end
  end

  def tr(price) do
    price |>
    Enum.map(& put_in(&1, [:tr], &1.high - &1.low))
  end

  def atr(list_price, nb_periods \\ 14, dest_key \\ :atr) do
    if Enum.count(list_price) <= nb_periods do
        Logger.error("Nb of periods too large!")
        :error
    else
        list_price |>
        tr |>
        ema(nb_periods, :tr, dest_key)
    end
  end

  def macd(list_price) do
    list_price |> ema(12, :close, :macd_short_ema) |> ema(26, :close, :macd_long_ema) |> Enum.map(& put_in(&1, [:macd_value], &1.macd_short_ema - &1.macd_long_ema)) |> ema(9, :macd_value, :macd_signal) |> Enum.map(& put_in(&1, [:macd_histo], &1.macd_value - &1.macd_signal))
  end

  # def bol(list_price, nb_periods \\ 20) do
  #   list_price = sma(list_price, nb_periods, :close, :bol_mm)
  #   {first_prices, _} = Enum.split(list_price, nb_periods - 1)
  #   first_prices = Enum.map(first_prices, & put_in(&1, [:bol_high], 0) |> put_in([:bol_low], 0))
  #   last_prices = Enum.chunk_every(list_price, nb_periods, 1, :discard) |> Enum.map(fn chunck ->
  #       price = Enum.reverse(chunck) |> hd
  #       moyenne = price.bol_mm
  #       std_dev = std_deviation(chunck |> Enum.map(& &1.close), moyenne)
  #       put_in(price, [:bol_high], moyenne + 2*std_dev) |>
  #       put_in([:bol_low], moyenne - 2*std_dev)
  #   end)
  #   first_prices ++ last_prices
  # end

  def roc(list_price, length \\ 9, dest_key \\ :roc) do
    init_first(list_price, length, dest_key, 0) ++
    list_price |> Enum.chunk_every(length+1, 1, :discard) |> Enum.map(fn l_p ->
       c = l_p |> Enum.reverse |> hd
       p = l_p |> hd
       c |> put_in([dest_key], 100 * (c.close - p.close)/(p.close))
    end)
  end

  def kst(list_price) do
    list_price
    |> roc(10, :roc_10)
    |> roc(15, :roc_15)
    |> roc(20, :roc_20)
    |> roc(30, :roc_30)
    |> sma(10, :roc_10, :roc_mm1)
    |> sma(10, :roc_15, :roc_mm2)
    |> sma(10, :roc_20, :roc_mm3)
    |> sma(15, :roc_30, :roc_mm4)
    |> Enum.map(& put_in(&1, [:kst], &1.roc_mm1 * 1 + &1.roc_mm2 * 2 + &1.roc_mm3 * 3 + &1.roc_mm4 * 4))
    |> Enum.map(fn p ->
        p |>
        pop_in([:roc_10]) |> elem(1) |>
        pop_in([:roc_15]) |> elem(1) |>
        pop_in([:roc_20]) |> elem(1) |>
        pop_in([:roc_30]) |> elem(1) |>
        pop_in([:roc_mm1]) |> elem(1) |>
        pop_in([:roc_mm2]) |> elem(1) |>
        pop_in([:roc_mm3]) |> elem(1) |>
        pop_in([:roc_mm4]) |> elem(1)
    end) |> sma(9, :kst, :kst_sig)
  end


  def pip_position(paire) do
    if String.contains?(paire, "JPY"), do: 0.01, else: 0.0001
  end


  defp rs(prices) do
      gain = Enum.filter(prices, & &1.close > &1.open) |> Enum.map(& &1.close - &1.open) |> Enum.sum
      loss = Enum.filter(prices, & &1.close < &1.open) |> Enum.map(& &1.open - &1.close) |> Enum.sum
      loss == 0 && gain || gain/loss
  end

  def rsi(list_price, nb_periods \\ 14) do
      {first_prices, _} = Enum.split(list_price, nb_periods - 1)
      first_prices = Enum.map(first_prices, & put_in(&1, [:rsi], 0))
      last_prices = Enum.chunk_every(list_price, nb_periods, 1, :discard) |> Enum.map(fn chunck ->
          put_in(Enum.reverse(chunck) |> hd, [:rsi], (100 - (100 / (1 + rs(chunck)))))
      end)
      first_prices ++ last_prices
  end

  def baseline(list_price, nb_periods \\ 50, dest_key \\ :baseline) do
      {first_prices, _} = Enum.split(list_price, nb_periods - 1)
      first_prices = Enum.map(first_prices, & put_in(&1, [dest_key], 0))
      last_prices = Enum.chunk_every(list_price, nb_periods, 1, :discard) |> Enum.map(fn chunck ->
          price = Enum.reverse(chunck) |> hd
          middle_point = (Enum.max(Enum.map(chunck, & &1.high)) + Enum.min(Enum.map(chunck, & &1.low)))/2
          put_in(price, [dest_key], middle_point)
      end)
      first_prices ++ last_prices
  end

  def ichimoku(list_prices) do
    list_prices = list_prices |> baseline(9, :tk) |> baseline(26, :kj)
    |> baseline(52, :ssb)
    |> Enum.map(fn p->
        if p[:tk] && p[:kj] do
            put_in(p, [:ssa], (p.tk + p.kj)/2)
        end
    end)
    # Decalage
    {first_prices, last_prices} = Enum.split(list_prices, 26)
    first_prices ++ (last_prices |> Enum.with_index |> Enum.map(fn {p, i} ->
        put_in(p, [:ssa], Enum.at(list_prices, i)[:ssa]) |> put_in([:ssb], Enum.at(list_prices, i)[:ssb])
    end))
  end

end

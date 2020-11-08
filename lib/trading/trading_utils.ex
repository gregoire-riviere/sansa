defmodule Sansa.TradingUtils do

  require Logger

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

  # def sma(list_price, nb_periods, key \\ :close, dest_key \\ :sma) do
  #   if Enum.count(list_price) <= nb_periods do
  #       Logger.error("Nb of periods too large!")
  #       :error
  #   else
  #       {first_prices, _} = Enum.split(list_price, nb_periods - 1)
  #       first_prices = Enum.map(first_prices, & put_in(&1, [dest_key], 0))
  #       last_prices = Enum.chunk_every(list_price, nb_periods, 1, :discard) |> Enum.map(fn chunck ->
  #           put_in(Enum.reverse(chunck) |> hd, [dest_key], (Enum.sum(Enum.map(chunck, & &1[key]))/nb_periods))
  #       end)
  #       first_prices ++ last_prices
  #   end
  # end

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
  def pip_position(paire) do
    if String.contains?(paire, "JPY"), do: 0.01, else: 0.0001
  end
end

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

  def pip_position(paire) do
    if String.contains?(paire, "JPY"), do: 0.01, else: 0.0001
  end
end

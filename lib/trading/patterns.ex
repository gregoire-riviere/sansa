defmodule Sansa.Patterns do

  require Logger

  ### Zones format :
  # {
  #     h: [borne haute],
  #     l: [borne basse],
  #     bias: [buy ou sell - facultatif]
  # }
  def run_pattern_detection(type, prices, zones) do
    Enum.reduce_while(zones, :no_trade, fn zone, acc ->
      case zone do
        %{bias: "buy"} ->
          if check_pattern(type, "buy", zone, prices), do: {:halt, {:ok, zone, :buy}}, else: {:cont, acc}
        %{bias: "sell"} ->
          if check_pattern(type, "sell", zone, prices), do: {:halt, {:ok, zone, :sell}}, else: {:cont, acc}
        _ ->
          cond do
            check_pattern(type, "buy", zone, prices) -> {:halt, {:ok, zone, :buy}}
            check_pattern(type, "sell", zone, prices) -> {:halt, {:ok, zone, :sell}}
            true -> {:cont, acc}
          end
      end
    end)
  end

  ## Shooting star pattern
  ## -> trying to spot long wick candle with small body
  ## Note : we tend to avoid extremely large candle (even with huge wick)

  def check_pattern(:shooting_star, "buy", zone, prices) do
    last_price = prices |> Enum.reverse |> hd
    corps_candle = abs(last_price[:open] - last_price[:close])
    whole_candle = last_price[:high] - last_price[:low]
    min_o_c = Enum.min([last_price[:close], last_price[:open]])
    max_o_c = Enum.max([last_price[:close], last_price[:open]])
    bot_wick = abs(min_o_c - last_price[:low])
    # top_wick = abs(max_o_c - last_price[:high])

    # -- conditions
    max_o_c > zone[:l]                   &&
    last_price[:low] < zone[:h]          &&
    bot_wick >= 0.666*whole_candle       &&
    corps_candle <= last_price[:atr]     &&
    whole_candle >= 0.5*last_price[:atr] &&
    whole_candle < 2.5 * last_price[:atr]
  end

  def check_pattern(:shooting_star, "sell", zone, prices) do
    last_price = prices |> Enum.reverse |> hd
    corps_candle = abs(last_price[:open] - last_price[:close])
    whole_candle = last_price[:high] - last_price[:low]
    min_o_c = Enum.min([last_price[:close], last_price[:open]])
    max_o_c = Enum.max([last_price[:close], last_price[:open]])
    # bot_wick = abs(min_o_c - last_price[:low])
    top_wick = abs(max_o_c - last_price[:high])

    # -- conditions
    min_o_c < zone[:h]                     &&
    last_price[:high] > zone[:l]           &&
    top_wick >= 0.666 * whole_candle       &&
    corps_candle <= last_price[:atr]       &&
    whole_candle >= 0.5 * last_price[:atr] &&
    whole_candle < 2.5 * last_price[:atr]
  end

  # Engulfing pattern
  # Candle 1 -> first candle, the one engulfed
  # Candle 2 -> the engulfing

  def in_zone(v, z), do: v <= z[:h] && v >= z[:l]

  def check_pattern(:engulfing, "buy", zone, prices) do
    candle_2 = prices |> Enum.reverse |> hd
    candle_1 = prices |> Enum.reverse |> Enum.at(1)
    corps_candle = abs(candle_2[:open] - candle_2[:close])
    # min_o_c = Enum.min([candle_2[:close], candle_2[:open]])
    max_o_c = Enum.max([candle_2[:close], candle_2[:open]])
    # bot_wick = abs(min_o_c - candle_2[:low])
    top_wick = abs(max_o_c - candle_2[:high])

    ## conditions --
    corps_candle <= 2 * candle_2[:atr] &&
    corps_candle >= 0.75 * candle_2[:atr] &&
    candle_1[:open] > candle_1[:close] &&
    candle_2[:open] < candle_2[:close] &&
    candle_1[:open] < candle_2[:close] &&
    top_wick < candle_2[:atr] &&
    (
      in_zone(candle_1[:open], zone) ||
      in_zone(candle_1[:close], zone) ||
      in_zone(candle_2[:open], zone) ||
      (candle_1.open > zone.h && candle_1.close < zone.l)
    )
  end

  def check_pattern(:engulfing, "sell", zone, prices) do
    candle_2 = prices |> Enum.reverse |> hd
    candle_1 = prices |> Enum.reverse |> Enum.at(1)
    corps_candle = abs(candle_2[:open] - candle_2[:close])
    min_o_c = Enum.min([candle_2[:close], candle_2[:open]])
    # max_o_c = Enum.max([candle_2[:close], candle_2[:open]])
    bot_wick = abs(min_o_c - candle_2[:low])
    # top_wick = abs(max_o_c - candle_2[:high])

    ## conditions --
    corps_candle <= 2 * candle_2[:atr] &&
    corps_candle >= 0.75 * candle_2[:atr] &&
    candle_1[:open] < candle_1[:close] &&
    candle_2[:open] > candle_2[:close] &&
    candle_1[:open] > candle_2[:close] &&
    bot_wick < candle_2[:atr] &&
    (
      in_zone(candle_1[:open], zone) ||
      in_zone(candle_1[:close], zone) ||
      in_zone(candle_2[:open], zone) ||
      (candle_1.close > zone.h && candle_1.open < zone.l)
    )
  end

  def check_pattern(:engulfing_bb, "buy", zone, prices) do
    candle_2 = prices |> Enum.reverse |> hd
    candle_1 = prices |> Enum.reverse |> Enum.at(1)
    corps_candle = abs(candle_2[:open] - candle_2[:close])
    min_o_c = Enum.min([candle_2[:close], candle_2[:open]])
    max_o_c = Enum.max([candle_2[:close], candle_2[:open]])
    bot_wick = abs(min_o_c - candle_2[:low])
    top_wick = abs(max_o_c - candle_2[:high])

    ## conditions --
    corps_candle < 2.5 * candle_2[:atr]   &&
    corps_candle >= 0.5 * candle_2[:atr]  &&
    candle_1[:open] > candle_1[:close]    &&
    candle_2[:open] < candle_2[:close]    &&
    candle_1[:open] < candle_2[:close]    &&
    bot_wick < candle_2[:atr]             &&
    candle_2[:close] > candle_2[:bol_low] &&
    candle_1[:close] < candle_1[:bol_low] &&
    candle_2[:high] < candle_2[:bol_mm]
  end

  def check_pattern(:engulfing_bb, "sell", zone, prices) do
    candle_2 = prices |> Enum.reverse |> hd
    candle_1 = prices |> Enum.reverse |> Enum.at(1)
    corps_candle = abs(candle_2[:open] - candle_2[:close])
    min_o_c = Enum.min([candle_2[:close], candle_2[:open]])
    max_o_c = Enum.max([candle_2[:close], candle_2[:open]])
    bot_wick = abs(min_o_c - candle_2[:low])
    top_wick = abs(max_o_c - candle_2[:high])

    ## conditions --
    corps_candle < 2.5 * candle_2[:atr]    &&
    corps_candle >= 0.5 * candle_2[:atr]   &&
    candle_1[:open] < candle_1[:close]     &&
    candle_2[:open] > candle_2[:close]     &&
    candle_1[:open] > candle_2[:close]     &&
    top_wick < candle_2[:atr]              &&
    candle_2[:close] < candle_2[:bol_high] &&
    candle_1[:close] > candle_1[:bol_high] &&
    candle_2[:low] > candle_2[:bol_mm]
  end

end

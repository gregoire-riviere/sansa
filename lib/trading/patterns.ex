defmodule Sansa.Patterns do

  require Logger

  ### Zones format :
  # {
  #     h: [borne haute],
  #     l: [borne basse],
  #     bias: [buy ou sell - facultatif]
  # }


  ## Shooting star pattern
  ## -> trying to spot long wick candle with small body
  ## Note : we tend to avoid extremely large candle (even with huge wick)
  def check_pattern(:shooting_star, prices, zones) do
    last_price = prices |> Enum.reverse |> hd
    Enum.reduce(zones, false, fn zone, acc ->
      corps_candle = abs(last_price[:open] - last_price[:close])
      min_o_c = Enum.min([last_price[:close], last_price[:open]])
      max_o_c = Enum.max([last_price[:close], last_price[:open]])
      bot_wick = abs(min_o_c - last_price[:low])
      top_wick = abs(max_o_c - last_price[:high])

      # The bias parameter determine the type of order
      acc || case zone[:bias] do
        "buy" ->
          max_o_c > zone[:l] &&
          last_price[:low] < zone[:h] &&
          bot_wick >= 2*corps_candle &&
          corps_candle <= last_price[:atr] &&
          top_wick <= 0.5*bot_wick &&
          abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
        "sell" ->
          min_o_c < zone[:h] &&
          last_price[:high] > zone[:l] &&
          top_wick >= 2*corps_candle &&
          corps_candle <= last_price[:atr] &&
          bot_wick <= 0.5*top_wick &&
          abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
        _ ->
          (
            max_o_c > zone[:l] &&
            last_price[:low] < zone[:h] &&
            bot_wick >= 2*corps_candle &&
            corps_candle <= last_price[:atr] &&
            top_wick <= 0.5*bot_wick &&
            abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
          ) || (
            min_o_c < zone[:h] &&
            last_price[:high] > zone[:l] &&
            top_wick >= 2*corps_candle &&
            corps_candle <= last_price[:atr] &&
            bot_wick <= 0.5*top_wick &&
            abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
          )
      end
    end)
  end

  def in_zone(v, z), do: v <= z[:h] && v >= z[:l]

  # Engulfing pattern
  # Candle 1 -> first candle, the one engulfed
  # Candle 2 -> the engulfing
  def check_pattern(:engulfing, prices, zones) do
    candle_2 = prices |> Enum.reverse |> hd
    candle_1 = prices |> Enum.reverse |> Enum.at(1)
    Enum.reduce(zones, false, fn zone, acc ->
      corps_candle = abs(candle_2[:open] - candle_2[:close])
      min_o_c = Enum.min([candle_2[:close], candle_2[:open]])
      max_o_c = Enum.max([candle_2[:close], candle_2[:open]])
      bot_wick = abs(min_o_c - candle_2[:low])
      top_wick = abs(max_o_c - candle_2[:high])
      acc ||
      (corps_candle < 2.5 * candle_2[:atr] &&
      corps_candle >= 0.3 * candle_2[:atr] &&
      case zone[:bias] do
        "buy" ->
          candle_1[:open] > candle_1[:close] &&
          candle_2[:open] < candle_2[:close] &&
          candle_1[:open] < candle_2[:close] &&
          top_wick < candle_2[:atr] &&
          (
            in_zone(candle_1[:open], zone) ||
            in_zone(candle_1[:close], zone) ||
            in_zone(candle_2[:open], zone)
          )
        "sell" ->
          candle_1[:open] < candle_1[:close] &&
          candle_2[:open] > candle_2[:close] &&
          candle_1[:open] > candle_2[:close] &&
          bot_wick < candle_2[:atr] &&
          (
            in_zone(candle_1[:open], zone) ||
            in_zone(candle_1[:close], zone) ||
            in_zone(candle_2[:open], zone)
          )
        _ ->
          (candle_1[:open] > candle_1[:close] &&
          candle_2[:open] < candle_2[:close] &&
          candle_1[:open] < candle_2[:close] &&
          top_wick < 0.5 * candle_2[:atr] &&
          (
            in_zone(candle_1[:open], zone) ||
            in_zone(candle_1[:close], zone) ||
            in_zone(candle_2[:open], zone)
          )) ||
          (candle_1[:open] < candle_1[:close] &&
          candle_2[:open] > candle_2[:close] &&
          candle_1[:open] > candle_2[:close] &&
          bot_wick < 0.5 * candle_2[:atr] &&
          (
            in_zone(candle_1[:open], zone) ||
            in_zone(candle_1[:close], zone) ||
            in_zone(candle_2[:open], zone)
          ))
        end)

    end)
  end
end

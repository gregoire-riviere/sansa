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
          top_wick <= corps_candle &&
          abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
        "sell" ->
          min_o_c < zone[:h] &&
          last_price[:high] > zone[:l] &&
          top_wick >= 2*corps_candle &&
          corps_candle <= last_price[:atr] &&
          bot_wick <= corps_candle &&
          abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
        _ ->
          (
            max_o_c > zone[:l] &&
            last_price[:low] < zone[:h] &&
            bot_wick >= 2*corps_candle &&
            corps_candle <= last_price[:atr] &&
            top_wick <= corps_candle &&
            abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
          ) || (
            min_o_c < zone[:h] &&
            last_price[:high] > zone[:l] &&
            top_wick >= 2*corps_candle &&
            corps_candle <= last_price[:atr] &&
            bot_wick <= corps_candle &&
            abs(last_price[:open] - last_price[:close]) < 2.5 * last_price[:atr]
          )
      end
    end)
  end

end

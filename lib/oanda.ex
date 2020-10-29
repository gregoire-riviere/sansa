defmodule Oanda.Interface do
  require Logger

  @default_ts %{ts_to: 0, ts_from: 0}
  @position_pip Application.get_env(:sansa, :trading)[:position_pip]

  def account_id(), do: File.read!(Application.get_env(:sansa, :oanda)[:account_id_file]) |> String.trim_trailing("\n")

  def main_header() do
      token = Application.get_env(:sansa, :oanda)[:token_file] |> File.read!
      [{'Authorization', '#{token}'}, {'Accept-Datetime-Format', 'UNIX'}]
  end

  def get_prices(ut, actif, nb_candles, opts \\ []) do
      %{ts_to: ts_to, ts_from: ts_from} = Enum.into(Enum.into(opts, %{}), @default_ts)

      ts_to = if ts_to == 0, do: "", else: "&to=#{ts_to}"
      ts_from = if ts_from == 0, do: "", else: "&from=#{ts_from}"
      url = 'https://api-fxpractice.oanda.com/v3/instruments/#{actif}/candles?count=#{nb_candles+1}&price=MAB&granularity=#{ut}#{ts_to}#{ts_from}'
      Logger.debug("#{url}")
      case :httpc.request(:get,{url, main_header()},[recv_timeout: 60_000, connect_timeout: 60_000], []) do
      {:ok,{{_,200,_},_,res}}->
          Poison.decode!(res) |> clean_prices(actif)
      end
  end

  def clean_prices(prices, actif) do
      prices["candles"] |>
      Enum.filter(& &1["complete"]) |> Enum.map(fn p ->
          %{
              time: p["time"] |> Integer.parse |> elem(0),
              open: p["mid"]["o"] |> Float.parse |> elem(0),
              close: p["mid"]["c"] |> Float.parse |> elem(0),
              high: p["mid"]["h"] |> Float.parse |> elem(0),
              low: p["mid"]["l"] |> Float.parse |> elem(0),
              spread: abs((p["ask"]["c"] |> Float.parse |> elem(0)) - (p["bid"]["c"] |> Float.parse |> elem(0)))/@position_pip[actif]
          }
      end)
  end

  def still_pending(paire) do
      url= 'https://api-fxpractice.oanda.com/v3/accounts/#{account_id()}/orders?instrument=#{paire}'
      {:ok,{{_,200,_},_,res}} = :httpc.request(:get,{url, main_header()},[recv_timeout: 300_000, connect_timeout: 300_000], [])
      res = Poison.decode!(res)["orders"]
      Enum.member?(res, fn e -> e["state"] == "PENDING" end)
  end

  def get_capital() do
      url = 'https://api-fxpractice.oanda.com/v3/accounts/#{account_id()}'
      {:ok,{{_,200,_},_,res}} = :httpc.request(:get,{url, main_header()},[recv_timeout: 300_000, connect_timeout: 300_000], [])
      Poison.decode!(res)["account"]["balance"] |> Float.parse |> elem(0)
  end

  #For compatibility with backtest version
  # def create_order(commande, _, _, paire), do: create_order(commande, paire)
  # def create_order(commande, paire) do
  #     url = 'https://api-fxpractice.oanda.com/v3/accounts/#{account_id()}/orders'
  #     commande = '#{Poison.encode!(commande)}'
  #     {:ok,{{_,code,_},_,res}} = :httpc.request(:post,{url, main_header(), 'application/json', commande},[recv_timeout: 300_000, connect_timeout: 300_000], [])
  #     Logger.debug("#{commande}")
  #     if code < 200 or code >=300 do
  #         Slack.Communcation.send_message("#debug", "Something strange happened while passing an order : got code #{code}. You may find the reason here : #{res}")
  #     else
  #         Slack.Communcation.send_message("#debug", "Nouvel ordre passe sur #{paire}")
  #     end
  # end

  def get_current_positions() do

      # requesting orders and positions
      url = 'https://api-fxpractice.oanda.com/v3/accounts/#{account_id()}/pendingOrders'
      {:ok,{{_,200,_},_,res}} = :httpc.request(:get,{url, main_header()},[recv_timeout: 300_000, connect_timeout: 300_000], [])
      orders = res |> Poison.decode! |> get_in(["orders"])
      url = 'https://api-fxpractice.oanda.com/v3/accounts/#{account_id()}/openPositions'
      {:ok,{{_,200,_},_,res}} = :httpc.request(:get,{url, main_header()},[recv_timeout: 300_000, connect_timeout: 300_000], [])

      # processing
      res |> Poison.decode! |> get_in(["positions"]) |> Enum.map(fn p->
          trade_id = p["long"]["tradeIDs"] || p["short"]["tradeIDs"]
          open_price = p["long"]["averagePrice"] || p["short"]["averagePrice"]
          sens = p["long"]["tradeIDs"] && :buy || :sell
          trade_id |> Enum.map(fn t_id ->
              order_sl = orders |> Enum.filter(& &1["tradeID"] == t_id && &1["type"] == "STOP_LOSS") |> hd
              # order_tp = orders |> Enum.filter(& &1["tradeID"] == t_id && &1["type"] == "TAKE_PROFIT") |> hd
              Logger.debug("#{inspect order_sl}")
              %{
                  paire: p["instrument"],
                  sl: order_sl["price"] |> Float.parse |> elem(0),
                  # tp: order_tp["price"] |> Float.parse |> elem(0),
                  open_price: open_price |> Float.parse |> elem(0),
                  sl_tid: order_sl["id"],
                  sens: sens
              }
          end)
      end) |> List.flatten
  end

  def change_sl_lvl(sl_tid, new_price) do

      url = 'https://api-fxpractice.oanda.com/v3/accounts/#{account_id()}/orders/#{sl_tid}'
      {:ok,{{_,200,_},_,res}} = :httpc.request(:get,{url, main_header()},[recv_timeout: 300_000, connect_timeout: 300_000], [])
      order = res |> Poison.decode! |> get_in(["order"])

      commande = %{
          "order" => put_in(order, ["price"], "#{new_price}")
      }
      commande = '#{Poison.encode!(commande)}'
      {:ok,{{_,code,_},_,res}} = :httpc.request(:put, {url, main_header(), 'application/json', commande}, [recv_timeout: 300_000, connect_timeout: 300_000], [])
      :ok
  end

end

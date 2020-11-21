defmodule Backtest do

  require Logger
  @spread_max Application.get_env(:sansa, :trading)[:spread_max]
  @increment %{
    "H1"  => 17452800,
    "M15" => 4363200
  }
  @parallelization %{
    "H1"  => 7,
    "M15" => 3
  }

  def getting_prices(p, ut \\ "H1", scope \\ :small) do
    Logger.info("Getting prices for #{ut} - #{p}")
    ts_start = 1483230033
    final_ts   = 1577838033
    ts_increment = @increment[ut]
    ts_array = Stream.iterate(ts_start, & Enum.min([(&1 + ts_increment), final_ts]))
    |> Enum.take_while(& &1 != final_ts)
    # (scope == :full && [1483296272, 1496342672] || []) ++
    prices = Enum.chunk_every(ts_array, 2, 1, :discard) |> Enum.map(fn [a, b] -> [a+1, b] end) |> Enum.map(fn [a, b] -> Oanda.Interface.get_prices(ut, p, 0, %{ts_from: a, ts_to: b}) end) |> List.flatten |> Enum.uniq |> Enum.sort(& &1[:time] <= &2[:time])
    |> Sansa.TradingUtils.atr
    # |> Sansa.TradingUtils.rsi
    # |> Sansa.TradingUtils.ichimoku
    |> Sansa.TradingUtils.kst
    |> Sansa.TradingUtils.macd
    |> Sansa.TradingUtils.ema(100, :close, :trend_50)
    |> Sansa.TradingUtils.ema(100, :close, :long_trend_100)
    |> Sansa.TradingUtils.ema(200, :close, :long_trend_200)
    |> Sansa.TradingUtils.ema(9, :close, :ema_9)
    |> Sansa.TradingUtils.ema(20, :close, :ema_20)
    Logger.info("Prices gotten for #{ut} - #{p}")
    prices
  end

  def get_spread(price, paire), do: (price.spread)*Sansa.TradingUtils.pip_position(paire)

  def run_full_backtest(name \\ "") do
    name = if name != "", do: " #{name}", else: name
    Slack.Communcation.send_message("#backtest", "==== :vertical_traffic_light: New Backtest#{name} ! :vertical_traffic_light: ====")
    Application.get_env(:sansa, :trading)[:paires] |> Enum.each(& Backtest.scan_backtest(&1))
    Slack.Communcation.send_message("#backtest", "==== :trident: Backtest#{name} ended :trident: ====")
  end

  def scan_backtest(paire) do
    rrp = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2, 3]
    strat = [:kst_strat]#, :macd_strat, :ss_ema, :ema_cross, :ich_cross]
    stop = [:regular_atr, :tight_atr, :very_tight, :large_atr]
    ut_list = ["H1"]
    scanning = for x <- rrp, y <- strat, z <- stop, do: [x, y, z]
    results =  Enum.map(ut_list, fn u ->
      cache = getting_prices(paire, u, :full)
      scanning |> Task.async_stream(fn [x, y, z] ->
        backtest_report(paire, y, z, x, u, cache)
      end, max_concurrency: @parallelization[u], timeout: :infinity) |> Enum.map(fn {:ok, res} -> res end)
    end) |> List.flatten

    File.write!("data/backtest_scan_#{paire}.json", Poison.encode!(results))

    report = Enum.map(ut_list, fn u->
      ":tada: --- ut : #{u} ---\n" <> (results |> Enum.filter(& &1.ut == u) |> Enum.sort(& &1.gain >= &2.gain) |> Enum.take(3) |> Enum.map(fn st ->
        "#{st.position_strat} with a win rate of #{st.win_rate}% and a gain of #{st.gain} % on #{st.nb_trades} trades (rrp : #{st.rrp}, stop: #{st.stop_strat} -- %/trades : #{(st.gain/st.nb_trades) |> Float.round(2)}"
      end) |> Enum.join("\n"))
    end) |> Enum.join("\n\n")
    Slack.Communcation.send_message("#backtest", "Backtest of #{paire} is over. Time for results!", %{attachments: report})
  end

  def analyse_over_pairs() do
    result = Application.get_env(:sansa, :trading)[:paires] |>
    Enum.map(fn p ->
      if File.exists?("data/backtest_scan_#{p}.json") do
        File.read!("data/backtest_scan_#{p}.json") |> Poison.decode!(keys: :atoms)
        |> Enum.map(& put_in(&1, [:paire], p))
        |> Enum.map(& put_in(&1, [:eur_p_trade], &1.gain / &1.nb_trades))
      else [] end
    end) |> List.flatten |> Enum.sort(& (&1.gain / &1.nb_trades) > (&2.gain / &2.nb_trades)) |> Enum.take(40)
    File.write!("data/final_result", Poison.encode!(result, pretty: true))
  end

  def is_valid_period?(ts) do
    !(ts >= 1583709881 && ts <= 1588285481)
  end

  def backtest_report(p, position_strat, stop_strat, rrp \\ 1.5, ut \\ "H1", cache \\ nil) do
    prices = cache || getting_prices(p, :small)
    depth = 300
    init_capital = 1000
    risk = 10
    win = risk * rrp
    report = Enum.chunk_every(prices, depth, 1, :discard) |> Enum.reduce(%{
      state: :not_trading,
      trading_info: nil,
      capital: init_capital,
      result: []
    }, fn new_prices, report ->
      current_price = new_prices |> Enum.reverse |> hd

      report = case report.state do

        :not_trading   -> report

        :long_position -> # Currently in a long_position
          cond do
            current_price.low <= report.trading_info.sl ->
              # Logger.info("New loss")
              %{
                state: :not_trading,
                trading_info: nil,
                capital: report.capital - risk,
                result: report.result ++ [%{close: current_price, outcome: :loss, open: report.trading_info}]
              }
              current_price.high >= report.trading_info.tp ->
                # Logger.info("New win")
              %{
                state: :not_trading,
                trading_info: nil,
                capital: report.capital + win,
                result: report.result ++ [%{close: current_price, outcome: :win, open: report.trading_info}]
              }
            true -> report
          end

        :short_position -> # Currently in a short_position
        cond do
          current_price.high >= report.trading_info.sl ->
            # Logger.info("New loss")
            %{
              state: :not_trading,
              trading_info: nil,
              capital: report.capital - risk,
              result: report.result ++ [%{close: current_price, outcome: :loss, open: report.trading_info}]
            }
          current_price.low <= report.trading_info.tp ->
            # Logger.info("New win")
            %{
              state: :not_trading,
              trading_info: nil,
              capital: report.capital + win,
              result: report.result ++ [%{close: current_price, outcome: :win, open: report.trading_info}]
            }
          true -> report
        end
      end
      if report.state == :not_trading && @spread_max[p] >= hd(Enum.reverse(new_prices))[:spread] && is_valid_period?(hd(Enum.reverse(new_prices))[:time]) do
        r = evaluate_strategy(position_strat, report, new_prices, rrp, stop_strat)
        case r.state do
          :long_position ->
            put_in(r, [:trading_info, :sl], r.trading_info.sl + (get_spread(hd(Enum.reverse(new_prices)), p))/2) |>
            put_in([:trading_info, :tp], r.trading_info.tp + (get_spread(hd(Enum.reverse(new_prices)), p))/2)
          :short_position ->
            put_in(r, [:trading_info, :sl], r.trading_info.sl - (get_spread(hd(Enum.reverse(new_prices)), p))/2) |>
            put_in([:trading_info, :tp], r.trading_info.tp - (get_spread(hd(Enum.reverse(new_prices)), p))/2)
          _ -> r
        end
      else report end
    end)
    win_rate = ((Enum.count(report.result, & &1.outcome == :win) / Enum.count(report.result)) * 100) |> Float.round
    nb_trades = Enum.count(report.result)
    final_gain = (((report.capital - init_capital)/init_capital)*100) |> Float.round(2)
    Logger.info("End of the backtest. We have a win rate of about #{win_rate} % with #{nb_trades} trades and a result of #{final_gain} %")
    %{win_rate: win_rate, nb_trades: nb_trades, gain: final_gain, rrp: rrp, stop_strat: stop_strat, position_strat: position_strat, ut: ut}
  end

  def evaluate_strategy(:macd_strat, report, new_prices, rrp, stop_strat) do
    current_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)

    cond do
      current_price.macd_histo >= 0 && price_before.macd_histo <= 0 && current_price.close > current_price.long_trend_200 && current_price.macd_value < 0 ->
        sl = stop_placement(stop_strat, new_prices, :buy)
        tp = current_price.close + rrp * abs(current_price.close - sl)
        Logger.warn("New long position")
        %{
          state: :long_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      current_price.macd_histo <= 0 && price_before.macd_histo >= 0 && current_price.close < current_price.long_trend_200 && current_price.macd_value > 0 ->
        sl = stop_placement(stop_strat, new_prices, :sell)
        tp = current_price.close - rrp * abs(current_price.close - sl)
        Logger.warn("New short position")
        %{
          state: :short_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      true ->
        report
    end
  end

  def evaluate_strategy(:kst_strat, report, new_prices, rrp, stop_strat) do
    current_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)

    cond do
      current_price.kst_sig < current_price.kst && price_before.kst_sig > price_before.kst && current_price.trend_50 > current_price.long_trend_200 && current_price.kst < 0 ->
        sl = stop_placement(stop_strat, new_prices, :buy)
        tp = current_price.close + rrp * abs(current_price.close - sl)
        Logger.warn("New long position")
        %{
          state: :long_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      current_price.kst_sig > current_price.kst && price_before.kst_sig < price_before.kst && current_price.trend_50 < current_price.long_trend_200 && current_price.kst > 0 ->
        sl = stop_placement(stop_strat, new_prices, :sell)
        tp = current_price.close - rrp * abs(current_price.close - sl)
        Logger.warn("New short position")
        %{
          state: :short_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      true ->
        report
    end
  end

  def evaluate_strategy(:ema_cross, report, new_prices, rrp, stop_strat) do
    current_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)
    corps_candle = abs(current_price.close - current_price.open)

    cond do
      current_price.ema_9 >= current_price.ema_20 && price_before.ema_9 < price_before.ema_20 && current_price.close > current_price.long_trend_200 && current_price.low > current_price.ema_20 && corps_candle < 2*current_price.atr ->
        sl = stop_placement(stop_strat, new_prices, :buy)
        tp = current_price.close + rrp * abs(current_price.close - sl)
        Logger.warn("New long position")
        %{
          state: :long_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      current_price.ema_9 <= current_price.ema_20 && price_before.ema_9 > price_before.ema_20 && current_price.close < current_price.long_trend_200 && current_price.high < current_price.ema_20 && corps_candle < 2*current_price.atr->
        sl = stop_placement(stop_strat, new_prices, :sell)
        tp = current_price.close - rrp * abs(current_price.close - sl)
        Logger.warn("New short position")
        %{
          state: :short_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      true ->
        report
    end
  end

  def evaluate_strategy(:adx_cross, report, new_prices, rrp, stop_strat) do
    current_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)
    corps_candle = abs(current_price.close - current_price.open)

    cond do
      current_price.ema_9 >= current_price.ema_20 && price_before.ema_9 < price_before.ema_20 && current_price.close > current_price.long_trend_200 && current_price.low > current_price.ema_20 && corps_candle < 2*current_price.atr ->
        sl = stop_placement(stop_strat, new_prices, :buy)
        tp = current_price.close + rrp * abs(current_price.close - sl)
        Logger.warn("New long position")
        %{
          state: :long_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      current_price.ema_9 <= current_price.ema_20 && price_before.ema_9 > price_before.ema_20 && current_price.close < current_price.long_trend_200 && current_price.high < current_price.ema_20 && corps_candle < 2*current_price.atr->
        sl = stop_placement(stop_strat, new_prices, :sell)
        tp = current_price.close - rrp * abs(current_price.close - sl)
        Logger.warn("New short position")
        %{
          state: :short_position,
          trading_info: %{sl: sl, tp: tp , open: current_price},
          capital: report.capital,
          result: report.result
        }
      true ->
        report
    end
  end

  def evaluate_strategy(:ss_ema, report, new_prices, rrp, stop_strat) do
    last_price = new_prices |> Enum.reverse |> hd
    whole_candle = last_price[:high] - last_price[:low]
    min_o_c = Enum.min([last_price[:close], last_price[:open]])
    max_o_c = Enum.max([last_price[:close], last_price[:open]])
    bot_wick = abs(min_o_c - last_price[:low])
    top_wick = abs(max_o_c - last_price[:high])

    cond do
      bot_wick >= 0.666*whole_candle       &&
      whole_candle >= 0.5*last_price[:atr] &&
      whole_candle < 2.5 * last_price[:atr]  &&
      last_price.low <= last_price.long_trend_100 &&
      last_price.close > last_price.long_trend_100 &&
      last_price.rsi < 50 ->
        sl = stop_placement(stop_strat, new_prices, :buy)
        tp = last_price.close + rrp * abs(last_price.close - sl)
        Logger.warn("New long position")
        %{
          state: :long_position,
          trading_info: %{sl: sl, tp: tp , open: last_price},
          capital: report.capital,
          result: report.result
        }
      top_wick >= 0.666 * whole_candle       &&
      whole_candle >= 0.5 * last_price[:atr] &&
      whole_candle < 2.5 * last_price[:atr] &&
      last_price.high >= last_price.long_trend_100 &&
      last_price.close < last_price.long_trend_100 &&
      last_price.rsi > 50 ->
        sl = stop_placement(stop_strat, new_prices, :sell)
        tp = last_price.close - rrp * abs(last_price.close - sl)
        Logger.warn("New short position")
        %{
          state: :short_position,
          trading_info: %{sl: sl, tp: tp , open: last_price},
          capital: report.capital,
          result: report.result
        }
      true ->
        report
    end
  end

  def evaluate_strategy(:ich_cross, report, new_prices, rrp, stop_strat) do
    last_price = new_prices |> Enum.reverse |> hd
    price_before = new_prices |> Enum.reverse |> Enum.at(1)

    cond do
      last_price.close > last_price.ssa && last_price.close > last_price.ssb &&
      price_before.tk < price_before.kj && last_price.tk > last_price.kj ->
        sl = stop_placement(stop_strat, new_prices, :buy)
        tp = last_price.close + rrp * abs(last_price.close - sl)
        Logger.warn("New long position")
        %{
          state: :long_position,
          trading_info: %{sl: sl, tp: tp , open: last_price},
          capital: report.capital,
          result: report.result
        }
      last_price.close < last_price.ssa && last_price.close < last_price.ssb &&
      price_before.tk > price_before.kj && last_price.tk < last_price.kj ->
        sl = stop_placement(stop_strat, new_prices, :sell)
        tp = last_price.close - rrp * abs(last_price.close - sl)
        Logger.warn("New short position")
        %{
          state: :short_position,
          trading_info: %{sl: sl, tp: tp , open: last_price},
          capital: report.capital,
          result: report.result
        }
      true ->
        report
    end
  end

  def stop_placement(:regular_atr, prices, sens) do
    last_price = prices |> Enum.reverse |> hd
    if sens == :buy do
      last_price.close - last_price.atr * 2
    else
      last_price.close + last_price.atr * 2
    end
  end

  def stop_placement(:tight_atr, prices, sens) do
    last_price = prices |> Enum.reverse |> hd
    if sens == :buy do
      last_price.close - last_price.atr * 1.5
    else
      last_price.close + last_price.atr * 1.5
    end
  end

  def stop_placement(:very_tight, prices, sens) do
    last_price = prices |> Enum.reverse |> hd
    if sens == :buy do
      last_price.close - last_price.atr
    else
      last_price.close + last_price.atr
    end
  end

  def stop_placement(:large_atr, prices, sens) do
    last_price = prices |> Enum.reverse |> hd
    if sens == :buy do
      last_price.close - last_price.atr * 2.5
    else
      last_price.close + last_price.atr * 2.5
    end
  end

end

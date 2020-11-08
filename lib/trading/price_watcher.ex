defmodule Sansa.Price.Watcher do
  use GenServer
  require Logger

  @ut "H1"
  @paires Application.get_env(:sansa, :trading)[:paires]
  @spread_max Application.get_env(:sansa, :trading)[:spread_max]
  @pattern_activated [:shooting_star, :engulfing]
  @orders_activated true

  def start_link(_) do
      GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
      Logger.info("Demarrage du price watcher")
      Process.send_after(self(), :tick, next_tick() |> next_pull_ms())
      {:ok, []}
  end

  def run() do
      Process.send(Sansa.Price.Watcher, :tick, [])
  end

  def next_pull_ms({h, m}) do
      now = Timex.now("Europe/Paris")
      now_m = now.hour * 60 + now.minute
      t = h * 60 + m
      diff = t - now_m
      if diff > 0 do
        diff * 60 * 1000
      else
        (24 * 60 + diff) * 60 * 1000
      end
    end

  def next_tick() do
      now = Timex.now("Europe/Paris")
      hour = if now.hour == 23, do: 0, else: now.hour + 1
      {hour, 0}
  end

  def is_pull_authorized() do
      Date.day_of_week(Timex.today) != 7 &&
      Date.day_of_week(Timex.today) != 6 &&
      !(Date.day_of_week(Timex.today) == 5 && Timex.now("Europe/Paris").hour >= 18)
  end

  def test_loop(p, ts) do
    v = Oanda.Interface.get_prices(@ut, p, 100, %{ts_to: ts}) |> Sansa.TradingUtils.atr
    if @spread_max[p] <= hd(Enum.reverse(v))[:spread] && false do
      Logger.info("Spread too high")
    else
      action = @pattern_activated |> Enum.map(& {&1, Sansa.Patterns.run_pattern_detection(&1, v, Sansa.ZonePuller.get_zones(p))})
      |> Enum.reduce_while(:no_trade, fn a, acc ->
        case a do
          {pat, {:ok, zone, sens}} ->
            Slack.Communcation.send_message("#suivi", "New #{to_string sens} on #{to_string pat} pattern on zone on #{p}")
            Logger.info("New #{to_string sens} on #{to_string pat} pattern on zone on #{p}")
            cond do
              !@orders_activated                -> Logger.warn("Order passing disabled")
                                                    {:cont, acc}
              zone[:locked]                     -> Logger.warn("Zone is locked")
                                                    {:cont, acc}
              zone[:one_shot] && !zone[:locked] -> Logger.warn("One shot zone")
                                                    case Sansa.Orders.new_order(p, v, sens) do
                                                      :error -> Loger.error("Zone not locked because of bad order")
                                                              {:cont, acc}
                                                      :ok    -> Sansa.ZonePuller.lock_zone(p, zone)
                                                              {:halt, :ok}
                                                    end
              true -> case Sansa.Orders.new_order(p, v, sens) do
                :error -> Loger.error("Bad order")
                          {:cont, acc}
                :ok    -> {:halt, :ok}
              end
            end
          _ -> {:cont, acc}
        end
      end)
      if action == :no_trade do
        Logger.info("No entry reason :(")
      end
    end
  end

  ## main loop
  def handle_info(:tick, _s) do
      Logger.info("New price check!")
      if is_pull_authorized() do
          @paires |> Enum.shuffle |> Enum.map(&
          {
            &1,
            Oanda.Interface.get_prices(@ut, &1, 100) |> Sansa.TradingUtils.atr
          }) |> Enum.each(fn {p, v} ->
            if @spread_max[p] <= hd(Enum.reverse(v))[:spread] && false do
                Slack.Communcation.send_message("#suivi", "Spread too damn high for #{p}")
                Logger.info("Spread too high")
            else
              action = @pattern_activated |> Enum.map(& {&1, Sansa.Patterns.run_pattern_detection(&1, v, Sansa.ZonePuller.get_zones(p))})
              |> Enum.reduce_while(:no_trade, fn a, acc ->
                case a do
                  {pat, {:ok, zone, sens}} ->
                    Slack.Communcation.send_message("#suivi", "New #{to_string sens} on #{to_string pat} pattern on zone on #{p}")
                    Logger.info("New #{to_string sens} on #{to_string pat} pattern on zone on #{p}")
                    cond do
                      !@orders_activated                -> Logger.warn("Order passing disabled")
                                                           {:cont, acc}
                      zone[:locked]                     -> Logger.warn("Zone is locked")
                                                           {:cont, acc}
                      zone[:one_shot] && !zone[:locked] -> Logger.warn("One shot zone")
                                                           case Sansa.Orders.new_order(p, v, sens) do
                                                             :error -> Loger.error("Zone not locked because of bad order")
                                                                      {:cont, acc}
                                                             :ok    -> Sansa.ZonePuller.lock_zone(p, zone)
                                                                      {:halt, :ok}
                                                           end
                      true -> case Sansa.Orders.new_order(p, v, sens) do
                        :error -> Loger.error("Bad order")
                                 {:cont, acc}
                        :ok    -> {:halt, :ok}
                      end
                    end
                  _ -> {:cont, acc}
                end
              end)
              if action == :no_trade do
                Logger.info("No entry reason :(")
              end
            end
          end)
      else
          Logger.debug("Pull not available")
      end

      Process.send_after(self(), :tick, next_tick() |> next_pull_ms())
      {:noreply, []}
  end

end

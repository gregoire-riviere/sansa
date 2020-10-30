defmodule Sansa.Price.Watcher do
  use GenServer
  require Logger

  @ut "H1"
  @paires Application.get_env(:sansa, :trading)[:paires]
  @spread_max Application.get_env(:sansa, :trading)[:spread_max]

  def start_link(opts) do
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
      Date.day_of_week(Timex.today) != 7
  end

  ## main loop
  def handle_info(:tick, _s) do
      Logger.info("New price check!")
      if is_pull_authorized() do
          @paires |> Enum.map(&
          {
            &1,
            Oanda.Interface.get_prices(@ut, &1, 100) |> Sansa.TradingUtils.atr
          }) |> Enum.each(fn {p, v} ->
            cond do
              @spread_max[p] <= hd(Enum.reverse(v))[:spread] ->
                Slack.Communcation.send_message("#suivi", "Spread too damn high for #{p}")
                Logger.info("Spread too high")
              Sansa.Patterns.check_pattern(:shooting_star, v, Sansa.ZonePuller.get_zones(p)) ->
                Slack.Communcation.send_message("#suivi", "New shooting star on zone on #{p}")
                Logger.info("Waou! A shooting star")
              Sansa.Patterns.check_pattern(:engulfing, v, Sansa.ZonePuller.get_zones(p)) ->
                Slack.Communcation.send_message("#suivi", "New engulfing star on zone on #{p}")
                Logger.info("Waou! An engulfing pattern")
              true ->
                Slack.Communcation.send_message("#suivi", "No entry reason on #{p}")
                Logger.info("No entry reason :(")
            end
          end)
      else
          Logger.debug("Pull not available")
      end

      Process.send_after(self(), :tick, next_tick() |> next_pull_ms())
      {:noreply, []}
  end

end

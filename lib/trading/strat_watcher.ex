defmodule Sansa.Strat.Watcher do
  use GenServer
  require Logger

  @ut "H1"
  @paires Application.get_env(:sansa, :trading)[:paires]
  @spread_max Application.get_env(:sansa, :trading)[:spread_max]
  @strats Application.get_env(:sansa, :trading)[:strats]
  @test_mode false

  def start_link(_) do
      GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
      Logger.info("Demarrage du price watcher")
      Process.send_after(self(), :tick, next_tick() |> next_pull_ms())
      {:ok, []}
  end

  def run() do
      Process.send(Sansa.Strat.Watcher, :tick, [])
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
      @test_mode ||
      (Date.day_of_week(Timex.today) != 7 &&
      Date.day_of_week(Timex.today) != 6 &&
      !(Date.day_of_week(Timex.today) == 5 && Timex.now("Europe/Paris").hour >= 18))
  end


  ## main loop
  def handle_info(:tick, _s) do
    Logger.info("New price check!")
    if is_pull_authorized() do
        @strats |> Enum.shuffle |> Enum.map(&
        {
          &1,
          Oanda.Interface.get_prices(@ut, elem(&1, 1), 250) |> Sansa.TradingUtils.atr
        }) |> Enum.each(fn {{spec, p}, v} ->
          if @spread_max[p] <= hd(Enum.reverse(v))[:spread] do
            Slack.Communcation.send_message("#suivi", "Spread too damn high for #{p}")
            Logger.info("Spread too high")
          else
            case Sansa.Strat.run_strat(spec.name, p, v, spec.rrp, spec.stop_placement) do
              :long_position ->
                Slack.Communcation.send_message("#suivi", "New long trade on #{p}")
              :short_position ->
                Slack.Communcation.send_message("#suivi", "New short trade on #{p}")
              _ -> Logger.debug("No entry reason on #{p}!")
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

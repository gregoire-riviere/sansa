defmodule Sansa.Strat.Watcher do
  use GenServer
  require Logger

  @ut "H1"
  @paires Application.get_env(:sansa, :trading)[:paires]
  @spread_max Application.get_env(:sansa, :trading)[:spread_max]
  @strats Application.get_env(:sansa, :trading)[:strats]
  @test_mode false

  def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: opts.name)
  end

  def init(opts) do
      Logger.info("Demarrage du price watcher #{opts.ut}")
      Process.send_after(self(), :tick, next_tick(opts.ut) |> next_pull_ms())
      Logger.debug("Next pull in #{next_tick(opts.ut) |> next_pull_ms()} ms!")
      {:ok, opts}
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

  def next_tick(ut) do
      h = Timex.now("Europe/Paris").hour
      m = Timex.now("Europe/Paris").minute
      case ut do
        "H1"  ->
          hour = if h == 23, do: 0, else: h + 1
          {hour, 0}
        "M15" ->
          cond do
            m < 15 -> {h, 15}
            m < 30 -> {h, 30}
            m < 45 -> {h, 45}
            true   ->
              hour = if h == 23, do: 0, else: h + 1
              {hour, 0}
          end
      end
  end

  def is_pull_authorized() do
      @test_mode ||
      (Date.day_of_week(Timex.today) != 7 &&
      Date.day_of_week(Timex.today) != 6 &&
      !(Date.day_of_week(Timex.today) == 5 && Timex.now("Europe/Paris").hour >= 18))
  end


  ## main loop
  def handle_info(:tick, opts) do
    Logger.info("New price check!")
    if is_pull_authorized() do
        @strats[opts.ut] |> Enum.shuffle |> Enum.map(&
        {
          &1,
          Oanda.Interface.get_prices(@ut, elem(&1, 1), 250) |> Sansa.TradingUtils.atr
        }) |> Enum.each(fn {{spec, p}, v} ->
          if @spread_max[p] <= (hd(Enum.reverse(v))[:spread] * Sansa.TradingUtils.pip_position(p)) do
            Slack.Communcation.send_message("#suivi", "Spread too damn high for #{p}")
            Logger.warn("Spread too high")
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

    Process.send_after(self(), :tick, next_tick(opts.ut) |> next_pull_ms())
    {:noreply, opts}
  end
end

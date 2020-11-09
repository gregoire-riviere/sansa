defmodule Sansa.ZonePuller do
  use GenServer
  require Logger
  @file_path "test.json"
  @refresh_period 120_000
  @zone_alert_period 60_000 * 120

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting zones service")
    s = refresh_zones()
    Process.send_after(self(), :refresh_zones, @refresh_period)
    Process.send_after(self(), :alert_locked_zone, @zone_alert_period)
    {:ok, s}
  end

  def handle_info(:refresh_zones, state) do
    Logger.info("Refreshing zones")
    new_tbl = refresh_zones()
    Process.send_after(self(), :refresh_zones, @refresh_period)
    {:noreply, new_tbl}
  end

  def refresh_zones() do
    if File.exists?(@file_path) do
      File.read!(@file_path) |>
        Poison.decode!(keys: :atoms) |>
        Enum.map(fn {k, v} -> {to_string(k), v} end) |> Enum.into(%{})
    else %{} end
  end

  def get_zones(p), do: GenServer.call(Sansa.ZonePuller, {:get_zones, p})
  def handle_call({:get_zones, p}, _from, state) do
    res = case state[p] do
      nil ->
        Logger.debug("No zones found")
        []
      o -> o
    end
    {:reply, res, state}
  end

  def lock_zone(p, zone), do: GenServer.cast(Sansa.ZonePuller, {:lock_zone, p, zone})
  def handle_cast({:lock_zone, p, zone}, state) do
    content = File.read!(@file_path) |> Poison.decode!
    paire_zones = if content[p], do: content[p], else: nil
    content = if paire_zones do
      content |> put_in([p],
        paire_zones |> Enum.map(& if &1["h"] == zone.h && &1["l"] == zone.l, do: put_in(&1, [:locked], true), else: &1)
      )
    else content end
    File.write!(@file_path, Poison.encode!(content, pretty: true))
    s = refresh_zones()
    {:noreply, s}
  end

  def alert_lock_zone(), do: Process.send(Sansa.ZonePuller, :alert_locked_zone, [])
  def handle_info(:alert_locked_zone, state) do
    Logger.info("Searching locked zones")
    zones_locked = Enum.map(state, fn {paire, zones} ->
      {paire, Enum.filter(zones, & &1[:locked])}
    end) |> Enum.reject(fn {k, v} -> Enum.count(v) == 0 end)
    |> Enum.map(fn {k, v} -> "#{Enum.count(v)} zone(s) for #{k}" end)
    |> Enum.join("\n")
    Slack.Communcation.send_message("#alert_lock", "Zones locked", zones_locked)
    Process.send_after(self(), :alert_locked_zone, @zone_alert_period)
    {:noreply, state}
  end

end

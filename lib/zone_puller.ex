defmodule Sansa.ZonePuller do
  use GenServer
  require Logger
  @file_path "test.json"
  @refresh_period 120_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting zones service")
    s = refresh_zones()
    Process.send_after(self(), :refresh_zones, @refresh_period)
    {:ok, s}
  end

  def handle_info(:refresh_zones, state) do
    Logger.info("Refreshing zones")
    new_tbl = refresh_zones(state)
    Process.send_after(self(), :refresh_zones, @refresh_period)
    {:noreply, new_tbl}
  end
  def refresh_zones(), do: refresh_zones(nil)
  def refresh_zones(tbl) do
    tbl != nil && :ets.delete(tbl)
    new_tbl = :ets.new(:zones, [])
    if File.exists?(@file_path) do
      File.read!(@file_path) |>
        Poison.decode!(keys: :atoms) |>
        Enum.each(fn {k, v} -> :ets.insert(new_tbl, {to_string(k), v}) end)
    end
    new_tbl
  end

  def get_zones(p), do: GenServer.call(Sansa.ZonePuller, {:get_zones, p})
  def handle_call({:get_zones, p}, _from, state) do
    res = case :ets.lookup(state, p) do
      [] -> []
      [{_, v}] -> v
      [{_, v}|_] -> v
      _ -> []
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
    File.write!(@file_path, Poison.encode!(content))
    s = refresh_zones(state)
    {:noreply, s}
  end

end

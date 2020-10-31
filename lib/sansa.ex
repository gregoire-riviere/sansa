defmodule Sansa do
  use Application

  def start(_type, _args) do
    children = [
      {Sansa.ZonePuller, []},
      {Sansa.Price.Watcher, []},
      {Sansa.Orders, []}
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end

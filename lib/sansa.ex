defmodule Sansa do
  use Application

  def start(_type, _args) do
    children = [
      # {Sansa.ZonePuller, []},
      Supervisor.child_spec({Sansa.Strat.Watcher, %{name: :strat_h1, ut: "H1"}}, id: :strat_h1),
      Supervisor.child_spec({Sansa.Strat.Watcher, %{name: :strat_m15, ut: "M15"}}, id: :strat_m15),
      {Sansa.Orders, []}
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end

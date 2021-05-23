defmodule Sansa.Orders do
  use GenServer
  require Logger

  @atr_stop_ratio 2
  @max_number_position 5
  @rrp Application.get_env(:sansa, :trading)[:rrp]
  @risque Application.get_env(:sansa, :trading)[:risque]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting orders service")
    {:ok, nil}
  end

  def compute_risk_for_pip(paire, sl_position, sl_distance, max_risk_eur) do
    pip_factor = Sansa.TradingUtils.pip_position(paire)
    [frst, scnd] = String.split(paire, "_")
    conversion_factor = case frst do
      "EUR" -> 1
      other -> Oanda.Interface.get_prices("H1", "EUR_#{other}", 100) |> hd |> get_in([:close])
    end
    (((max_risk_eur/sl_distance)*sl_position)/pip_factor)*conversion_factor
  end

  def new_order(paire, prices, sens, rrp \\ @rrp, stop_placement \\ :regular_atr), do: GenServer.call(Sansa.Orders, {:new_order, paire, prices, sens, rrp, stop_placement})
  def handle_call({:new_order, paire, prices, sens, rrp, stop_placement}, _from, _) do
    cond do
      Oanda.Interface.still_pending(paire) ->
        Slack.Communcation.send_message("#debug", "Ordre toujours en cours pour #{paire}")
        {:reply, :error, nil}
      length(Oanda.Interface.get_current_positions()) >= @max_number_position ->
        Slack.Communcation.send_message("#debug", "Trop de positions ouvertes pour le moment")
        {:reply, :error, nil}
      true ->
        current = Enum.reverse(prices) |> hd
        nb_digits = current.close |> Float.to_string |> String.split(".") |> Enum.at(1) |> byte_size

        #sl and tp position
        stop_position = Sansa.Stop.place_stop(stop_placement, prices, sens)
        stop_distance = abs(current.close - stop_position)
        tp_distance = stop_distance * rrp
        tp_position = if sens == :buy, do: current.close + tp_distance, else: current.close - tp_distance

        #Volume computation
        risque_max_euros = Float.round(@risque * Oanda.Interface.get_capital(), 2)
        stop_pip = stop_distance / Sansa.TradingUtils.pip_position(paire)
        volume = trunc(Float.round(compute_risk_for_pip(paire, stop_position, stop_pip, risque_max_euros)))
        volume = if sens == :buy, do: volume, else: -volume

        commande = %{
            "order"=> %{
                "units"=> "#{volume}",
                "instrument"=> paire,
                "timeInForce"=> "FOK",
                "type"=> "MARKET",
                "positionFill"=> "DEFAULT",
                "stopLossOnFill"=> %{
                    "price"=> "#{Float.round(stop_position, nb_digits)}"
                },
                "takeProfitOnFill"=> %{
                    "price"=> "#{Float.round(tp_position, nb_digits)}"
                }
            }
        }
        Logger.info("Ordre passe : #{inspect commande}")
        Slack.Communcation.send_message("#orders_passed", "Nouvel order pour #{paire} : #{inspect commande}")
        {:reply, Oanda.Interface.create_order(commande, current, sens, paire), nil}
    end
  end

end


defmodule Sansa.Stop do

  def place_stop(:regular_atr, prices, sens) do
    last_price = prices |> Enum.reverse |> hd
    if sens == :buy do
      last_price.close - last_price.atr * 2
    else
      last_price.close + last_price.atr * 2
    end
  end

  def place_stop(:tight_atr, prices, sens) do
    last_price = prices |> Enum.reverse |> hd
    if sens == :buy do
      last_price.close - last_price.atr * 1.5
    else
      last_price.close + last_price.atr * 1.5
    end
  end

  def place_stop(:very_tight, prices, sens) do
    last_price = prices |> Enum.reverse |> hd
    if sens == :buy do
      last_price.close - last_price.atr
    else
      last_price.close + last_price.atr
    end
  end

end

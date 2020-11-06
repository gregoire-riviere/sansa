defmodule Sansa.Orders do
  use GenServer
  require Logger

  @atr_stop_ratio 2.5
  @max_number_position 5
  @spread_max Application.get_env(:sansa, :trading)[:spread_max]
  @position_pip Application.get_env(:sansa, :trading)[:position_pip]
  @taille_pour_mille Application.get_env(:sansa, :trading)[:taille_pour_mille]
  @rrp Application.get_env(:sansa, :trading)[:rrp]
  @risque Application.get_env(:sansa, :trading)[:risque]
  @order_method :tight

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting orders service")
    {:ok, nil}
  end

  def compute_risk_for_pip(paire, sl_position, sl_distance, max_risk_eur) do
    pip_factor = if String.contains?(paire, "JPY"), do: 0.01, else: 0.0001
    [frst, scnd] = String.split(paire, "_")
    conversion_factor = case frst do
      "EUR" -> 1
      other -> Oanda.Interface.get_prices("H1", "EUR_#{other}", 100) |> hd |> get_in([:close])
    end
    (((max_risk_eur/sl_distance)*sl_position)/pip_factor)*conversion_factor
  end

  def new_order(paire, prices, sens), do: GenServer.cast(Sansa.Orders, {:new_order, paire, prices, sens, @order_method})
  def handle_cast({:new_order, paire, prices, sens, :regular}, _) do
    cond do
      Oanda.Interface.still_pending(paire) ->
        Slack.Communcation.send_message("#debug", "Ordre toujours en cours pour #{paire}")
      length(Oanda.Interface.get_current_positions()) >= @max_number_position ->
        Slack.Communcation.send_message("#debug", "Trop de positions ouvertes pour le moment")
      true ->
        current = Enum.reverse(prices) |> hd
        nb_digits = current.close |> Float.to_string |> String.split(".") |> Enum.at(1) |> byte_size
        stop_position = if sens == :buy, do: current.close - @atr_stop_ratio*current.atr, else: current.close + @atr_stop_ratio*current.atr
        stop_distance = abs(current.close - stop_position)
        tp_distance = stop_distance * @rrp
        tp_position = if sens == :buy, do: current.close + tp_distance, else: current.close - tp_distance
        risque_max_euros = Float.round(@risque * Oanda.Interface.get_capital(), 2)
        stop_pip = stop_distance / @position_pip[paire]
        risque_pour_mille = @taille_pour_mille[paire] * stop_pip
        Logger.debug(risque_pour_mille)
        volume = trunc(Float.round(risque_max_euros*1000/risque_pour_mille))
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
        Oanda.Interface.create_order(commande, current, sens, paire)
    end
    {:noreply, nil}
  end

  def find_last_point(prices, sens) do
    current = Enum.reverse(prices) |> hd
    case sens do
      :buy  ->
        price_point = - current.atr*0.3 + (Enum.reverse(prices) |> Enum.take(5) |> Enum.map(& &1.low) |> Enum.min)
        atr_limit = current.close - current.atr*@atr_stop_ratio
        Enum.max([price_point, atr_limit])
      :sell ->
        price_point = current.atr*0.3 + (Enum.reverse(prices) |> Enum.take(5) |> Enum.map(& &1.high) |> Enum.max)
        atr_limit = current.close + current.atr*@atr_stop_ratio
        Enum.min([price_point, atr_limit])
    end
  end

  def handle_cast({:new_order, paire, prices, sens, :tight}, _) do
    cond do
      Oanda.Interface.still_pending(paire) ->
        Slack.Communcation.send_message("#debug", "Ordre toujours en cours pour #{paire}")
      length(Oanda.Interface.get_current_positions()) >= @max_number_position ->
        Slack.Communcation.send_message("#debug", "Trop de positions ouvertes pour le moment")
      true ->
        current = Enum.reverse(prices) |> hd
        nb_digits = current.close |> Float.to_string |> String.split(".") |> Enum.at(1) |> byte_size

        #sl and tp position
        stop_position = find_last_point(prices, sens)
        stop_distance = abs(current.close - stop_position)
        tp_distance = stop_distance * @rrp
        tp_position = if sens == :buy, do: current.close + tp_distance, else: current.close - tp_distance

        #Volume computation
        risque_max_euros = Float.round(@risque * Oanda.Interface.get_capital(), 2)
        stop_pip = stop_distance / @position_pip[paire]
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
        Oanda.Interface.create_order(commande, current, sens, paire)
    end
    {:noreply, nil}
  end
end

defmodule Sansa.Orders do
  use GenServer
  require Logger

  @atr_stop_ratio 2
  @spread_max Application.get_env(:sansa, :trading)[:spread_max]
  @position_pip Application.get_env(:sansa, :trading)[:position_pip]
  @taille_pour_mille Application.get_env(:sansa, :trading)[:taille_pour_mille]
  @rrp Application.get_env(:sansa, :trading)[:rrp]
  @risque Application.get_env(:sansa, :trading)[:risque]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting orders service")
    {:ok, nil}
  end

  def handle_cast({:new_order, paire, prices, sens}, _) do
    if Oanda.Interface.still_pending(paire) do
      Slack.Communcation.send_message("#debug", "Ordre toujours en cours pour #{paire}")
    else
      current = Enum.reverse(prices) |> hd
      nb_digits = current.close |> Float.to_string |> String.split(".") |> Enum.at(1) |> byte_size
      stop_position = if sens == :buy, do: current.close - @atr_stop_ratio*current.atr, else: current.close + @atr_stop_ratio*current.atr
      stop_distance = abs(current.close - stop_position)
      tp_distance = stop_distance * @rrp
      tp_position = if sens == :buy, do: current.close + tp_distance, else: current.close - tp_distance
      risque_max_euros = Float.round(@risque * Oanda.Interface.get_capital(), 2)
      stop_pip = stop_distance / @position_pip[paire]
      risque_pour_mille = @taille_pour_mille[paire] * stop_pip
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
  end

end

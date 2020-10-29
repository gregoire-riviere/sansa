defmodule Slack.Communcation do
  require Logger

  def slack_header do
      token = File.read!("data/slack_token") |> String.trim_trailing("\n")
      [{'Content-Type', 'application/json'}, {'Authorization', '#{token}'}]
  end

  def send_message(chan, message) do
    if chan == "#debug" do
      Logger.debug(message)
    else
      Logger.info(message)
    end
    req = Poison.encode!(%{
      "channel" => chan,
      "text" => message
    })
    url = "https://slack.com/api/chat.postMessage"
    header = slack_header()
    Logger.debug(req)
    :httpc.request(:post, {'#{url}', header, 'application/json', '#{req}'}, [], [])
  end

  def send_report(result) do
    req = Poison.encode!(%{
      "channel" => "#backtest",
      "text" => result,
      "icon_emoji" => ":bar_chart:"
    })
    url = "https://slack.com/api/chat.postMessage"
    header = slack_header()
    :httpc.request(:post, {'#{url}', header, 'application/json', '#{req}'}, [], [])
    :ok
  end

end

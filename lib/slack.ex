defmodule Slack.Communcation do
  require Logger

  def slack_header do
      token = File.read!("data/slack_token") |> String.trim_trailing("\n")
      [{'Content-Type', 'application/json'}, {'Authorization', '#{token}'}]
  end

  def slack_chan, do: "#" <> (File.read!("data/slack_channel") |> String.trim_trailing("\n"))

  def send_message(chan, message, opts \\ %{}) do
    %{emoji: emoji, attachments: attachments} = Enum.into(Enum.into(opts, %{}), %{emoji: nil, attachments: nil})
    req = %{
      "channel" => chan,
      "text" => message,
    }
    req = if emoji, do: put_in(req, ["icon_emoji"], emoji) |> put_in(["as_user"], true), else: req
    req = if attachments, do: put_in(req, ["attachments"], [%{"text"=> attachments}]), else: req
    req = Poison.encode!(req)
    url = "https://slack.com/api/chat.postMessage"
    header = slack_header()
    Logger.debug(req)
    :httpc.request(:post, {'#{url}', header, 'application/json', '#{req}'}, [], [])
  end

end

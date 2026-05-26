defmodule Portal.FounderChat.Telegram do
  @moduledoc false

  require Logger

  alias Portal.FounderChat.{Conversation, Message}

  def create_topic(%Conversation{} = conversation) do
    case request("createForumTopic", %{
           chat_id: config()[:telegram_chat_id],
           name: "Caio visitor ##{conversation.id}"
         }) do
      {:ok, %{"result" => %{"message_thread_id" => thread_id}}} -> thread_id
      _ -> nil
    end
  end

  def send_conversation_started(%Conversation{} = conversation) do
    text = """
    New Caio chat ##{conversation.id}
    Path: #{conversation.current_path || "/"}

    Reply in this topic, or use:
    /reply #{conversation.id} your message
    """

    send_message(conversation, String.trim(text))
  end

  def send_visitor_message(%Conversation{} = conversation, %Message{} = message) do
    send_message(conversation, "Visitor ##{conversation.id}: #{message.body}")
  end

  def send_message(%Conversation{} = conversation, text) do
    payload =
      %{
        chat_id: conversation.telegram_chat_id || config()[:telegram_chat_id],
        text: text,
        disable_web_page_preview: true
      }
      |> maybe_put_thread(conversation.telegram_thread_id)

    request("sendMessage", payload)
  end

  defp maybe_put_thread(payload, thread_id) when thread_id in [nil, ""], do: payload

  defp maybe_put_thread(payload, thread_id) do
    case Integer.parse(to_string(thread_id)) do
      {id, ""} -> Map.put(payload, :message_thread_id, id)
      _ -> payload
    end
  end

  defp request(method, payload) do
    token = config()[:telegram_bot_token]

    cond do
      config()[:telegram_delivery_enabled] == false ->
        {:ok, %{"ok" => true, "result" => %{}}}

      blank?(token) ->
        {:error, :missing_token}

      true ->
        url = ~c"https://api.telegram.org/bot#{token}/#{method}"
        body = Jason.encode!(payload)
        headers = [{~c"content-type", ~c"application/json"}]

        case :httpc.request(:post, {url, headers, ~c"application/json", body}, [], []) do
          {:ok, {{_, status, _}, _headers, response_body}} when status in 200..299 ->
            Jason.decode(to_string(response_body))

          {:ok, {{_, status, _}, _headers, response_body}} ->
            Logger.warning("Telegram #{method} failed with #{status}: #{inspect(response_body)}")
            {:error, status}

          {:error, reason} ->
            Logger.warning("Telegram #{method} failed: #{inspect(reason)}")
            {:error, reason}
        end
    end
  rescue
    error ->
      Logger.warning("Telegram #{method} raised: #{Exception.message(error)}")
      {:error, error}
  end

  defp config, do: Application.get_env(:portal, :founder_chat, [])

  defp blank?(value), do: !is_binary(value) or String.trim(value) == ""
end

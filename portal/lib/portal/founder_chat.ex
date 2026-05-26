defmodule Portal.FounderChat do
  import Ecto.Query

  alias Portal.Accounts
  alias Portal.FounderChat.{Conversation, Message, Telegram}
  alias Portal.Repo

  def enabled? do
    config = config()

    truthy?(config[:enabled]) and present?(config[:telegram_bot_token]) and
      present?(config[:telegram_chat_id])
  end

  def widget_config do
    if enabled?() do
      %{
        title: config()[:title] || "Chat with Daniel",
        subtitle: config()[:subtitle] || "I read these directly in Telegram."
      }
    end
  end

  def get_or_create_conversation(session_token, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    conversation =
      Conversation
      |> where([c], c.session_token == ^session_token and c.status == "open")
      |> order_by([c], desc: c.id)
      |> limit(1)
      |> Repo.one()

    attrs =
      attrs
      |> Map.take([:lead_id, :current_path, :user_agent])
      |> Map.put(:session_token, session_token)
      |> Map.put(:last_seen_at, now)

    case conversation do
      nil ->
        %Conversation{}
        |> Conversation.changeset(Map.put(attrs, :status, "open"))
        |> Repo.insert()
        |> tap(fn
          {:ok, conversation} -> ensure_telegram_thread(conversation)
          _ -> :ok
        end)

      conversation ->
        conversation
        |> Conversation.changeset(attrs)
        |> Repo.update()
        |> tap(fn
          {:ok, conversation} -> ensure_telegram_thread(conversation)
          _ -> :ok
        end)
    end
  end

  def list_messages(conversation_id, after_id \\ 0) do
    Message
    |> where([m], m.conversation_id == ^conversation_id and m.id > ^after_id)
    |> order_by([m], asc: m.id)
    |> limit(100)
    |> Repo.all()
  end

  def create_visitor_message(conversation, body) do
    body = clean_body(body)

    with {:ok, message} <- create_message(conversation, "visitor", body) do
      Telegram.send_visitor_message(conversation, message)
      {:ok, message}
    end
  end

  def create_founder_message_from_telegram(%{"message" => message}) do
    text = clean_body(message["text"] || message["caption"])
    if text == "", do: :ignored, else: create_founder_message(message, text)
  end

  def create_founder_message_from_telegram(_payload), do: :ignored

  defp create_founder_message(message, text) do
    chat_id = to_string(get_in(message, ["chat", "id"]) || "")
    thread_id = to_string(message["message_thread_id"] || "")

    conversation =
      conversation_by_thread(chat_id, thread_id) ||
        conversation_by_reply_command(text)

    case conversation do
      nil ->
        :ignored

      conversation ->
        clean_text = String.replace(text, ~r/^\/reply\s+\d+\s+/i, "")

        create_message(
          conversation,
          "founder",
          clean_text,
          to_string(message["message_id"] || "")
        )
    end
  end

  defp conversation_by_thread(_chat_id, ""), do: nil

  defp conversation_by_thread(chat_id, thread_id) do
    Conversation
    |> where([c], c.telegram_chat_id == ^chat_id and c.telegram_thread_id == ^thread_id)
    |> order_by([c], desc: c.id)
    |> limit(1)
    |> Repo.one()
  end

  defp conversation_by_reply_command(text) do
    with [_, id] <- Regex.run(~r/^\/reply\s+(\d+)\s+/i, text) do
      Repo.get(Conversation, id)
    else
      _ -> nil
    end
  end

  defp create_message(conversation, direction, body, telegram_message_id \\ nil) do
    %Message{}
    |> Message.changeset(%{
      conversation_id: conversation.id,
      direction: direction,
      body: body,
      telegram_message_id: telegram_message_id
    })
    |> Repo.insert()
  end

  defp ensure_telegram_thread(%Conversation{telegram_chat_id: chat_id} = conversation)
       when chat_id not in [nil, ""] do
    {:ok, conversation}
  end

  defp ensure_telegram_thread(conversation) do
    config = config()
    chat_id = to_string(config[:telegram_chat_id])

    thread_id =
      if truthy?(config[:telegram_forum_topics]) do
        Telegram.create_topic(conversation)
      end

    conversation
    |> Conversation.changeset(%{
      telegram_chat_id: chat_id,
      telegram_thread_id: to_string(thread_id || "")
    })
    |> Repo.update()
    |> tap(fn
      {:ok, updated} -> Telegram.send_conversation_started(updated)
      _ -> :ok
    end)
  end

  defp config, do: Application.get_env(:portal, :founder_chat, [])

  defp clean_body(body) do
    body
    |> to_string()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 4_000)
  end

  defp present?(value), do: is_binary(value) && String.trim(value) != ""

  defp truthy?(value), do: value in [true, "1", "true", "TRUE", "yes", "YES"]

  def lead_id_from_session(nil), do: nil

  def lead_id_from_session(lead_id) do
    case Accounts.get_lead(lead_id) do
      nil -> nil
      lead -> lead.id
    end
  end
end

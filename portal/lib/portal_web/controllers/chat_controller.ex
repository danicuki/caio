defmodule PortalWeb.ChatController do
  use PortalWeb, :controller

  alias Portal.FounderChat

  def config(conn, _params) do
    json(conn, %{enabled: FounderChat.enabled?(), widget: FounderChat.widget_config()})
  end

  def create_conversation(conn, params) do
    if FounderChat.enabled?() do
      do_create_conversation(conn, params)
    else
      chat_not_found(conn)
    end
  end

  defp do_create_conversation(conn, params) do
    conn = ensure_session_token(conn)

    attrs = %{
      lead_id: FounderChat.lead_id_from_session(get_session(conn, :lead_id)),
      current_path: params["path"],
      user_agent: conn |> get_req_header("user-agent") |> List.first()
    }

    case FounderChat.get_or_create_conversation(get_session(conn, :session_token), attrs) do
      {:ok, conversation} ->
        conn
        |> put_session(:chat_conversation_id, conversation.id)
        |> json(%{conversation: conversation_json(conversation), messages: []})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not start chat"})
    end
  end

  def messages(conn, params) do
    with true <- FounderChat.enabled?(),
         {:ok, conversation_id} <- conversation_id(conn),
         true <- authorized_conversation?(conn, conversation_id) do
      after_id = params["after_id"] |> parse_int()
      messages = FounderChat.list_messages(conversation_id, after_id)

      json(conn, %{messages: Enum.map(messages, &message_json/1)})
    else
      _ ->
        chat_not_found(conn)
    end
  end

  def create_message(conn, %{"message" => %{"body" => body}}) do
    with true <- FounderChat.enabled?(),
         {:ok, conversation_id} <- conversation_id(conn),
         true <- authorized_conversation?(conn, conversation_id),
         conversation when not is_nil(conversation) <-
           Portal.Repo.get(Portal.FounderChat.Conversation, conversation_id),
         {:ok, message} <- FounderChat.create_visitor_message(conversation, body) do
      json(conn, %{message: message_json(message)})
    else
      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not send message"})
    end
  end

  def create_message(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Message body is required"})
  end

  defp chat_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Chat not found"})
  end

  def telegram_webhook(conn, %{"secret" => secret} = params) do
    expected = Application.get_env(:portal, :founder_chat, [])[:telegram_webhook_secret]

    if webhook_secret_matches?(secret, expected) do
      FounderChat.create_founder_message_from_telegram(params)
      json(conn, %{ok: true})
    else
      conn
      |> put_status(:not_found)
      |> json(%{ok: false})
    end
  end

  defp webhook_secret_matches?(secret, expected)
       when is_binary(secret) and is_binary(expected) and expected != "" do
    byte_size(secret) == byte_size(expected) and Plug.Crypto.secure_compare(secret, expected)
  end

  defp webhook_secret_matches?(_secret, _expected), do: false

  defp conversation_id(conn) do
    case get_session(conn, :chat_conversation_id) do
      id when is_integer(id) -> {:ok, id}
      id when is_binary(id) -> {:ok, parse_int(id)}
      _ -> :error
    end
  end

  defp authorized_conversation?(conn, conversation_id) do
    conversation = Portal.Repo.get(Portal.FounderChat.Conversation, conversation_id)
    conversation && conversation.session_token == get_session(conn, :session_token)
  end

  defp ensure_session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> put_session(conn, :session_token, Ecto.UUID.generate())
      _ -> conn
    end
  end

  defp parse_int(nil), do: 0

  defp parse_int(value) do
    case Integer.parse(to_string(value)) do
      {int, _} -> int
      _ -> 0
    end
  end

  defp conversation_json(conversation) do
    %{
      id: conversation.id,
      status: conversation.status
    }
  end

  defp message_json(message) do
    %{
      id: message.id,
      direction: message.direction,
      body: message.body,
      created_at: message.created_at
    }
  end
end

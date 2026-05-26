defmodule PortalWeb.ChatControllerTest do
  use PortalWeb.ConnCase

  import Ecto.Query

  alias Portal.FounderChat.{Conversation, Message}
  alias Portal.Repo

  setup do
    previous = Application.get_env(:portal, :founder_chat)

    Application.put_env(:portal, :founder_chat,
      enabled: true,
      title: "Chat with Daniel",
      subtitle: "Telegram direct",
      telegram_bot_token: "test-token",
      telegram_chat_id: "-100123",
      telegram_webhook_secret: "test-secret",
      telegram_delivery_enabled: false,
      telegram_forum_topics: false
    )

    on_exit(fn -> Application.put_env(:portal, :founder_chat, previous) end)
  end

  test "starts a conversation and stores visitor messages", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post("/chat/conversations", %{path: "/jobs/123"})

    assert %{"conversation" => %{"id" => conversation_id}} = json_response(conn, 200)
    assert get_session(conn, :chat_conversation_id) == conversation_id

    conn =
      conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> post("/chat/messages", %{message: %{body: "This search feels useful"}})

    assert %{"message" => %{"body" => "This search feels useful", "direction" => "visitor"}} =
             json_response(conn, 200)

    conversation = Repo.get!(Conversation, conversation_id)
    assert conversation.current_path == "/jobs/123"
    assert conversation.telegram_chat_id == "-100123"

    assert Repo.one!(
             from(m in Message, where: m.conversation_id == ^conversation_id, select: count(m.id))
           ) == 1
  end

  test "records Telegram replies for a conversation", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post("/chat/conversations", %{path: "/"})

    %{"conversation" => %{"id" => conversation_id}} = json_response(conn, 200)

    payload = %{
      message: %{
        message_id: 99,
        text: "/reply #{conversation_id} Thanks for trying Caio",
        chat: %{id: -100_123}
      }
    }

    conn =
      build_conn()
      |> put_req_header("accept", "application/json")
      |> post("/telegram/webhook/test-secret", payload)

    assert %{"ok" => true} = json_response(conn, 200)

    message =
      Repo.one!(
        from(m in Message,
          where: m.conversation_id == ^conversation_id and m.direction == "founder"
        )
      )

    assert message.body == "Thanks for trying Caio"
    assert message.telegram_message_id == "99"
  end
end

defmodule Portal.Repo.Migrations.AddFounderChatTables do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:chat_conversations) do
      add :session_token, :text, null: false
      add :lead_id, references(:leads, on_delete: :nilify_all)
      add :visitor_name, :text
      add :current_path, :text
      add :user_agent, :text
      add :telegram_chat_id, :text
      add :telegram_thread_id, :text
      add :status, :text, null: false, default: "open"
      add :last_seen_at, :utc_datetime

      timestamps(inserted_at: :created_at, type: :utc_datetime)
    end

    create_if_not_exists index(:chat_conversations, [:session_token])
    create_if_not_exists index(:chat_conversations, [:lead_id])

    execute("""
    CREATE INDEX IF NOT EXISTS chat_conversations_telegram_thread_index
    ON chat_conversations(telegram_chat_id, telegram_thread_id);
    """)

    create_if_not_exists table(:chat_messages) do
      add :conversation_id, references(:chat_conversations, on_delete: :delete_all), null: false
      add :direction, :text, null: false
      add :body, :text, null: false
      add :telegram_message_id, :text

      timestamps(updated_at: false, inserted_at: :created_at, type: :utc_datetime)
    end

    create_if_not_exists index(:chat_messages, [:conversation_id, :id])
  end
end

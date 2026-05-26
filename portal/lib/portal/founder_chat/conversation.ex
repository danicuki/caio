defmodule Portal.FounderChat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_conversations" do
    field :session_token, :string
    field :visitor_name, :string
    field :current_path, :string
    field :user_agent, :string
    field :telegram_chat_id, :string
    field :telegram_thread_id, :string
    field :status, :string, default: "open"
    field :last_seen_at, :utc_datetime

    belongs_to :lead, Portal.Accounts.Lead
    has_many :messages, Portal.FounderChat.Message

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [
      :session_token,
      :lead_id,
      :visitor_name,
      :current_path,
      :user_agent,
      :telegram_chat_id,
      :telegram_thread_id,
      :status,
      :last_seen_at
    ])
    |> validate_required([:session_token, :status])
  end
end

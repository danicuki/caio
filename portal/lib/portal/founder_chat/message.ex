defmodule Portal.FounderChat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :direction, :string
    field :body, :string
    field :telegram_message_id, :string

    belongs_to :conversation, Portal.FounderChat.Conversation

    timestamps(updated_at: false, inserted_at: :created_at, type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :direction, :body, :telegram_message_id])
    |> validate_required([:conversation_id, :direction, :body])
    |> validate_inclusion(:direction, ["visitor", "founder", "system"])
    |> validate_length(:body, min: 1, max: 4_000)
  end
end

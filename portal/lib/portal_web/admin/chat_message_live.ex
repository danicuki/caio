defmodule PortalWeb.Admin.ChatMessageLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Portal.FounderChat.Message,
      repo: Portal.Repo,
      item_query: &PortalWeb.Admin.Actions.sqlite_item_query/3
    ],
    init_order: %{by: :created_at, direction: :desc},
    per_page_default: 50

  @impl Backpex.LiveResource
  def singular_name, do: "Chat message"

  @impl Backpex.LiveResource
  def plural_name, do: "Chat messages"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {PortalWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def item_actions(default_actions), do: PortalWeb.Admin.Actions.read_only(default_actions)

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item) when action in [:new, :edit, :delete], do: false
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", orderable: true},
      conversation_id: %{module: Backpex.Fields.Number, label: "Conversation", orderable: true},
      direction: %{
        module: Backpex.Fields.Text,
        label: "Direction",
        searchable: true,
        orderable: true
      },
      body: %{module: Backpex.Fields.Textarea, label: "Body", searchable: true},
      telegram_message_id: %{
        module: Backpex.Fields.Text,
        label: "Telegram message",
        except: [:index]
      },
      created_at: %{module: Backpex.Fields.DateTime, label: "Created", orderable: true}
    ]
  end
end

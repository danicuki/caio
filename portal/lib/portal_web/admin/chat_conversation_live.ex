defmodule PortalWeb.Admin.ChatConversationLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Portal.FounderChat.Conversation,
      repo: Portal.Repo,
      update_changeset: &PortalWeb.Admin.Changesets.conversation/3,
      item_query: &PortalWeb.Admin.Actions.sqlite_item_query/3
    ],
    init_order: %{by: :created_at, direction: :desc},
    per_page_default: 50

  @impl Backpex.LiveResource
  def singular_name, do: "Chat conversation"

  @impl Backpex.LiveResource
  def plural_name, do: "Chat conversations"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {PortalWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def item_actions(default_actions), do: PortalWeb.Admin.Actions.editable(default_actions)

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item) when action in [:new, :delete], do: false
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", orderable: true},
      lead_id: %{module: Backpex.Fields.Number, label: "Lead ID", orderable: true},
      visitor_name: %{module: Backpex.Fields.Text, label: "Visitor", searchable: true},
      status: %{
        module: Backpex.Fields.Select,
        label: "Status",
        options: [{"Open", "open"}, {"Closed", "closed"}]
      },
      current_path: %{module: Backpex.Fields.Text, label: "Path", searchable: true},
      telegram_chat_id: %{module: Backpex.Fields.Text, label: "Telegram chat", except: [:index]},
      telegram_thread_id: %{
        module: Backpex.Fields.Text,
        label: "Telegram thread",
        except: [:index]
      },
      user_agent: %{module: Backpex.Fields.Textarea, label: "User agent", except: [:index]},
      last_seen_at: %{module: Backpex.Fields.DateTime, label: "Last seen", orderable: true},
      created_at: %{module: Backpex.Fields.DateTime, label: "Created", orderable: true},
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated",
        orderable: true,
        except: [:index]
      }
    ]
  end
end

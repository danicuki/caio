defmodule PortalWeb.Admin.JobInterestLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Portal.Accounts.JobInterest,
      repo: Portal.Repo,
      item_query: &PortalWeb.Admin.Actions.sqlite_item_query/3
    ],
    init_order: %{by: :created_at, direction: :desc},
    per_page_default: 50

  @impl Backpex.LiveResource
  def singular_name, do: "Job interest"

  @impl Backpex.LiveResource
  def plural_name, do: "Job interests"

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
      lead_id: %{module: Backpex.Fields.Number, label: "Lead ID", orderable: true},
      job_post_id: %{module: Backpex.Fields.Number, label: "Job ID", orderable: true},
      session_token: %{
        module: Backpex.Fields.Text,
        label: "Session",
        searchable: true,
        except: [:index]
      },
      source_url: %{module: Backpex.Fields.URL, label: "Source URL", searchable: true},
      created_at: %{module: Backpex.Fields.DateTime, label: "Created", orderable: true}
    ]
  end
end

defmodule PortalWeb.Admin.LeadLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Portal.Accounts.Lead,
      repo: Portal.Repo,
      create_changeset: &PortalWeb.Admin.Changesets.lead/3,
      update_changeset: &PortalWeb.Admin.Changesets.lead/3,
      item_query: &PortalWeb.Admin.Actions.sqlite_item_query/3
    ],
    init_order: %{by: :created_at, direction: :desc},
    per_page_default: 50

  @impl Backpex.LiveResource
  def singular_name, do: "Lead"

  @impl Backpex.LiveResource
  def plural_name, do: "Leads"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {PortalWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", orderable: true, except: [:new, :edit]},
      email: %{module: Backpex.Fields.Email, label: "Email", searchable: true, orderable: true},
      linkedin_url: %{module: Backpex.Fields.URL, label: "LinkedIn", searchable: true},
      target_role: %{module: Backpex.Fields.Text, label: "Target role", searchable: true},
      target_location: %{module: Backpex.Fields.Text, label: "Target location", searchable: true},
      consent_job_help: %{module: Backpex.Fields.Boolean, label: "Wants job help"},
      created_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created",
        orderable: true,
        except: [:new, :edit]
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated",
        orderable: true,
        except: [:new, :edit]
      }
    ]
  end
end

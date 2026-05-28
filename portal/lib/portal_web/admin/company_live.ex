defmodule PortalWeb.Admin.CompanyLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Portal.Jobs.Company,
      repo: Portal.Repo,
      update_changeset: &PortalWeb.Admin.Changesets.company/3,
      item_query: &PortalWeb.Admin.Actions.sqlite_item_query/3
    ],
    init_order: %{by: :open_jobs_count, direction: :desc},
    primary_key: :id,
    per_page_default: 50

  @impl Backpex.LiveResource
  def singular_name, do: "Company"

  @impl Backpex.LiveResource
  def plural_name, do: "Companies"

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
      id: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        searchable: true,
        orderable: true,
        readonly: true
      },
      name: %{module: Backpex.Fields.Text, label: "Name", searchable: true, orderable: true},
      logo_url: %{module: Backpex.Fields.URL, label: "Logo URL"},
      website_url: %{module: Backpex.Fields.URL, label: "Website"},
      description: %{module: Backpex.Fields.Textarea, label: "Description", except: [:index]},
      open_jobs_count: %{
        module: Backpex.Fields.Number,
        label: "Open jobs",
        orderable: true,
        except: [:new, :edit]
      },
      source_count: %{
        module: Backpex.Fields.Number,
        label: "Sources",
        orderable: true,
        except: [:new, :edit]
      },
      location_count: %{
        module: Backpex.Fields.Number,
        label: "Locations",
        orderable: true,
        except: [:new, :edit]
      },
      remote_count: %{
        module: Backpex.Fields.Number,
        label: "Remote",
        orderable: true,
        except: [:new, :edit]
      },
      salary_count: %{
        module: Backpex.Fields.Number,
        label: "Salary data",
        orderable: true,
        except: [:new, :edit]
      },
      refreshed_at: %{module: Backpex.Fields.Text, label: "Refreshed", except: [:new, :edit]}
    ]
  end
end

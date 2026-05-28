defmodule PortalWeb.Admin.JobPostLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Portal.Jobs.JobPost,
      repo: Portal.Repo,
      item_query: &PortalWeb.Admin.Actions.sqlite_item_query/3
    ],
    init_order: %{by: :id, direction: :desc},
    per_page_default: 50

  @impl Backpex.LiveResource
  def singular_name, do: "Job"

  @impl Backpex.LiveResource
  def plural_name, do: "Jobs"

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
      title: %{module: Backpex.Fields.Text, label: "Title", searchable: true, orderable: true},
      company: %{module: Backpex.Fields.Text, label: "Company", searchable: true, orderable: true},
      company_id: %{
        module: Backpex.Fields.Text,
        label: "Company slug",
        searchable: true,
        except: [:index]
      },
      source: %{module: Backpex.Fields.Text, label: "Source", searchable: true, orderable: true},
      source_key: %{
        module: Backpex.Fields.Text,
        label: "Source key",
        searchable: true,
        except: [:index]
      },
      location: %{module: Backpex.Fields.Text, label: "Location", searchable: true},
      remote: %{module: Backpex.Fields.Number, label: "Remote", orderable: true, except: [:index]},
      employment_type: %{module: Backpex.Fields.Text, label: "Employment", searchable: true},
      category: %{
        module: Backpex.Fields.Text,
        label: "Category",
        searchable: true,
        except: [:index]
      },
      salary: %{module: Backpex.Fields.Text, label: "Salary", searchable: true},
      source_url: %{module: Backpex.Fields.URL, label: "Source URL", except: [:index]},
      published_at: %{module: Backpex.Fields.Text, label: "Published", orderable: true},
      created_at: %{
        module: Backpex.Fields.Text,
        label: "Created",
        orderable: true,
        except: [:index]
      },
      updated_at: %{
        module: Backpex.Fields.Text,
        label: "Updated",
        orderable: true,
        except: [:index]
      },
      description: %{module: Backpex.Fields.Textarea, label: "Description", except: [:index]}
    ]
  end
end

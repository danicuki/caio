defmodule Portal.Jobs.JobUrlOverride do
  use Ecto.Schema

  schema "job_url_overrides" do
    field :source, :string
    field :source_key, :string
    field :apply_url, :string
    field :reason, :string
    field :created_at, :string
    field :updated_at, :string
  end
end

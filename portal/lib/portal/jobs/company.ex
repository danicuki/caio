defmodule Portal.Jobs.Company do
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}

  schema "companies" do
    field :name, :string
    field :logo_url, :string
    field :website_url, :string
    field :description, :string
    field :open_jobs_count, :integer, default: 0
    field :source_count, :integer, default: 0
    field :location_count, :integer, default: 0
    field :remote_count, :integer, default: 0
    field :salary_count, :integer, default: 0
    field :latest_posted_at, :string
    field :top_locations_json, :string, default: "[]"
    field :top_sources_json, :string, default: "[]"
    field :refreshed_at, :string
    field :created_at, :string
    field :updated_at, :string
  end
end

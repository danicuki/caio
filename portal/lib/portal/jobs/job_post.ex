defmodule Portal.Jobs.JobPost do
  use Ecto.Schema

  schema "job_posts" do
    field :source, :string
    field :source_key, :string
    field :title, :string
    field :company, :string
    field :company_id, :string
    field :company_logo_url, :string, virtual: true
    field :location, :string
    field :remote, :integer
    field :employment_type, :string
    field :category, :string
    field :salary, :string
    field :source_url, :string
    field :published_at, :string
    field :tags_json, :string
    field :description, :string
    field :salary_min, :float
    field :salary_max, :float
    field :salary_currency, :string
    field :salary_period, :string
    field :location_city, :string
    field :location_state, :string
    field :location_country, :string
    field :location_continent, :string
    field :location_scope, :string
    field :created_at, :string
    field :updated_at, :string
  end
end

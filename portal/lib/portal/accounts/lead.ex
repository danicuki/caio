defmodule Portal.Accounts.Lead do
  use Ecto.Schema
  import Ecto.Changeset

  schema "leads" do
    field :email, :string
    field :linkedin_url, :string
    field :target_role, :string
    field :target_location, :string
    field :consent_job_help, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  def changeset(lead, attrs) do
    lead
    |> cast(attrs, [:email, :linkedin_url, :target_role, :target_location, :consent_job_help])
    |> update_change(:email, fn email -> email |> String.trim() |> String.downcase() end)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_format(:linkedin_url, ~r/^https?:\/\/(www\.)?linkedin\.com\//,
      message: "must be a LinkedIn URL"
    )
    |> unique_constraint(:email)
  end
end

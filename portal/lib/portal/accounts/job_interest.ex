defmodule Portal.Accounts.JobInterest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "job_interests" do
    field :job_post_id, :integer
    field :session_token, :string
    field :source_url, :string
    belongs_to :lead, Portal.Accounts.Lead

    field :created_at, :utc_datetime
  end

  def changeset(interest, attrs) do
    interest
    |> cast(attrs, [:lead_id, :job_post_id, :session_token, :source_url, :created_at])
    |> validate_required([:job_post_id, :source_url, :created_at])
  end
end

defmodule Portal.Accounts do
  import Ecto.Query

  alias Portal.Accounts.{JobInterest, Lead}
  alias Portal.Jobs.JobPost
  alias Portal.Repo

  def get_lead(nil), do: nil
  def get_lead(id), do: Repo.get(Lead, id)

  def upsert_lead(attrs) do
    email = attrs["email"] || attrs[:email]

    case Repo.get_by(Lead, email: String.downcase(String.trim(email || ""))) do
      nil ->
        %Lead{}
        |> Lead.changeset(attrs)
        |> Repo.insert()

      lead ->
        lead
        |> Lead.changeset(attrs)
        |> Repo.update()
    end
  end

  def record_interest(attrs) do
    %JobInterest{}
    |> JobInterest.changeset(
      Map.put(attrs, :created_at, DateTime.utc_now() |> DateTime.truncate(:second))
    )
    |> Repo.insert()
  end

  def recent_interest_count(lead_id) do
    JobInterest
    |> where([i], i.lead_id == ^lead_id)
    |> select([i], count(i.id))
    |> Repo.one()
  end

  def recent_interests(lead_id, limit \\ 50)

  def recent_interests(nil, _limit), do: []

  def recent_interests(lead_id, limit) do
    JobInterest
    |> join(:left, [i], j in JobPost, on: j.id == i.job_post_id)
    |> where([i], i.lead_id == ^lead_id)
    |> order_by([i], desc: i.created_at, desc: i.id)
    |> limit(^limit)
    |> select([i, j], %{interest: i, job: j})
    |> Repo.all()
  end
end

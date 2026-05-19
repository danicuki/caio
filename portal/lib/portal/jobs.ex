defmodule Portal.Jobs do
  import Ecto.Query

  alias Portal.Jobs.JobPost
  alias Portal.Repo

  @guest_limit 10
  @guest_preview 18
  @member_limit 50

  def guest_limit, do: @guest_limit

  def search(params, unlocked?) do
    limit = if unlocked?, do: @member_limit, else: @guest_preview

    JobPost
    |> base_filters(params)
    |> order_by([j], desc: coalesce(j.published_at, j.updated_at), desc: j.id)
    |> limit(^limit)
    |> Repo.all()
  end

  def count(params) do
    JobPost
    |> base_filters(params)
    |> select([j], count(j.id))
    |> Repo.one()
  end

  def get!(id), do: Repo.get!(JobPost, id)

  defp base_filters(query, params) do
    query
    |> text_search(params["q"])
    |> like_filter(:title, params["role"])
    |> location_filter(params["location"])
  end

  defp text_search(query, value) when is_binary(value) do
    fts = fts_query(value)

    if fts == "" do
      query
    else
      where(
        query,
        [j],
        fragment("? IN (SELECT rowid FROM job_posts_fts WHERE job_posts_fts MATCH ?)", j.id, ^fts)
      )
    end
  end

  defp text_search(query, _), do: query

  defp like_filter(query, _field, value) when value in [nil, ""], do: query

  defp like_filter(query, field, value) do
    pattern = "%#{String.trim(value)}%"
    where(query, [j], like(field(j, ^field), ^pattern))
  end

  defp location_filter(query, value) when value in [nil, ""], do: query

  defp location_filter(query, value) do
    pattern = "%#{String.trim(value)}%"

    where(
      query,
      [j],
      like(j.location, ^pattern) or like(j.location_city, ^pattern) or
        like(j.location_state, ^pattern) or like(j.location_country, ^pattern) or
        like(j.location_continent, ^pattern)
    )
  end

  defp fts_query(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9+#.\s-]/u, " ")
    |> String.split()
    |> Enum.take(8)
    |> Enum.map(&"\"#{String.replace(&1, "\"", "")}\"")
    |> Enum.join(" ")
  end
end

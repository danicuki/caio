defmodule Portal.Jobs do
  import Ecto.Query

  alias Portal.Jobs.JobPost
  alias Portal.Repo

  @guest_limit 10
  @guest_preview 18
  @member_limit 50
  @list_fields [
    :id,
    :source,
    :title,
    :company,
    :location,
    :remote,
    :employment_type,
    :category,
    :salary,
    :tags_json,
    :published_at,
    :salary_min,
    :salary_max,
    :salary_currency,
    :salary_period,
    :location_city,
    :location_state,
    :location_country,
    :location_continent,
    :location_scope,
    :updated_at
  ]

  def guest_limit, do: @guest_limit

  def total_count do
    JobPost
    |> public_scope()
    |> select([j], count(j.id))
    |> Repo.one()
  end

  def search(params, unlocked?) do
    limit = if unlocked?, do: @member_limit, else: @guest_preview

    JobPost
    |> public_scope()
    |> base_filters(params)
    |> apply_order(params)
    |> limit(^limit)
    |> select_list_fields()
    |> Repo.all()
  end

  def sample(limit \\ 6) do
    max_id =
      JobPost
      |> public_scope()
      |> select([j], max(j.id))
      |> Repo.one() || 0

    if max_id <= 0 do
      []
    else
      limit
      |> random_id_candidates(max_id)
      |> Enum.flat_map(&sample_from_id/1)
      |> Enum.uniq_by(& &1.id)
      |> Enum.take(limit)
      |> fill_sample(limit)
    end
  end

  def count(params) do
    JobPost
    |> public_scope()
    |> base_filters(params)
    |> limited_count()
  end

  def get!(id) do
    JobPost
    |> public_scope()
    |> where([j], j.id == ^id)
    |> Repo.one!()
  end

  def company_stats(%JobPost{company: company}) when company not in [nil, ""] do
    company_key = normalize_company(company)
    cutoff = public_cutoff_date()

    JobPost
    |> where([j], not is_nil(j.company) and fragment("trim(?)", j.company) != "")
    |> where([j], fragment("lower(trim(?))", j.company) == ^company_key)
    |> where(
      [j],
      fragment("COALESCE(NULLIF(?, ''), '9999-12-31') >= ?", j.published_at, ^cutoff)
    )
    |> select([j], %{
      open_jobs_count: count(),
      source_count: fragment("COUNT(DISTINCT NULLIF(lower(trim(?)), ''))", j.source),
      location_count: fragment("COUNT(DISTINCT NULLIF(lower(trim(?)), ''))", j.location_country),
      latest_posted_at: max(j.published_at)
    })
    |> Repo.one()
  end

  def company_stats(_job) do
    %{
      open_jobs_count: 0,
      source_count: 0,
      location_count: 0,
      latest_posted_at: nil
    }
  end

  defp public_scope(query) do
    cutoff = public_cutoff_date()

    where(
      query,
      [j],
      is_nil(j.published_at) or j.published_at == "" or j.published_at >= ^cutoff
    )
  end

  defp public_cutoff_date do
    Date.utc_today()
    |> Date.add(-183)
    |> Date.to_iso8601()
  end

  defp normalize_company(company) do
    company
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp select_list_fields(query) do
    select(query, [j], struct(j, ^@list_fields))
  end

  defp limited_count(query, cap \\ 10_000) do
    count =
      query
      |> select([j], j.id)
      |> limit(^(cap + 1))
      |> subquery()
      |> select([j], count(j.id))
      |> Repo.one()

    if count > cap, do: "#{cap}+", else: count
  end

  defp random_id_candidates(limit, max_id) do
    Stream.repeatedly(fn -> :rand.uniform(max_id) end)
    |> Enum.take(limit * 4)
  end

  defp sample_from_id(id) do
    JobPost
    |> public_scope()
    |> where([j], j.id >= ^id)
    |> order_by([j], asc: j.id)
    |> limit(1)
    |> select_list_fields()
    |> Repo.all()
  end

  defp fill_sample(jobs, limit) when length(jobs) >= limit, do: jobs

  defp fill_sample(jobs, limit) do
    needed = limit - length(jobs)

    fallback =
      JobPost
      |> public_scope()
      |> order_by([j], desc: j.id)
      |> limit(^needed)
      |> select_list_fields()
      |> Repo.all()

    (jobs ++ fallback)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(limit)
  end

  defp base_filters(query, params) do
    query
    |> text_search(params["q"])
    |> fts_filter(params["role"], "title")
    |> fts_filter(params["company"], "company")
    |> location_filter(params["location"])
  end

  defp apply_order(query, %{"order" => "random"}) do
    order_by(query, [j], fragment("random()"))
  end

  defp apply_order(query, _params) do
    order_by(query, [j], desc: j.id)
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

  defp fts_filter(query, value, columns) when is_binary(value) do
    fts = fts_query(value, columns)

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

  defp fts_filter(query, _value, _columns), do: query

  defp location_filter(query, value) when value in [nil, ""], do: query

  defp location_filter(query, value) do
    fts_filter(
      query,
      value,
      "{location location_city location_state location_country location_continent}"
    )
  end

  defp fts_query(value, columns \\ nil) do
    terms =
      value
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9+#.\s-]/u, " ")
      |> String.split()
      |> Enum.take(8)
      |> Enum.map(&"\"#{String.replace(&1, "\"", "")}\"")
      |> Enum.join(" ")

    cond do
      terms == "" -> ""
      is_nil(columns) -> terms
      true -> "#{columns}: #{terms}"
    end
  end
end

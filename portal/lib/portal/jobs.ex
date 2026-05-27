defmodule Portal.Jobs do
  import Ecto.Query

  alias Portal.Jobs.Company
  alias Portal.Jobs.JobPost
  alias Portal.Jobs.JobUrlOverride
  alias Portal.Repo

  @guest_limit 10
  @guest_preview 18
  @member_limit 50
  @list_fields [
    :id,
    :source,
    :title,
    :company,
    :company_id,
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

  def apply_url(%JobPost{} = job) do
    case Repo.get_by(JobUrlOverride, source: job.source, source_key: job.source_key) do
      nil -> job.source_url
      override -> override.apply_url
    end
  end

  def company_profile(company) when company not in [nil, ""] do
    company
    |> company_slug()
    |> company_profile_by_slug()
  end

  def company_profile(_company), do: nil

  def company_profile_by_slug(slug) when slug not in [nil, ""] do
    slug = normalize_slug(slug)

    case Repo.get(Company, slug) do
      nil -> legacy_company_profile_by_slug(slug)
      company -> company_profile_from_record(company)
    end
  end

  def company_profile_by_slug(_slug), do: nil

  def sitemap_companies(limit \\ 2_000) do
    rows =
      Company
      |> where([c], c.open_jobs_count > 0)
      |> order_by([c], desc: c.open_jobs_count, asc: c.name)
      |> limit(^limit)
      |> select([c], %{
        name: c.name,
        slug: c.id,
        latest_posted_at: c.latest_posted_at,
        count: c.open_jobs_count
      })
      |> Repo.all()

    if rows == [], do: legacy_sitemap_companies(limit), else: rows
  end

  def refresh_companies do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    aliases =
      Repo.query!("""
      SELECT lower(trim(company)) AS normalized_name, min(trim(company)) AS display_name, count(*) AS jobs_count
      FROM job_posts
      WHERE company IS NOT NULL AND trim(company) != ''
      GROUP BY lower(trim(company))
      """)
      |> rows_to_aliases(now)

    aliases
    |> Enum.map(fn alias_row ->
      %{
        id: alias_row.company_id,
        name: alias_row.display_name,
        created_at: now,
        updated_at: now
      }
    end)
    |> Enum.uniq_by(& &1.id)
    |> insert_company_rows(on_conflict: :nothing)

    aliases
    |> Enum.map(fn alias_row ->
      Map.take(alias_row, [
        :company_id,
        :normalized_name,
        :display_name,
        :jobs_count,
        :created_at,
        :updated_at
      ])
    end)
    |> insert_alias_rows()

    Repo.query!("""
    UPDATE job_posts
    SET company_id = (
      SELECT company_id
      FROM company_aliases
      WHERE company_aliases.normalized_name = lower(trim(job_posts.company))
      LIMIT 1
    )
    WHERE company IS NOT NULL
      AND trim(company) != ''
      AND (
        company_id IS NULL
        OR company_id = ''
        OR company_id != (
          SELECT company_id
          FROM company_aliases
          WHERE company_aliases.normalized_name = lower(trim(job_posts.company))
          LIMIT 1
        )
      )
    """)

    refresh_company_stats(now)
  end

  def company_slug(company) do
    company
    |> to_string()
    |> String.downcase()
    |> String.replace("&", "and")
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "company"
      slug -> slug
    end
  end

  def company_path(%JobPost{company_id: company_id}) when company_id not in [nil, ""] do
    "/companies/#{company_id}"
  end

  def company_path(%JobPost{company: company}), do: company_path(company)

  def company_path(company), do: "/companies/#{company_slug(company)}"

  defp normalize_slug(slug) do
    slug
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]+/u, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  def company_stats(%JobPost{company_id: company_id, company: company})
      when company_id not in [nil, ""] do
    company_id
    |> company_stats_by_slug()
    |> case do
      nil when company not in [nil, ""] -> legacy_company_stats(company)
      nil -> empty_company_stats()
      stats -> stats
    end
  end

  def company_stats(%JobPost{company: company}) when company not in [nil, ""] do
    company
    |> company_slug()
    |> company_stats_by_slug()
    |> case do
      nil -> legacy_company_stats(company)
      stats -> stats
    end
  end

  def company_stats(_job), do: empty_company_stats()

  defp company_profile_from_record(%Company{} = company) do
    roles =
      JobPost
      |> public_scope()
      |> where([j], j.company_id == ^company.id)
      |> order_by([j], desc: j.id)
      |> limit(30)
      |> select_list_fields()
      |> Repo.all()

    %{
      name: company.name,
      slug: company.id,
      logo_url: company.logo_url,
      website_url: company.website_url,
      description: company.description,
      stats: company_stats_from_record(company),
      locations: decode_company_signals(company.top_locations_json),
      sources: decode_company_signals(company.top_sources_json),
      roles: roles
    }
  end

  defp company_stats_by_slug(slug) do
    case Repo.get(Company, slug) do
      nil -> nil
      company -> company_stats_from_record(company)
    end
  end

  defp company_stats_from_record(%Company{} = company) do
    %{
      open_jobs_count: company.open_jobs_count || 0,
      source_count: company.source_count || 0,
      location_count: company.location_count || 0,
      remote_count: company.remote_count || 0,
      salary_count: company.salary_count || 0,
      latest_posted_at: company.latest_posted_at
    }
  end

  defp legacy_company_profile_by_slug(slug) do
    base = company_slug_query(slug)

    jobs =
      base
      |> order_by([j], desc: j.id)
      |> limit(30)
      |> select_list_fields()
      |> Repo.all()

    if jobs == [] do
      nil
    else
      company = jobs |> List.first() |> Map.get(:company)

      %{
        name: company,
        slug: company_slug(company),
        logo_url: nil,
        website_url: nil,
        description: nil,
        stats: company_profile_stats(base),
        locations: company_top_values(base, :location_country, 8),
        sources: company_top_values(base, :source, 8),
        roles: jobs
      }
    end
  end

  defp legacy_sitemap_companies(limit) do
    JobPost
    |> public_scope()
    |> where([j], not is_nil(j.company) and fragment("trim(?)", j.company) != "")
    |> group_by([j], fragment("lower(trim(?))", j.company))
    |> order_by([j], desc: count(j.id))
    |> limit(^limit)
    |> select([j], %{
      name: fragment("min(trim(?))", j.company),
      slug:
        fragment(
          "lower(trim(replace(replace(replace(replace(replace(?, '.', ''), '&', 'and'), '/', '-'), ' ', '-'), '--', '-'), '-'))",
          j.company
        ),
      latest_posted_at: max(j.published_at),
      count: count(j.id)
    })
    |> Repo.all()
    |> Enum.map(fn company ->
      %{company | slug: company_slug(company.name)}
    end)
  end

  defp legacy_company_stats(company) do
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

  defp empty_company_stats do
    %{
      open_jobs_count: 0,
      source_count: 0,
      location_count: 0,
      latest_posted_at: nil
    }
  end

  defp rows_to_aliases(%{rows: rows}, now) do
    Enum.map(rows, fn [normalized_name, display_name, jobs_count] ->
      %{
        company_id: company_slug(display_name),
        normalized_name: normalized_name,
        display_name: display_name,
        jobs_count: jobs_count,
        created_at: now,
        updated_at: now
      }
    end)
  end

  defp insert_company_rows([], _opts), do: :ok

  defp insert_company_rows(rows, opts) do
    rows
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Company, chunk,
        on_conflict: Keyword.fetch!(opts, :on_conflict),
        conflict_target: :id
      )
    end)
  end

  defp insert_alias_rows([]), do: :ok

  defp insert_alias_rows(rows) do
    rows
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      Repo.insert_all("company_aliases", chunk,
        on_conflict: {:replace, [:company_id, :display_name, :jobs_count, :updated_at]},
        conflict_target: :normalized_name
      )
    end)
  end

  defp refresh_company_stats(now) do
    top_locations = top_company_values_by(:location_country)
    top_sources = top_company_values_by(:source)

    rows =
      Repo.query!(
        """
        SELECT
          company_id,
          min(trim(company)) AS name,
          count(*) AS open_jobs_count,
          COUNT(DISTINCT NULLIF(lower(trim(source)), '')) AS source_count,
          COUNT(DISTINCT NULLIF(lower(trim(location_country)), '')) AS location_count,
          SUM(CASE WHEN remote = 1 OR lower(coalesce(location_scope, '')) LIKE '%remote%' THEN 1 ELSE 0 END) AS remote_count,
          COUNT(NULLIF(salary, '')) AS salary_count,
          max(published_at) AS latest_posted_at
        FROM job_posts
        WHERE company_id IS NOT NULL
          AND company_id != ''
          AND (published_at IS NULL OR published_at = '' OR published_at >= ?)
        GROUP BY company_id
        """,
        [public_cutoff_date()]
      ).rows
      |> Enum.map(fn [
                       company_id,
                       name,
                       open_jobs_count,
                       source_count,
                       location_count,
                       remote_count,
                       salary_count,
                       latest_posted_at
                     ] ->
        %{
          id: company_id,
          name: name,
          open_jobs_count: open_jobs_count || 0,
          source_count: source_count || 0,
          location_count: location_count || 0,
          remote_count: remote_count || 0,
          salary_count: salary_count || 0,
          latest_posted_at: latest_posted_at,
          top_locations_json: Jason.encode!(Map.get(top_locations, company_id, [])),
          top_sources_json: Jason.encode!(Map.get(top_sources, company_id, [])),
          refreshed_at: now,
          created_at: now,
          updated_at: now
        }
      end)

    rows
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Company, chunk,
        on_conflict:
          {:replace,
           [
             :name,
             :open_jobs_count,
             :source_count,
             :location_count,
             :remote_count,
             :salary_count,
             :latest_posted_at,
             :top_locations_json,
             :top_sources_json,
             :refreshed_at,
             :updated_at
           ]},
        conflict_target: :id
      )
    end)

    %{companies: length(rows)}
  end

  defp top_company_values_by(field) when field in [:location_country, :source] do
    column = Atom.to_string(field)

    Repo.query!(
      """
      SELECT company_id, #{column}, count(*) AS value_count
      FROM job_posts
      WHERE company_id IS NOT NULL
        AND company_id != ''
        AND #{column} IS NOT NULL
        AND trim(#{column}) != ''
        AND (published_at IS NULL OR published_at = '' OR published_at >= ?)
      GROUP BY company_id, #{column}
      ORDER BY company_id ASC, value_count DESC, #{column} ASC
      """,
      [public_cutoff_date()]
    )
    |> Map.fetch!(:rows)
    |> Enum.reduce(%{}, fn [company_id, label, count], acc ->
      values = Map.get(acc, company_id, [])

      if length(values) >= 8 do
        acc
      else
        Map.put(acc, company_id, values ++ [%{label: label, count: count}])
      end
    end)
  end

  defp decode_company_signals(nil), do: []

  defp decode_company_signals(json) do
    json
    |> Jason.decode!()
    |> Enum.map(fn %{"label" => label, "count" => count} -> %{label: label, count: count} end)
  rescue
    _ -> []
  end

  defp company_slug_query(slug) do
    JobPost
    |> public_scope()
    |> where([j], not is_nil(j.company) and fragment("trim(?)", j.company) != "")
    |> where(
      [j],
      fragment(
        """
        lower(trim(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(
                          replace(?, '&', 'and'),
                        '''', ''),
                      '.', ''),
                    ',', ''),
                  '(', ''),
                ')', ''),
              '/', '-'),
            ' ', '-'),
          '--', '-'),
        '-'))
        """,
        j.company
      ) == ^slug
    )
  end

  defp company_profile_stats(query) do
    query
    |> select([j], %{
      open_jobs_count: count(),
      source_count: fragment("COUNT(DISTINCT NULLIF(lower(trim(?)), ''))", j.source),
      location_count: fragment("COUNT(DISTINCT NULLIF(lower(trim(?)), ''))", j.location_country),
      latest_posted_at: max(j.published_at),
      salary_count: fragment("COUNT(NULLIF(?, ''))", j.salary),
      remote_count:
        fragment(
          "SUM(CASE WHEN ? = 1 OR lower(coalesce(?, '')) LIKE '%remote%' THEN 1 ELSE 0 END)",
          j.remote,
          j.location_scope
        )
    })
    |> Repo.one()
  end

  defp company_top_values(query, field, limit) when field in [:location_country, :source] do
    query
    |> where([j], not is_nil(field(j, ^field)) and fragment("trim(?)", field(j, ^field)) != "")
    |> group_by([j], field(j, ^field))
    |> order_by([j], desc: count(j.id), asc: field(j, ^field))
    |> limit(^limit)
    |> select([j], %{label: field(j, ^field), count: count(j.id)})
    |> Repo.all()
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

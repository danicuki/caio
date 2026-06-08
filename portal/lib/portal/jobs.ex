defmodule Portal.Jobs do
  import Ecto.Query

  alias Portal.Jobs.Company
  alias Portal.Jobs.JobPost
  alias Portal.Jobs.JobUrlOverride
  alias Portal.Repo

  @guest_limit 10
  @guest_preview 18
  @member_limit 50
  @browse_result_limit 10_000
  @job_sitemap_range_size 10_000
  @sitemap_url_limit 50_000
  @sitemap_refresh_opts [timeout: :infinity]
  @home_cache_table :portal_home_jobs_cache
  @home_cache_key :snapshot
  @home_cache_ttl_ms 120_000
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
  def page_size(true), do: @member_limit
  def page_size(false), do: @guest_preview
  def browse_result_limit, do: @browse_result_limit

  def max_page(total, per_page) when is_integer(total) and total > 0,
    do: total |> Kernel./(per_page) |> Float.ceil() |> trunc()

  def max_page(total, _per_page) when is_integer(total), do: 1

  def max_page(_capped_total, per_page),
    do: @browse_result_limit |> Kernel./(per_page) |> Float.ceil() |> trunc()

  def home_snapshot(limit \\ 6) do
    case cached_home_snapshot() do
      {:ok, snapshot} ->
        snapshot

      :miss ->
        stats = homepage_stats()

        snapshot = %{
          total_count: stats.open_jobs_count,
          stats: stats,
          sample_jobs: homepage_sample(limit)
        }

        put_cached_home_snapshot(snapshot)
        snapshot
    end
  end

  def total_count do
    JobPost
    |> public_scope()
    |> select([j], count(j.id))
    |> Repo.one()
  end

  def search(params, unlocked?) do
    limit = page_size(unlocked?)
    offset = (if(unlocked?, do: page(params), else: 1) - 1) * limit

    JobPost
    |> public_scope()
    |> base_filters(params)
    |> apply_order(params)
    |> offset(^offset)
    |> limit(^limit)
    |> select_list_fields()
    |> Repo.all()
  end

  def page(%{"page" => value}) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  def page(_params), do: 1

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

  def homepage_total_count do
    homepage_stats().open_jobs_count
  end

  def homepage_stats do
    stats = company_homepage_stats()

    if stats.company_count > 0 do
      stats
    else
      job_homepage_stats()
    end
  end

  def homepage_sample(limit \\ 6) do
    JobPost
    |> public_scope()
    |> order_by([j], desc: j.id)
    |> limit(^limit)
    |> select_list_fields()
    |> Repo.all()
  end

  defp company_homepage_stats do
    Company
    |> where([c], c.open_jobs_count > 0)
    |> exclude_noisy_companies()
    |> select([c], %{
      company_count: count(c.id),
      open_jobs_count: fragment("COALESCE(SUM(?), 0)", c.open_jobs_count),
      remote_count: fragment("COALESCE(SUM(?), 0)", c.remote_count),
      salary_count: fragment("COALESCE(SUM(?), 0)", c.salary_count),
      latest_posted_at: max(c.latest_posted_at)
    })
    |> Repo.one()
    |> normalize_homepage_stats()
  end

  defp job_homepage_stats do
    JobPost
    |> public_scope()
    |> select([j], %{
      company_count: fragment("COUNT(DISTINCT NULLIF(lower(trim(?)), ''))", j.company),
      open_jobs_count: count(j.id),
      remote_count:
        fragment(
          "SUM(CASE WHEN ? = 1 OR lower(coalesce(?, '')) LIKE '%remote%' THEN 1 ELSE 0 END)",
          j.remote,
          j.location_scope
        ),
      salary_count:
        fragment(
          "SUM(CASE WHEN ? IS NOT NULL OR ? IS NOT NULL OR trim(coalesce(?, '')) != '' THEN 1 ELSE 0 END)",
          j.salary_min,
          j.salary_max,
          j.salary
        ),
      latest_posted_at: max(j.published_at)
    })
    |> Repo.one()
    |> normalize_homepage_stats()
  end

  defp normalize_homepage_stats(nil) do
    %{
      company_count: 0,
      open_jobs_count: 0,
      remote_count: 0,
      salary_count: 0,
      latest_posted_at: nil
    }
  end

  defp normalize_homepage_stats(stats) do
    %{
      company_count: stats.company_count || 0,
      open_jobs_count: stats.open_jobs_count || 0,
      remote_count: stats.remote_count || 0,
      salary_count: stats.salary_count || 0,
      latest_posted_at: stats.latest_posted_at
    }
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
    |> with_company_cache()
    |> select([j, a, c], j)
    |> select_merge([j, a, c], %{
      company_id: coalesce(j.company_id, a.company_id),
      company_logo_url: c.logo_url
    })
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
      |> exclude_noisy_companies()
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

  def job_sitemap_range_size, do: @job_sitemap_range_size

  def job_sitemap_ranges(range_size \\ @job_sitemap_range_size) do
    max_id = max_job_post_id()

    if max_id <= 0 do
      []
    else
      1
      |> Stream.iterate(&(&1 + range_size))
      |> Enum.take_while(&(&1 <= max_id))
      |> Enum.map(fn first_id ->
        %{first_id: first_id, last_id: first_id + range_size - 1}
      end)
    end
  end

  def sitemap_jobs_in_id_range(first_id, last_id) do
    first_id = max(first_id, 1)
    last_id = min(max(last_id, first_id), first_id + @job_sitemap_range_size - 1)

    JobPost
    |> public_scope()
    |> where([j], j.id >= ^first_id and j.id <= ^last_id)
    |> limit(^@job_sitemap_range_size)
    |> select([j], %{
      id: j.id,
      published_at: j.published_at,
      updated_at: j.updated_at
    })
    |> Repo.all()
  end

  def sitemap_locations(limit \\ @sitemap_url_limit) do
    sitemap_facets("location", limit)
  end

  def sitemap_keywords(limit \\ @sitemap_url_limit) do
    sitemap_facets("keyword", limit)
  end

  def top_hiring_companies(limit \\ 24), do: sitemap_companies(limit)

  def top_search_keywords(limit \\ 32) do
    case sitemap_keywords(limit) do
      [] -> sitemap_categories(limit)
      keywords -> keywords
    end
  end

  def refresh_sitemap_facets do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    locations = location_sitemap_rows()
    keywords = keyword_sitemap_rows()

    Repo.transaction(
      fn ->
        refresh_sitemap_facet("location", locations, now)
        refresh_sitemap_facet("keyword", keywords, now)
      end,
      @sitemap_refresh_opts
    )

    %{locations: length(locations), keywords: length(keywords)}
  end

  defp sitemap_facets(facet, limit) do
    Repo.query!(
      """
      SELECT label, jobs_count, latest_posted_at
      FROM sitemap_facets
      WHERE facet = ?
      ORDER BY jobs_count DESC, label ASC
      LIMIT ?
      """,
      [facet, limit]
    )
    |> Map.fetch!(:rows)
    |> Enum.map(fn [label, count, latest_posted_at] ->
      %{label: label, count: count, latest_posted_at: latest_posted_at}
    end)
    |> reject_non_tech_facets()
  end

  defp refresh_sitemap_facet(facet, rows, now) do
    Repo.query!("DELETE FROM sitemap_facets WHERE facet = ?", [facet], @sitemap_refresh_opts)

    rows
    |> Enum.map(fn %{label: label, count: count, latest_posted_at: latest_posted_at} ->
      %{
        facet: facet,
        label: label,
        jobs_count: count,
        latest_posted_at: latest_posted_at,
        refreshed_at: now
      }
    end)
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      Repo.insert_all("sitemap_facets", chunk, @sitemap_refresh_opts)
    end)
  end

  defp location_sitemap_rows(limit \\ @sitemap_url_limit) do
    Repo.query!(
      """
      SELECT
        trim(location_city) AS label,
        count(*) AS jobs_count,
        max(published_at) AS latest_posted_at
      FROM job_posts
      WHERE location_city IS NOT NULL
        AND trim(location_city) != ''
        AND (published_at IS NULL OR published_at = '' OR published_at >= ?)
      GROUP BY lower(trim(location_city))
      HAVING jobs_count >= 2
      ORDER BY jobs_count DESC, label ASC
      LIMIT ?
      """,
      [public_cutoff_date(), limit],
      @sitemap_refresh_opts
    )
    |> Map.fetch!(:rows)
    |> Enum.map(fn [label, count, latest_posted_at] ->
      %{label: label, count: count, latest_posted_at: latest_posted_at}
    end)
  end

  defp keyword_sitemap_rows(limit \\ @sitemap_url_limit) do
    Repo.query!(
      """
      SELECT
        label,
        count(*) AS jobs_count,
        max(published_at) AS latest_posted_at
      FROM (
        SELECT trim(category) AS label, published_at
        FROM job_posts
        WHERE category IS NOT NULL
          AND trim(category) != ''
          AND (published_at IS NULL OR published_at = '' OR published_at >= ?)

        UNION ALL

        SELECT
          trim(
            CASE json_each.type
              WHEN 'text' THEN json_each.value
              WHEN 'object' THEN COALESCE(
                json_extract(json_each.value, '$.name'),
                replace(json_extract(json_each.value, '$.short_name'), '-', ' ')
              )
              ELSE NULL
            END
          ) AS label,
          job_posts.published_at
        FROM job_posts,
          json_each(
            CASE
              WHEN json_valid(job_posts.tags_json) THEN job_posts.tags_json
              ELSE '[]'
            END
          )
        WHERE job_posts.tags_json IS NOT NULL
          AND job_posts.tags_json != ''
          AND (job_posts.published_at IS NULL OR job_posts.published_at = '' OR job_posts.published_at >= ?)
      )
      WHERE label IS NOT NULL
        AND label != ''
        AND length(label) BETWEEN 2 AND 60
      GROUP BY lower(label)
      HAVING jobs_count >= 3
      ORDER BY jobs_count DESC, label ASC
      LIMIT ?
      """,
      [public_cutoff_date(), public_cutoff_date(), limit],
      @sitemap_refresh_opts
    )
    |> Map.fetch!(:rows)
    |> Enum.map(fn [label, count, latest_posted_at] ->
      %{label: label, count: count, latest_posted_at: latest_posted_at}
    end)
  rescue
    Exqlite.Error ->
      sitemap_categories(limit)
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

  def refresh_company_logos(opts \\ []) do
    force? = Keyword.get(opts, :force, false)
    limit = Keyword.get(opts, :limit)
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    domain_by_company_id =
      Repo.query!("""
      SELECT COALESCE(j.company_id, a.company_id) AS company_id, j.source_url
      FROM job_posts j
      LEFT JOIN company_aliases a
        ON a.normalized_name = lower(trim(j.company))
      WHERE COALESCE(j.company_id, a.company_id) IS NOT NULL
        AND COALESCE(j.company_id, a.company_id) != ''
        AND j.source_url IS NOT NULL
        AND j.source_url != ''
      """)
      |> Map.fetch!(:rows)
      |> Enum.reduce(%{}, fn [company_id, source_url], acc ->
        case logo_domain_from_url(source_url) do
          nil ->
            acc

          domain ->
            Map.update(acc, company_id, %{domain => 1}, fn domain_counts ->
              Map.update(domain_counts, domain, 1, &(&1 + 1))
            end)
        end
      end)
      |> Map.new(fn {company_id, domain_counts} ->
        {domain, _count} = Enum.max_by(domain_counts, fn {_domain, count} -> count end)
        {company_id, domain}
      end)

    companies_with_domains =
      Company
      |> where([c], c.open_jobs_count > 0)
      |> maybe_missing_logo_filter(force?)
      |> select([c], {c.id, c.name})
      |> Repo.all()
      |> Enum.map(fn {company_id, name} ->
        {company_id, Map.get(domain_by_company_id, company_id) || guessed_logo_domain(name)}
      end)
      |> Enum.reject(fn {_company_id, domain} -> is_nil(domain) end)
      |> maybe_limit(limit)

    Enum.reduce(companies_with_domains, %{companies: 0}, fn {company_id, domain}, acc ->
      query =
        Company
        |> where([c], c.id == ^company_id)
        |> maybe_missing_logo_filter(force?)

      {count, _} =
        Repo.update_all(query,
          set: [
            website_url: "https://#{domain}",
            logo_url: logo_url_for_domain(domain),
            updated_at: now
          ]
        )

      %{acc | companies: acc.companies + count}
    end)
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

  def logo_url_for_domain(domain) do
    "https://www.google.com/s2/favicons?domain=#{URI.encode_www_form(domain)}&sz=128"
  end

  def logo_url_for_company(company_name) when company_name not in [nil, ""] do
    company_name
    |> guessed_logo_domain()
    |> case do
      nil -> nil
      domain -> logo_url_for_domain(domain)
    end
  end

  def logo_url_for_company(_company_name), do: nil

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

  defp sitemap_categories(limit) do
    JobPost
    |> public_scope()
    |> where([j], not is_nil(j.category) and fragment("trim(?)", j.category) != "")
    |> group_by([j], fragment("lower(trim(?))", j.category))
    |> having([j], count(j.id) >= 3)
    |> order_by([j], desc: count(j.id), asc: fragment("min(trim(?))", j.category))
    |> limit(^limit)
    |> select([j], %{
      label: fragment("min(trim(?))", j.category),
      count: count(j.id),
      latest_posted_at: max(j.published_at)
    })
    |> Repo.all()
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

  defp logo_domain_from_url(source_url) do
    with %URI{host: host} when is_binary(host) <- URI.parse(source_url),
         domain when not is_nil(domain) <- registrable_domain(host),
         false <- ignored_logo_domain?(domain) do
      domain
    else
      _ -> nil
    end
  end

  defp guessed_logo_domain(company_name) do
    company_name
    |> to_string()
    |> String.downcase()
    |> String.replace("&", "and")
    |> String.replace(
      ~r/\b(inc|incorporated|llc|ltd|limited|gmbh|ag|sa|plc|corp|corporation|co|company)\b\.?/u,
      " "
    )
    |> String.replace(~r/[^a-z0-9]+/u, "")
    |> case do
      "" -> nil
      domain -> "#{domain}.com"
    end
  end

  defp registrable_domain(host) do
    host =
      host
      |> String.downcase()
      |> String.trim_leading("www.")

    parts = String.split(host, ".", trim: true)

    cond do
      length(parts) < 2 ->
        nil

      length(parts) >= 3 and Enum.join(Enum.take(parts, -2), ".") in common_second_level_tlds() ->
        parts |> Enum.take(-3) |> Enum.join(".")

      true ->
        parts |> Enum.take(-2) |> Enum.join(".")
    end
  end

  defp common_second_level_tlds do
    ~w(
      co.uk com.au com.br com.mx com.sg com.tr co.jp co.kr co.nz co.za
      com.ar com.co com.pl com.pt com.ng
    )
  end

  defp ignored_logo_domain?(domain) do
    domain in ~w(
      angel.co applicantai.com applytojob.com arbeitnow.com ashbyhq.com bamboohr.com breezy.hr
      builtin.com careerplug.com comeet.co greenhouse.io greenhouse.io
      getonbrd.com himalayas.app indeed.com jobicy.com jobs.lever.co lever.co linkedin.com
      remoteok.com remotive.com recruitee.com smartrecruiters.com themuse.com
      remotejobs.org workable.com workdayjobs.com web3.career ziprecruiter.com
    )
  end

  defp maybe_limit(items, nil), do: items
  defp maybe_limit(items, limit), do: Enum.take(items, limit)

  defp maybe_missing_logo_filter(query, true), do: query

  defp maybe_missing_logo_filter(query, false) do
    where(query, [c], is_nil(c.logo_url) or c.logo_url == "")
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

    query
    |> exclude_noisy_job_companies()
    |> where(
      [j],
      is_nil(j.published_at) or j.published_at == "" or j.published_at >= ^cutoff
    )
  end

  defp exclude_noisy_job_companies(query) do
    where(
      query,
      [j],
      (is_nil(j.company) or j.company not in ^noisy_job_company_names()) and
        (is_nil(j.category) or j.category not in ^noisy_job_categories()) and
        (is_nil(j.title) or j.title not in ^noisy_job_titles())
    )
  end

  defp exclude_noisy_companies(query) do
    where(
      query,
      [c],
      c.id not in ^noisy_company_ids() and
        fragment("lower(trim(?))", c.name) not in ^noisy_company_names()
    )
  end

  defp noisy_company_ids do
    ~w(
      boschgroup bosch-group dominos domino-s jobgether cityofnewyork
      sgs jysk eurofins abbvie alten securitas redbull kreyco
      insurance-office-of-america
    )
  end

  defp noisy_job_company_names do
    [
      "BoschGroup",
      "Bosch Group",
      "DominoS",
      "Domino's",
      "Jobgether",
      "CityOfNewYork",
      "City of New York",
      "SGS",
      "JYSK",
      "Eurofins",
      "AbbVie",
      "ALTEN",
      "Securitas",
      "RedBull",
      "Red Bull",
      "Kreyco",
      "Insurance Office of America"
    ]
  end

  defp noisy_job_categories do
    [
      "Mechanical Engineering",
      "Mechanical Or Industrial Engineering",
      "Industrial Engineering",
      "Mechanical Design",
      "General Business",
      "Restaurants",
      "Manufacturing",
      "Supply Chain",
      "Human Resources",
      "Accounting/Auditing"
    ]
  end

  defp noisy_job_titles do
    [
      "Mechanical Engineer",
      "Industrial Engineer",
      "CAD Designer",
      "Delivery Driver",
      "Customer Service Rep",
      "Warehouse Order Selector"
    ]
  end

  defp noisy_company_names do
    [
      "boschgroup",
      "bosch group",
      "dominos",
      "domino's",
      "jobgether",
      "cityofnewyork",
      "city of new york",
      "sgs",
      "jysk",
      "eurofins",
      "abbvie",
      "alten",
      "securitas",
      "redbull",
      "red bull",
      "kreyco",
      "insurance office of america"
    ]
  end

  defp reject_non_tech_facets(rows) do
    Enum.reject(rows, fn %{label: label} -> non_tech_facet?(label) end)
  end

  defp non_tech_facet?(label) do
    label =
      label
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[-_+]+/, " ")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    Enum.any?(non_tech_facet_phrases(), &String.contains?(label, &1))
  end

  defp non_tech_facet_phrases do
    [
      "mechanical or industrial engineering",
      "mechanical engineering",
      "industrial engineering",
      "mechanical design",
      "manufacturing",
      "general business",
      "restaurant",
      "restaurants",
      "hvac",
      "building services",
      "civil engineering",
      "construction",
      "retail",
      "hospitality",
      "food service",
      "healthcare",
      "nursing",
      "legal",
      "accounting",
      "human resources",
      "supply chain",
      "warehouse",
      "logistics"
    ]
  end

  defp public_cutoff_date do
    Date.utc_today()
    |> Date.add(-183)
    |> Date.to_iso8601()
  end

  defp max_job_post_id do
    JobPost
    |> select([j], max(j.id))
    |> Repo.one() || 0
  end

  defp normalize_company(company) do
    company
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp select_list_fields(query) do
    query
    |> with_company_cache()
    |> select([j, a, c], struct(j, ^@list_fields))
    |> select_merge([j, a, c], %{
      company_id: coalesce(j.company_id, a.company_id),
      company_logo_url: c.logo_url
    })
  end

  defp with_company_cache(query) do
    query
    |> join(:left, [j], a in "company_aliases",
      on: a.normalized_name == fragment("lower(trim(?))", j.company)
    )
    |> join(:left, [j, a], c in Company, on: c.id == coalesce(j.company_id, a.company_id))
  end

  defp limited_count(query, cap \\ @browse_result_limit) do
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
    |> seniority_filter(params["seniority"])
    |> workplace_filter(params["workplace"])
    |> salary_filter(params["salary"])
    |> perk_filter(params["perk"])
  end

  defp apply_order(query, %{"order" => "random"}) do
    order_by(query, [j], fragment("random()"))
  end

  defp apply_order(query, _params) do
    order_by(query, [j], desc: j.published_at, desc: j.id)
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

  defp seniority_filter(query, value) when value in [nil, ""], do: query

  defp seniority_filter(query, "junior") do
    where(query, [j], fragment("lower(coalesce(?, '')) LIKE ?", j.title, ^"%junior%"))
  end

  defp seniority_filter(query, "mid") do
    where(
      query,
      [j],
      fragment(
        "lower(coalesce(?, '')) LIKE ? OR lower(coalesce(?, '')) LIKE ?",
        j.title,
        ^"%mid%",
        j.title,
        ^"%intermediate%"
      )
    )
  end

  defp seniority_filter(query, "senior") do
    where(query, [j], fragment("lower(coalesce(?, '')) LIKE ?", j.title, ^"%senior%"))
  end

  defp seniority_filter(query, "staff") do
    where(
      query,
      [j],
      fragment(
        "lower(coalesce(?, '')) LIKE ? OR lower(coalesce(?, '')) LIKE ?",
        j.title,
        ^"%staff%",
        j.title,
        ^"%principal%"
      )
    )
  end

  defp seniority_filter(query, _value), do: query

  defp workplace_filter(query, value) when value in [nil, ""], do: query

  defp workplace_filter(query, "remote") do
    where(
      query,
      [j],
      j.remote == 1 or
        fragment("lower(coalesce(?, ''))", j.location_scope) == "remote" or
        fragment("lower(coalesce(?, '')) LIKE ?", j.location, ^"%remote%")
    )
  end

  defp workplace_filter(query, "hybrid") do
    where(query, [j], fragment("lower(coalesce(?, '')) LIKE ?", j.location, ^"%hybrid%"))
  end

  defp workplace_filter(query, "office") do
    where(
      query,
      [j],
      not (j.remote == 1) and
        fragment("lower(coalesce(?, '')) NOT LIKE ?", j.location, ^"%remote%") and
        fragment("lower(coalesce(?, '')) NOT LIKE ?", j.location, ^"%hybrid%")
    )
  end

  defp workplace_filter(query, _value), do: query

  defp salary_filter(query, "listed") do
    where(
      query,
      [j],
      not is_nil(j.salary_min) or not is_nil(j.salary_max) or
        fragment("trim(coalesce(?, '')) != ''", j.salary)
    )
  end

  defp salary_filter(query, _value), do: query

  defp perk_filter(query, value) when value in [nil, ""], do: query

  defp perk_filter(query, "visa"), do: text_search(query, "visa sponsorship")
  defp perk_filter(query, "equity"), do: text_search(query, "equity stock options")
  defp perk_filter(query, _value), do: query

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

  defp cached_home_snapshot do
    ensure_home_cache_table()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@home_cache_table, @home_cache_key) do
      [{@home_cache_key, timestamp, snapshot}] when now - timestamp < @home_cache_ttl_ms ->
        {:ok, snapshot}

      _ ->
        :miss
    end
  end

  defp put_cached_home_snapshot(snapshot) do
    ensure_home_cache_table()

    :ets.insert(
      @home_cache_table,
      {@home_cache_key, System.monotonic_time(:millisecond), snapshot}
    )
  end

  defp ensure_home_cache_table do
    :ets.new(@home_cache_table, [
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  rescue
    ArgumentError -> :ok
  end
end

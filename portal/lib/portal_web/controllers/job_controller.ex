defmodule PortalWeb.JobController do
  use PortalWeb, :controller

  alias Portal.Analytics
  alias Portal.Accounts
  alias Portal.Jobs

  def index(conn, params) do
    conn = ensure_session_token(conn)
    lead = current_lead(conn)
    unlocked? = not is_nil(lead)
    total = Jobs.count(params)
    per_page = Jobs.page_size(unlocked?)
    requested_page = if(unlocked?, do: Jobs.page(params), else: 1)
    page = min(requested_page, Jobs.max_page(total, per_page))

    if unlocked? and requested_page != page do
      redirect(conn, to: page_path(params, page))
    else
      params = Map.put(params, "page", Integer.to_string(page))
      jobs = Jobs.search(params, unlocked?)
      has_prev_page? = unlocked? and page > 1
      has_next_page? = unlocked? and next_page?(jobs, total, page, per_page)

      Analytics.capture("jobs_search_viewed", analytics_id(conn, lead), %{
        query: params["q"],
        role: params["role"],
        company: params["company"],
        location: params["location"],
        order: params["order"],
        result_count: total,
        unlocked: unlocked?
      })

      render(conn, :index,
        page_title: search_page_title(params),
        meta_description: search_meta_description(params, total),
        canonical_path: search_canonical_path(params),
        robots: search_robots(params),
        json_ld: search_json_ld(params, total),
        analytics_distinct_id: analytics_id(conn, lead),
        jobs: jobs,
        params: params,
        total: total,
        lead: lead,
        unlocked?: unlocked?,
        guest_limit: Jobs.guest_limit(),
        page: page,
        per_page: per_page,
        has_prev_page?: has_prev_page?,
        has_next_page?: has_next_page?,
        prev_page_path: if(has_prev_page?, do: page_path(params, page - 1)),
        next_page_path: if(has_next_page?, do: page_path(params, page + 1)),
        quick_filter_groups: quick_filter_groups(params),
        mobile_filter_chips: mobile_filter_chips(params)
      )
    end
  end

  def show(conn, %{"id" => id}) do
    conn = ensure_session_token(conn)
    job = Jobs.get!(id)
    lead = current_lead(conn)

    Analytics.capture("job_detail_viewed", analytics_id(conn, lead), %{
      job_id: job.id,
      source: job.source,
      company: job.company,
      has_salary: not is_nil(PortalWeb.JobHTML.salary(job))
    })

    conn
    |> put_resp_header("cache-tag", job_cache_tags(job))
    |> render(:show,
      page_title: job_page_title(job),
      meta_description: job_meta_description(job),
      canonical_path: ~p"/jobs/#{job.id}",
      og_type: "article",
      json_ld: job_json_ld(job),
      analytics_distinct_id: analytics_id(conn, lead),
      job: job,
      company_stats: Jobs.company_stats(job),
      lead: lead,
      session_token: session_token(conn)
    )
  end

  def apply(conn, %{"id" => id}) do
    job = Jobs.get!(id)
    apply_url = Jobs.apply_url(job)

    case lead_for_apply(conn, Map.get(conn.params, "lead", %{})) do
      {:ok, conn, lead} ->
        Accounts.record_interest(%{
          lead_id: lead.id,
          job_post_id: job.id,
          session_token: session_token(conn),
          source_url: apply_url
        })

        Analytics.capture("job_apply_clicked", analytics_id(conn, lead), %{
          job_id: job.id,
          source: job.source,
          company: job.company,
          has_session_lead: not is_nil(get_session(conn, :lead_id))
        })

        redirect(conn, external: apply_url)

      {:error, changeset} ->
        Analytics.capture("job_apply_lead_failed", session_token(conn), %{
          job_id: job.id,
          reason: "validation"
        })

        conn
        |> put_flash(:error, first_error(changeset))
        |> redirect(to: ~p"/jobs/#{job.id}")
    end
  end

  defp current_lead(conn), do: Accounts.get_lead(get_session(conn, :lead_id))

  defp lead_for_apply(conn, lead_params) do
    case current_lead(conn) do
      nil -> create_apply_lead(conn, lead_params)
      lead -> {:ok, ensure_session_token(conn), lead}
    end
  end

  defp create_apply_lead(conn, lead_params) do
    case Accounts.upsert_lead(lead_params) do
      {:ok, lead} ->
        conn =
          conn
          |> put_session(:lead_id, lead.id)
          |> ensure_session_token()

        {:ok, conn, lead}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp ensure_session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> put_session(conn, :session_token, Ecto.UUID.generate())
      _ -> conn
    end
  end

  defp session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> nil
      token -> token
    end
  end

  defp analytics_id(conn, nil), do: "session:#{get_session(conn, :session_token)}"
  defp analytics_id(conn, lead), do: "lead:#{lead.id}:#{get_session(conn, :session_token)}"

  defp search_page_title(params) do
    subject = search_subject(params)

    case clean_param(params["location"]) do
      nil -> sentence_case("#{subject} jobs")
      location -> sentence_case("#{subject} jobs in #{location}")
    end
  end

  defp search_meta_description(params, total) do
    subject = search_subject(params)
    location = clean_param(params["location"])
    company = clean_param(params["company"])
    count = total |> to_string() |> String.replace("+", "+ matching")

    scope =
      cond do
        company && location -> " at #{company} in #{location}"
        company -> " at #{company}"
        location -> " in #{location}"
        true -> ""
      end

    "Search #{count} #{subject} jobs#{scope} on Caio. Compare company, salary, location, source, and posting-date details before applying."
  end

  defp search_canonical_path(params) do
    query =
      [
        {"q", clean_param(params["q"])},
        {"role", clean_param(params["role"])},
        {"company", clean_param(params["company"])},
        {"location", clean_param(params["location"])},
        {"seniority", clean_param(params["seniority"])},
        {"workplace", clean_param(params["workplace"])},
        {"salary", clean_param(params["salary"])},
        {"perk", clean_param(params["perk"])}
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> URI.encode_query()

    if query == "", do: "/jobs", else: "/jobs?#{query}"
  end

  defp search_robots(params) do
    index_affecting_keys = ~w(q role company location seniority workplace salary perk order)
    has_filters? = Enum.any?(index_affecting_keys, &(clean_param(params[&1]) != nil))
    paginated? = Jobs.page(params) > 1

    if has_filters? or paginated?, do: "noindex,follow"
  end

  defp search_subject(params) do
    clean_param(params["q"]) || clean_param(params["role"]) || "tech"
  end

  defp clean_param(value) when is_binary(value) do
    value
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp clean_param(_value), do: nil

  defp next_page?(jobs, total, page, per_page) when is_integer(total) do
    page * per_page < total and length(jobs) == per_page
  end

  defp next_page?(jobs, _total, _page, per_page), do: length(jobs) == per_page

  defp page_path(params, page) do
    query =
      params
      |> Map.drop(["_csrf_token"])
      |> Map.put("page", Integer.to_string(page))
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> URI.encode_query()

    if query == "", do: "/jobs", else: "/jobs?#{query}"
  end

  defp mobile_filter_chips(params) do
    [
      %{label: "Remote", key: "workplace", value: "remote"},
      %{label: "Salary listed", key: "salary", value: "listed"},
      %{label: "Visa friendly", key: "perk", value: "visa"},
      %{label: "Senior", key: "seniority", value: "senior"}
    ]
    |> Enum.map(&quick_filter(params, &1))
  end

  defp quick_filter_groups(params) do
    [
      %{
        label: "Role family",
        filters: [
          %{label: "Engineering", key: "role", value: "engineer"},
          %{label: "Design", key: "role", value: "designer"},
          %{label: "Data", key: "role", value: "data"}
        ]
      },
      %{
        label: "Seniority",
        filters: [
          %{label: "Junior", key: "seniority", value: "junior"},
          %{label: "Mid-level", key: "seniority", value: "mid"},
          %{label: "Senior", key: "seniority", value: "senior"},
          %{label: "Staff+", key: "seniority", value: "staff"}
        ]
      },
      %{
        label: "Workplace",
        filters: [
          %{label: "Remote", key: "workplace", value: "remote"},
          %{label: "Hybrid", key: "workplace", value: "hybrid"},
          %{label: "Office", key: "workplace", value: "office"}
        ]
      },
      %{
        label: "Perks",
        filters: [
          %{label: "Visa sponsorship", key: "perk", value: "visa"},
          %{label: "Equity", key: "perk", value: "equity"},
          %{label: "Salary listed", key: "salary", value: "listed"}
        ]
      }
    ]
    |> Enum.map(fn group ->
      Map.update!(group, :filters, &Enum.map(&1, fn filter -> quick_filter(params, filter) end))
    end)
  end

  defp quick_filter(params, filter) do
    active? = clean_param(params[filter.key]) == filter.value

    filter
    |> Map.put(:active?, active?)
    |> Map.put(:path, filter_path(params, filter, active?))
  end

  defp filter_path(params, filter, true) do
    params
    |> Map.drop(["_csrf_token", "page", filter.key])
    |> encode_jobs_query()
  end

  defp filter_path(params, filter, false) do
    params
    |> Map.drop(["_csrf_token", "page"])
    |> Map.put(filter.key, filter.value)
    |> encode_jobs_query()
  end

  defp encode_jobs_query(params) do
    query =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> URI.encode_query()

    if query == "", do: "/jobs", else: "/jobs?#{query}"
  end

  defp sentence_case(value) do
    value
    |> String.trim()
    |> String.replace_prefix(String.first(value) || "", String.upcase(String.first(value) || ""))
  end

  defp job_page_title(job), do: "#{job.title} at #{job.company || "a tech company"}"

  defp job_cache_tags(job) do
    ["jobs", "job-#{job.id}", company_cache_tag(job)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(",")
  end

  defp company_cache_tag(%{company_id: company_id}) when company_id not in [nil, ""] do
    "company-#{company_id}"
  end

  defp company_cache_tag(_job), do: nil

  defp job_meta_description(job) do
    location = PortalWeb.JobHTML.compact_location(job)
    salary = PortalWeb.JobHTML.salary(job) || "salary not listed"

    "#{job.title} at #{job.company || "a tech company"} in #{location}. #{salary}. Open the original posting from Caio."
  end

  defp search_json_ld(params, total) do
    %{
      "@context" => "https://schema.org",
      "@type" => "SearchResultsPage",
      "name" => "#{search_page_title(params)} · Caio",
      "description" => search_meta_description(params, total),
      "url" => PortalWeb.PageHTML.absolute_url(search_canonical_path(params)),
      "isPartOf" => %{
        "@type" => "WebSite",
        "name" => "Caio",
        "url" => PortalWeb.PageHTML.absolute_url("/")
      }
    }
  end

  defp job_json_ld(job) do
    job_location = job_location_json_ld(job)
    applicant_location_requirements = applicant_location_requirements_json_ld(job)

    if fresh_for_job_markup?(job) && (job_location || applicant_location_requirements) do
      %{
        "@context" => "https://schema.org",
        "@type" => "JobPosting",
        "title" => job.title,
        "description" => PortalWeb.JobHTML.clean_description(job.description),
        "datePosted" => published_date(job),
        "employmentType" => job.employment_type,
        "hiringOrganization" => %{
          "@type" => "Organization",
          "name" => job.company || "Company",
          "logo" => PortalWeb.JobHTML.company_logo_url(job),
          "sameAs" => PortalWeb.PageHTML.absolute_url(Jobs.company_path(job))
        },
        "jobLocationType" =>
          if(PortalWeb.JobHTML.remote_label(job), do: "TELECOMMUTE", else: nil),
        "jobLocation" => job_location,
        "applicantLocationRequirements" => applicant_location_requirements,
        "baseSalary" => salary_json_ld(job),
        "validThrough" => valid_through(job),
        "url" => PortalWeb.PageHTML.absolute_url("/jobs/#{job.id}")
      }
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()
    end
  end

  defp fresh_for_job_markup?(job) do
    case Date.from_iso8601(published_date(job)) do
      {:ok, date} -> Date.diff(Date.utc_today(), date) <= 90
      _ -> false
    end
  end

  defp published_date(job) do
    [Map.get(job, :published_at), Map.get(job, :created_at), Map.get(job, :updated_at)]
    |> Enum.find_value(&iso_date/1)
    |> case do
      nil -> Date.utc_today() |> Date.to_iso8601()
      date -> date
    end
  end

  defp iso_date(value) when value in [nil, ""], do: nil

  defp iso_date(value) do
    value
    |> to_string()
    |> String.slice(0, 10)
    |> Date.from_iso8601()
    |> case do
      {:ok, date} -> Date.to_iso8601(date)
      _ -> nil
    end
  end

  defp valid_through(job) do
    job
    |> published_date()
    |> Date.from_iso8601()
    |> case do
      {:ok, date} ->
        date
        |> Date.add(90)
        |> DateTime.new!(~T[23:59:59], "Etc/UTC")
        |> DateTime.to_iso8601()

      _ ->
        nil
    end
  end

  defp job_location_json_ld(%{location_country: country} = job) when country not in [nil, ""] do
    %{
      "@type" => "Place",
      "address" =>
        %{
          "@type" => "PostalAddress",
          "addressLocality" => Map.get(job, :location_city),
          "addressRegion" => location_region(job),
          "addressCountry" => country
        }
        |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
        |> Map.new()
    }
  end

  defp job_location_json_ld(_job), do: nil

  defp applicant_location_requirements_json_ld(job) do
    if PortalWeb.JobHTML.remote_label(job) do
      country = applicant_country(job)

      if country do
        %{
          "@type" => "Country",
          "name" => country
        }
      end
    end
  end

  defp applicant_country(%{location_country: country}) when country not in [nil, ""], do: country

  defp applicant_country(%{location: location}) when location not in [nil, ""] do
    cond do
      String.contains?(String.downcase(location), ["united states", " usa", "us only"]) -> "US"
      String.contains?(String.downcase(location), ["brazil", "brasil"]) -> "BR"
      String.contains?(String.downcase(location), "canada") -> "CA"
      String.contains?(String.downcase(location), ["united kingdom", " uk"]) -> "GB"
      String.contains?(String.downcase(location), ["europe", "emea"]) -> "EU"
      true -> "Worldwide"
    end
  end

  defp applicant_country(_job), do: "Worldwide"

  defp location_region(%{location_state: state}) when state not in [nil, ""], do: state
  defp location_region(_job), do: nil

  defp salary_json_ld(%{salary_min: min, salary_max: max, salary_currency: currency})
       when not is_nil(min) or not is_nil(max) do
    %{
      "@type" => "MonetaryAmount",
      "currency" => currency || "USD",
      "value" => %{
        "@type" => "QuantitativeValue",
        "minValue" => min,
        "maxValue" => max
      }
    }
  end

  defp salary_json_ld(_job), do: nil

  defp first_error(changeset) do
    {field, {message, _}} = List.first(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end
end

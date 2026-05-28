defmodule PortalWeb.JobController do
  use PortalWeb, :controller

  alias Portal.Analytics
  alias Portal.Accounts
  alias Portal.Jobs

  def index(conn, params) do
    conn = ensure_session_token(conn)
    lead = current_lead(conn)
    unlocked? = not is_nil(lead)
    jobs = Jobs.search(params, unlocked?)
    total = Jobs.count(params)

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
      json_ld: search_json_ld(params, total),
      analytics_distinct_id: analytics_id(conn, lead),
      jobs: jobs,
      params: params,
      total: total,
      lead: lead,
      unlocked?: unlocked?,
      guest_limit: Jobs.guest_limit()
    )
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

    render(conn, :show,
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

    "Meet #{count} #{subject} jobs#{scope} on Caio. Compare live tech roles with cleaner company, salary, location, and source signals before applying."
  end

  defp search_canonical_path(params) do
    query =
      [
        {"q", clean_param(params["q"])},
        {"role", clean_param(params["role"])},
        {"company", clean_param(params["company"])},
        {"location", clean_param(params["location"])}
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> URI.encode_query()

    if query == "", do: "/jobs", else: "/jobs?#{query}"
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

  defp sentence_case(value) do
    value
    |> String.trim()
    |> String.replace_prefix(String.first(value) || "", String.upcase(String.first(value) || ""))
  end

  defp job_page_title(job), do: "#{job.title} at #{job.company || "a tech company"}"

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
      "jobLocationType" => if(PortalWeb.JobHTML.remote_label(job), do: "TELECOMMUTE", else: nil),
      "jobLocation" => job_location_json_ld(job),
      "baseSalary" => salary_json_ld(job),
      "url" => PortalWeb.PageHTML.absolute_url("/jobs/#{job.id}")
    }
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp published_date(%{published_at: value}) when value not in [nil, ""],
    do: String.slice(value, 0, 10)

  defp published_date(_job), do: nil

  defp job_location_json_ld(%{location_city: city, location_country: country})
       when city not in [nil, ""] or country not in [nil, ""] do
    %{
      "@type" => "Place",
      "address" => %{
        "@type" => "PostalAddress",
        "addressLocality" => city,
        "addressCountry" => country
      }
    }
  end

  defp job_location_json_ld(_job), do: nil

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

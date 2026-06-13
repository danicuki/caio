defmodule PortalWeb.PageController do
  use PortalWeb, :controller

  alias Portal.{Accounts, Analytics, Jobs}

  @sitemap_cache_control "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400"

  def home(conn, _params) do
    conn = ensure_session_token(conn)
    snapshot = Jobs.home_snapshot(6)
    %{sample_jobs: sample_jobs, total_count: total_jobs} = snapshot
    index_stats = Map.get(snapshot, :stats) || Jobs.homepage_stats()
    lead = current_lead(conn)

    Analytics.capture("home_viewed", analytics_id(conn, lead), %{
      total_jobs: total_jobs,
      company_count: index_stats.company_count,
      sample_count: length(sample_jobs)
    })

    render(conn, :home,
      page_title: "Search public tech jobs",
      meta_description:
        "Search public tech jobs on Caio with company, salary, location, source, and posting-date details kept visible.",
      canonical_path: "/",
      analytics_distinct_id: analytics_id(conn, lead),
      sample_jobs: sample_jobs,
      highlighted_companies: ["Stripe", "Figma", "GitHub", "Shopify", "Vercel"],
      index_stats: index_stats,
      quick_searches: quick_searches(),
      total_jobs: total_jobs,
      lead: lead
    )
  end

  def sitemap(conn, _params) do
    render_sitemap_index(conn, sitemap_index_entries(), ["sitemap-root"])
  end

  def robots(conn, _params) do
    body =
      [
        "User-agent: *",
        "Allow: /",
        "Disallow: /auth/",
        "",
        "Sitemap: https://caio-jobs.com/sitemap.xml",
        sitemap_index_entries()
        |> Enum.map(&"Sitemap: #{&1}")
      ]
      |> List.flatten()
      |> Enum.join("\n")

    conn
    |> put_resp_header("cache-control", @sitemap_cache_control)
    |> put_resp_content_type("text/plain")
    |> text(body)
  end

  def sitemap_static(conn, _params) do
    render_urlset(conn, static_sitemap_urls())
  end

  defp static_sitemap_urls do
    [
      "/",
      "/jobs",
      "/about",
      "/how-it-works",
      "/pricing",
      "/privacy",
      "/terms",
      "/status",
      "/hiring-now",
      "/remote-tech-jobs",
      "/startup-jobs",
      "/top-skills"
    ]
    |> Enum.map(&%{loc: "https://caio-jobs.com#{&1}"})
  end

  def sitemap_companies(conn, _params) do
    render_urlset(conn, company_sitemap_urls())
  end

  defp company_sitemap_urls do
    Jobs.sitemap_companies()
    |> Enum.map(fn company ->
      %{
        loc: "https://caio-jobs.com/companies/#{company.slug}",
        lastmod: company.latest_posted_at
      }
    end)
  end

  defp job_sitemap_entries do
    Jobs.job_sitemap_ranges()
    |> Enum.map(fn %{first_id: first_id, last_id: last_id} ->
      "https://caio-jobs.com/sitemap-jobs-#{first_id}-#{last_id}.xml"
    end)
  end

  defp sitemap_index_entries do
    [
      "https://caio-jobs.com/sitemap-static.xml",
      "https://caio-jobs.com/sitemap-companies.xml"
    ] ++ job_sitemap_entries()
  end

  def sitemap_jobs(conn, %{"range" => range}) do
    case parse_sitemap_job_range(range) do
      {:ok, first_id, last_id} ->
        urls =
          Jobs.sitemap_jobs_in_id_range(first_id, last_id)
          |> Enum.map(fn job ->
            %{
              loc: "https://caio-jobs.com/jobs/#{job.id}",
              lastmod: job.updated_at || job.published_at
            }
          end)

        render_urlset(conn, urls, ["sitemap-jobs", "sitemap-jobs-#{first_id}-#{last_id}"])

      :error ->
        conn
        |> put_status(:not_found)
        |> render_urlset([], ["sitemap-jobs"])
    end
  end

  def sitemap_location_redirect(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: ~p"/sitemap-locations.xml")
  end

  def sitemap_locations(conn, _params) do
    urls =
      Jobs.sitemap_locations()
      |> Enum.map(fn location ->
        %{
          loc: "https://caio-jobs.com/jobs?#{URI.encode_query(%{"location" => location.label})}",
          lastmod: location.latest_posted_at
        }
      end)

    render_urlset(conn, urls)
  end

  def sitemap_keywords(conn, _params) do
    urls =
      Jobs.sitemap_keywords()
      |> Enum.map(fn keyword ->
        %{
          loc: "https://caio-jobs.com/jobs?#{URI.encode_query(%{"q" => keyword.label})}",
          lastmod: keyword.latest_posted_at
        }
      end)

    render_urlset(conn, urls)
  end

  def about(conn, _params) do
    render_static(conn,
      page_title: "About",
      eyebrow: "About Caio",
      title: "A quieter layer on top of the noisy job market.",
      intro:
        "Caio indexes public job postings, cleans up the fields that matter, and helps candidates spend less time sorting through weak listings.",
      sections: [
        %{
          title: "What Caio is",
          body:
            "Today Caio is a search surface for public tech jobs. It collects postings from public APIs, ATS feeds, and company career pages, then makes them easier to search by role, company, salary, location, and source."
        },
        %{
          title: "Where it is going",
          body:
            "The job board is the acquisition layer. The product direction is an application agent that can match jobs, tailor candidate material, and help people apply consistently without turning the process into spam."
        },
        %{
          title: "What matters",
          body:
            "Freshness, truthful candidate representation, transparent automation, and a clear audit trail matter more than raw volume."
        }
      ]
    )
  end

  def how_it_works(conn, _params) do
    render_static(conn,
      page_title: "How it works",
      eyebrow: "How it works",
      title: "From public posting to searchable job record.",
      intro:
        "Caio turns scattered job postings into structured search results, then uses saved preferences to make the next step more targeted.",
      sections: [
        %{
          title: "1. Crawl public sources",
          body:
            "The crawler pulls from public job APIs, ATS feeds, and public company career pages. Each job keeps its original source URL so candidates apply at the source of truth."
        },
        %{
          title: "2. Normalize the fields",
          body:
            "Caio standardizes company names, locations, salary ranges, tags, remote status, and posting dates so search results are easier to compare."
        },
        %{
          title: "3. Filter out weak records",
          body:
            "Quality gates reject obvious junk, stale records, and malformed data. Public counts use a freshness window rather than the raw database total."
        },
        %{
          title: "4. Unlock a profile",
          body:
            "A free profile stores target role and location preferences. Those preferences can later power saved searches, daily digests, and agent-assisted applications."
        }
      ]
    )
  end

  def pricing(conn, _params) do
    render_static(conn,
      page_title: "Pricing",
      eyebrow: "Pricing",
      title: "Free while Caio is being built in public.",
      intro:
        "The current job search product is free. The codebase is open source, and the paid product will come later around hands-on help with applications.",
      sections: [
        %{
          title: "Job search",
          body:
            "Search, browse, and unlock the current index for free. No password is required for the current profile flow."
        },
        %{
          title: "Open source",
          body:
            "Caio is developed in the open. The changelog links to the public commit history so changes can be inspected directly.",
          links: [
            %{label: "Open GitHub repo", href: "https://github.com/danicuki/caio"},
            %{label: "View changelog", href: "/changelog"}
          ]
        },
        %{
          title: "Future paid agent",
          body:
            "A future paid plan may cover automated job matching, application preparation, CV tailoring, and application tracking. That is separate from the current free search experience."
        }
      ],
      cta: %{label: "Browse jobs", path: "/jobs"}
    )
  end

  def privacy(conn, _params) do
    render_static(conn,
      page_title: "Privacy",
      eyebrow: "Privacy",
      title: "Privacy policy",
      intro:
        "Caio only asks for the information needed to unlock search and improve job recommendations.",
      updated: "May 26, 2026",
      sections: [
        %{
          title: "Information we collect",
          body:
            "If you unlock search, Caio stores your email address and any optional LinkedIn URL, target role, target location, and consent choices you submit."
        },
        %{
          title: "How we use it",
          body:
            "We use this information to unlock the job index, remember your search preferences, improve recommendations, and contact you about relevant job-search help when you opt in."
        },
        %{
          title: "Analytics",
          body:
            "Caio uses product analytics to understand search, unlock, login, and apply-click behavior. Session replay may be enabled to find usability issues, with form inputs and personal details masked."
        },
        %{
          title: "Job and application data",
          body:
            "When you continue to an application, Caio stores your email if needed, records the job, source URL, session, and lead, then redirects you to the original posting. Caio does not submit applications for you in the current product."
        },
        %{
          title: "Sharing",
          body:
            "We do not sell your personal information. We do not share your email with employers through the current search product."
        },
        %{
          title: "Retention and deletion",
          body:
            "We keep profile and interest data while it is useful for the product. You can request deletion by contacting contact@caio-jobs.com."
        }
      ]
    )
  end

  def terms(conn, _params) do
    render_static(conn,
      page_title: "Terms",
      eyebrow: "Terms",
      title: "Terms of use",
      intro:
        "Use Caio as a search and discovery tool. Always confirm details on the original employer or job-source page before applying.",
      updated: "May 26, 2026",
      sections: [
        %{
          title: "Service",
          body:
            "Caio indexes and organizes public job postings. Listings can change, expire, duplicate, or contain errors from the original source."
        },
        %{
          title: "No employment guarantee",
          body:
            "Caio does not guarantee interviews, offers, compensation, job availability, or employer responses."
        },
        %{
          title: "Original postings",
          body:
            "Applications happen on the original job source. The original posting controls the final job details, requirements, and application process."
        },
        %{
          title: "Acceptable use",
          body:
            "Do not abuse, overload, scrape, resell, or attempt to disrupt Caio. Do not use Caio to submit false or misleading candidate information."
        },
        %{
          title: "Open source",
          body:
            "Some or all of Caio may be available as open source. Open source code is governed by its repository license; hosted service use is governed by these terms.",
          links: [
            %{label: "Open GitHub repo", href: "https://github.com/danicuki/caio"}
          ]
        }
      ]
    )
  end

  def status(conn, _params) do
    render_static(conn,
      page_title: "Status",
      eyebrow: "Status",
      title: "Crawler and search status",
      intro:
        "Caio is an early product. The crawler, search index, and job counts may change while sources are added and cleaned.",
      sections: [
        %{
          title: "Search",
          body:
            "The portal reads from the crawler database and filters public results through a freshness window."
        },
        %{
          title: "Crawlers",
          body:
            "Crawler workers may be running, paused, rate-limited, or backfilling depending on source behavior."
        },
        %{
          title: "Incidents",
          body:
            "There is no separate public incident dashboard yet. For now, use the GitHub commit history and local logs as the operational record.",
          links: [
            %{label: "View commit history", href: "/changelog"},
            %{label: "Open GitHub repo", href: "https://github.com/danicuki/caio"}
          ]
        }
      ]
    )
  end

  def changelog(conn, _params) do
    redirect(conn, external: "https://github.com/danicuki/caio/commits/main")
  end

  def hiring_now(conn, _params) do
    render_acquisition(conn,
      page_title: "Companies hiring now",
      canonical_path: "/hiring-now",
      eyebrow: "Hiring now",
      title: "Companies with the most open tech roles on Caio.",
      intro:
        "A live-ish starting point for jobseekers who want to search by company instead of scrolling another generic job board.",
      meta_description:
        "See companies with the most open tech jobs indexed by Caio, then jump into focused company searches.",
      kind: :companies,
      items: Jobs.top_hiring_companies(30),
      quick_searches: quick_searches()
    )
  end

  def remote_tech_jobs(conn, _params) do
    render_acquisition(conn,
      page_title: "Remote tech jobs",
      canonical_path: "/remote-tech-jobs",
      eyebrow: "Remote tech jobs",
      title: "Start with remote tech roles that are easier to compare.",
      intro:
        "Shareable searches for people who want remote software, data, product, and infrastructure roles without rebuilding the same filters every day.",
      meta_description:
        "Search remote software engineering, React, Python, AI, product, data, and DevOps jobs on Caio.",
      kind: :searches,
      items: remote_searches(),
      quick_searches: quick_searches()
    )
  end

  def startup_jobs(conn, _params) do
    render_acquisition(conn,
      page_title: "Startup jobs",
      canonical_path: "/startup-jobs",
      eyebrow: "Startup jobs",
      title: "Search startup tech roles from one place.",
      intro:
        "Useful entry points for startup, founding engineer, product, growth, and early-stage searches. Open the original posting when a role looks real.",
      meta_description:
        "Search startup engineering, founding engineer, product, growth, and remote startup jobs on Caio.",
      kind: :searches,
      items: startup_searches(),
      quick_searches: quick_searches()
    )
  end

  def top_skills(conn, _params) do
    render_acquisition(conn,
      page_title: "Top tech job skills",
      canonical_path: "/top-skills",
      eyebrow: "Top skills",
      title: "Popular skills and categories in Caio's tech job index.",
      intro:
        "A quick way to jump into real searches. Pick a skill, compare open roles, and adjust from there.",
      meta_description:
        "Explore popular tech job skills and categories from Caio's job index with direct search links.",
      kind: :keywords,
      items: Jobs.top_search_keywords(36),
      quick_searches: quick_searches()
    )
  end

  defp render_sitemap_index(conn, entries, tags) do
    body =
      [
        ~s(<?xml version="1.0" encoding="UTF-8"?>),
        ~s(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">),
        Enum.map(entries, &sitemap_entry/1),
        "</sitemapindex>"
      ]
      |> List.flatten()
      |> Enum.join("\n")

    render_xml(conn, body, ["sitemap" | tags])
  end

  defp render_urlset(conn, urls, tags \\ ["sitemap-urlset"]) do
    body =
      [
        ~s(<?xml version="1.0" encoding="UTF-8"?>),
        ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">),
        Enum.map(urls, &sitemap_url/1),
        "</urlset>"
      ]
      |> List.flatten()
      |> Enum.join("\n")

    render_xml(conn, body, ["sitemap" | tags])
  end

  defp render_xml(conn, body, tags) do
    conn
    |> put_resp_header("cache-control", @sitemap_cache_control)
    |> put_resp_header("cache-tag", tags |> Enum.uniq() |> Enum.join(","))
    |> put_resp_content_type("application/xml")
    |> text(body)
  end

  defp sitemap_entry(loc), do: "  <sitemap><loc>#{xml_escape(loc)}</loc></sitemap>"

  defp parse_sitemap_job_range(range) do
    range = String.trim_trailing(range, ".xml")

    with [first_id, last_id] <- String.split(range, "-", parts: 2),
         {first_id, ""} <- Integer.parse(first_id),
         {last_id, ""} <- Integer.parse(last_id),
         true <- first_id > 0,
         true <- last_id >= first_id do
      {:ok, first_id, last_id}
    else
      _ -> :error
    end
  end

  defp sitemap_url(%{loc: loc} = url) do
    lastmod = url[:lastmod]

    [
      "  <url>",
      "    <loc>#{xml_escape(loc)}</loc>",
      if(lastmod in [nil, ""],
        do: nil,
        else: "    <lastmod>#{String.slice(to_string(lastmod), 0, 10)}</lastmod>"
      ),
      "  </url>"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp xml_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp render_static(conn, assigns) do
    conn = ensure_session_token(conn)
    lead = current_lead(conn)
    page_title = Keyword.fetch!(assigns, :page_title)

    Analytics.capture("static_page_viewed", analytics_id(conn, lead), %{
      page_title: page_title,
      path: Phoenix.Controller.current_path(conn)
    })

    render(
      conn,
      :static,
      assigns
      |> Keyword.put(:lead, lead)
      |> Keyword.put(:analytics_distinct_id, analytics_id(conn, lead))
      |> Keyword.put_new(:meta_description, Keyword.fetch!(assigns, :intro))
      |> Keyword.put_new(:canonical_path, Phoenix.Controller.current_path(conn))
    )
  end

  defp render_acquisition(conn, assigns) do
    conn = ensure_session_token(conn)
    lead = current_lead(conn)
    page_title = Keyword.fetch!(assigns, :page_title)

    Analytics.capture("acquisition_page_viewed", analytics_id(conn, lead), %{
      page_title: page_title,
      path: Phoenix.Controller.current_path(conn),
      kind: assigns[:kind]
    })

    render(
      conn,
      :acquisition,
      assigns
      |> Keyword.put(:lead, lead)
      |> Keyword.put(:analytics_distinct_id, analytics_id(conn, lead))
      |> Keyword.put_new(:meta_description, Keyword.fetch!(assigns, :intro))
    )
  end

  defp quick_searches do
    [
      %{
        label: "Remote software engineer",
        path:
          "/jobs?#{URI.encode_query(%{"q" => "software engineer", "location" => "remote", "utm_source" => "caio", "utm_campaign" => "launch-week", "utm_content" => "quick-remote-software"})}"
      },
      %{
        label: "React remote",
        path:
          "/jobs?#{URI.encode_query(%{"q" => "react", "location" => "remote", "utm_source" => "caio", "utm_campaign" => "launch-week", "utm_content" => "quick-react-remote"})}"
      },
      %{
        label: "Python remote",
        path:
          "/jobs?#{URI.encode_query(%{"q" => "python", "location" => "remote", "utm_source" => "caio", "utm_campaign" => "launch-week", "utm_content" => "quick-python-remote"})}"
      },
      %{
        label: "AI engineer",
        path:
          "/jobs?#{URI.encode_query(%{"q" => "ai engineer", "utm_source" => "caio", "utm_campaign" => "launch-week", "utm_content" => "quick-ai-engineer"})}"
      },
      %{
        label: "Product manager",
        path:
          "/jobs?#{URI.encode_query(%{"q" => "product manager", "utm_source" => "caio", "utm_campaign" => "launch-week", "utm_content" => "quick-product-manager"})}"
      },
      %{
        label: "Data analyst",
        path:
          "/jobs?#{URI.encode_query(%{"q" => "data analyst", "utm_source" => "caio", "utm_campaign" => "launch-week", "utm_content" => "quick-data-analyst"})}"
      }
    ]
  end

  defp remote_searches do
    [
      search_card("Remote software engineer", %{
        "q" => "software engineer",
        "location" => "remote"
      }),
      search_card("Remote backend", %{"q" => "backend", "location" => "remote"}),
      search_card("Remote frontend", %{"q" => "frontend", "location" => "remote"}),
      search_card("Remote React", %{"q" => "react", "location" => "remote"}),
      search_card("Remote Python", %{"q" => "python", "location" => "remote"}),
      search_card("Remote AI engineer", %{"q" => "ai engineer", "location" => "remote"}),
      search_card("Remote product manager", %{"q" => "product manager", "location" => "remote"}),
      search_card("Remote data analyst", %{"q" => "data analyst", "location" => "remote"}),
      search_card("Remote DevOps", %{"q" => "devops sre", "location" => "remote"})
    ]
  end

  defp startup_searches do
    [
      search_card("Startup software engineer", %{"q" => "startup software engineer"}),
      search_card("Founding engineer", %{"q" => "founding engineer"}),
      search_card("Early stage backend", %{"q" => "early stage backend"}),
      search_card("Startup product manager", %{"q" => "startup product manager"}),
      search_card("Growth engineer", %{"q" => "growth engineer"}),
      search_card("Remote startup roles", %{"q" => "startup", "location" => "remote"}),
      search_card("AI startup jobs", %{"q" => "ai startup"}),
      search_card("Fintech startup jobs", %{"q" => "fintech startup"})
    ]
  end

  defp search_card(label, params) do
    params =
      params
      |> Map.put("utm_source", "caio")
      |> Map.put("utm_campaign", "launch-week")
      |> Map.put(
        "utm_content",
        label |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
      )

    %{label: label, path: "/jobs?#{URI.encode_query(params)}"}
  end

  defp current_lead(conn), do: Accounts.get_lead(get_session(conn, :lead_id))

  defp ensure_session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> put_session(conn, :session_token, Ecto.UUID.generate())
      _ -> conn
    end
  end

  defp analytics_id(conn, nil), do: "session:#{get_session(conn, :session_token)}"
  defp analytics_id(conn, lead), do: "lead:#{lead.id}:#{get_session(conn, :session_token)}"
end

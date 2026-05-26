defmodule PortalWeb.PageController do
  use PortalWeb, :controller

  alias Portal.Jobs

  def home(conn, _params) do
    sample_jobs = Jobs.sample(6)
    total_jobs = Jobs.total_count()
    render(conn, :home, sample_jobs: sample_jobs, total_jobs: total_jobs)
  end

  def about(conn, _params) do
    render_static(conn,
      page_title: "About",
      eyebrow: "About Caio",
      title: "A quieter layer on top of the noisy job market.",
      intro:
        "Caio indexes public job postings, normalizes the useful signals, and helps candidates spend less time sorting through low-quality listings.",
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
      title: "From public posting to usable job signal.",
      intro:
        "Caio turns scattered job postings into a structured search experience, then uses profile signal to make the next step more targeted.",
      sections: [
        %{
          title: "1. Crawl public sources",
          body:
            "The crawler pulls from public job APIs, ATS feeds, and public company career pages. Each job keeps its original source URL so candidates apply at the source of truth."
        },
        %{
          title: "2. Normalize the fields",
          body:
            "Caio standardizes company names, locations, salary ranges, tags, remote signals, and posting dates so search results are easier to compare."
        },
        %{
          title: "3. Filter out bad signal",
          body:
            "Quality gates reject obvious junk, stale records, and malformed data. Public counts use a freshness window rather than the raw database total."
        },
        %{
          title: "4. Unlock a profile",
          body:
            "A free profile stores target role and location preferences. That signal can later power saved searches, daily digests, and agent-assisted applications."
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
        "The current job search product is free. The codebase is open source, and the paid product will come later around higher-value application-agent workflows.",
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
          title: "Job and application data",
          body:
            "When you click apply, Caio records the job, source URL, session, and lead if available, then redirects you to the original posting. Caio does not submit applications for you in the current product."
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

  defp render_static(conn, assigns) do
    render(conn, :static, assigns)
  end
end

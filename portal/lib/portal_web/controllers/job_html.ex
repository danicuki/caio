defmodule PortalWeb.JobHTML do
  use PortalWeb, :html

  embed_templates "job_html/*"

  attr :active, :string, default: ""
  attr :compact, :boolean, default: false
  attr :count, :any, default: nil

  def site_nav(assigns) do
    ~H"""
    <nav class={["topbar", @compact && "compact"]}>
      <a href={~p"/"} class="brand" aria-label="Caio home">
        <span class="brand-mark">C</span>
        <span>Caio</span>
      </a>
      <div id="site-nav-menu" class="nav-menu">
        <div class="nav-links">
          <a href={~p"/jobs"} class={["nav-link", @active == "jobs" && "active"]}>Jobs</a>
          <a href={~p"/jobs?order=random"} class="nav-link">Explore</a>
          <a href="#unlock" class="nav-cta">Free profile</a>
        </div>
        <div class="theme-toggle" aria-label="Theme">
          <button type="button" data-phx-theme="light">Light</button>
          <button type="button" data-phx-theme="dark">Dark</button>
          <button type="button" data-phx-theme="system">Auto</button>
        </div>
      </div>
      <%= if @count do %>
        <span class="nav-muted">{@count}</span>
      <% end %>
      <button
        type="button"
        class="mobile-menu-button"
        aria-controls="site-nav-menu"
        aria-expanded="false"
      >
        Menu
      </button>
    </nav>
    """
  end

  attr :job, :map, required: true
  attr :locked, :boolean, default: false

  def job_card(assigns) do
    ~H"""
    <a
      href={if @locked, do: "#unlock", else: ~p"/jobs/#{@job.id}"}
      class={["job-card", @locked && "locked-card"]}
    >
      <.company_avatar job={@job} />
      <div class="job-card-main">
        <div class="job-card-topline">
          <span>{@job.company || "Company"}</span>
          <span>{posted_label(@job)}</span>
        </div>
        <h3>{if @locked, do: "Senior role at a verified tech company", else: @job.title}</h3>
        <.metadata_row job={@job} />
        <.tag_list tags={job_tags(@job)} />
      </div>
      <span class="open-arrow" aria-hidden="true">{if @locked, do: "Unlock", else: "View"}</span>
    </a>
    """
  end

  attr :job, :map, required: true

  def company_avatar(assigns) do
    ~H"""
    <span class="company-avatar" aria-hidden="true">{company_initials(@job)}</span>
    """
  end

  attr :job, :map, required: true

  def metadata_row(assigns) do
    ~H"""
    <p class="job-meta">
      <span>{compact_location(@job)}</span>
      <%= if salary(@job) do %>
        <span>{salary(@job)}</span>
      <% end %>
      <%= if employment_label(@job) do %>
        <span>{employment_label(@job)}</span>
      <% end %>
      <%= if remote_label(@job) do %>
        <span>{remote_label(@job)}</span>
      <% end %>
    </p>
    """
  end

  attr :tags, :list, default: []

  def tag_list(assigns) do
    ~H"""
    <%= if @tags != [] do %>
      <div class="tag-list">
        <%= for tag <- Enum.take(@tags, 4) do %>
          <span class="tag-chip">{tag}</span>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :return_to, :string, required: true
  attr :params, :map, default: %{}
  attr :variant, :string, default: "card"

  def lead_form(assigns) do
    ~H"""
    <form id="unlock" action={~p"/leads"} method="post" class={["lead-form", "lead-form-#{@variant}"]}>
      <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
      <input type="hidden" name="lead[return_to]" value={@return_to} />
      <div class="social-row" aria-label="Visual social sign in options">
        <button type="button">Continue with Google</button>
        <button type="button">GitHub</button>
      </div>
      <div class="form-divider"><span>or unlock with email</span></div>
      <label>
        <span>Email</span>
        <input name="lead[email]" type="email" placeholder="you@example.com" required />
      </label>
      <label>
        <span>LinkedIn URL</span>
        <input name="lead[linkedin_url]" type="url" placeholder="Optional profile link" />
      </label>
      <input
        name="lead[target_role]"
        type="text"
        value={@params["role"] || @params["q"]}
        placeholder="Target role"
      />
      <input
        name="lead[target_location]"
        type="text"
        value={@params["location"]}
        placeholder="Target location"
      />
      <label class="checkbox-line">
        <input name="lead[consent_job_help]" value="true" type="checkbox" />
        <span>Send me relevant role recommendations and job-search help.</span>
      </label>
      <button type="submit" class="primary-button">Unlock free search</button>
    </form>
    """
  end

  attr :return_to, :string, required: true
  attr :params, :map, default: %{}
  attr :lead, :map, default: nil
  attr :variant, :string, default: "panel"

  def unlock_panel(assigns) do
    ~H"""
    <%= if @lead do %>
      <div class={["unlock-box", "success", "unlock-#{@variant}"]}>
        <span class="eyebrow">Unlocked</span>
        <strong>Unlimited search active</strong>
        <p>{@lead.email}</p>
      </div>
    <% else %>
      <section class={["unlock-box", "unlock-#{@variant}"]}>
        <span class="eyebrow">Free. 20 seconds. No password.</span>
        <strong>See every match in this search.</strong>
        <p>
          Create a free Caio profile to unlock hidden roles, keep your search signal, and get sharper job recommendations.
        </p>
        <.lead_form return_to={@return_to} params={@params} variant={@variant} />
      </section>
    <% end %>
    """
  end

  def footer(assigns) do
    ~H"""
    <footer class="site-footer">
      <div class="site-footer-inner">
        <div class="footer-brand">
          <a href={~p"/"} class="footer-wordmark" aria-label="Caio home">
            <span class="footer-dot"></span>
            <span>caio</span>
          </a>
          <p>
            A search engine for tech jobs. Hundreds of thousands of roles indexed from across
            the web, refreshed every hour.
          </p>
        </div>

        <nav class="footer-column" aria-label="Search">
          <h2>Search</h2>
          <a href={~p"/jobs?role=frontend"}>Frontend</a>
          <a href={~p"/jobs?role=backend"}>Backend</a>
          <a href={~p"/jobs?q=machine+learning+data"}>ML & data</a>
          <a href={~p"/jobs?role=design"}>Design</a>
          <a href={~p"/jobs?q=devops+sre"}>DevOps & SRE</a>
          <a href={~p"/jobs?location=remote"}>Remote only</a>
        </nav>

        <nav class="footer-column" aria-label="Caio">
          <h2>Caio</h2>
          <a href={~p"/"}>About</a>
          <a href="#unlock">How it works</a>
          <a href={~p"/jobs?order=random"}>Changelog</a>
          <a href="#unlock">Pricing</a>
        </nav>

        <nav class="footer-column" aria-label="Help">
          <h2>Help</h2>
          <a href="mailto:hello@caio.jobs">Contact</a>
          <a href="#privacy">Privacy</a>
          <a href="#terms">Terms</a>
          <a href="#status">Status</a>
        </nav>

        <div class="footer-bottom">
          <span>© {Date.utc_today().year} Caio</span>
          <span>Public job data, normalized for quieter search.</span>
        </div>
      </div>
    </footer>
    """
  end

  def compact_location(job) do
    [job.location_city, job.location_state, job.location_country]
    |> Enum.reject(&is_nil_or_empty?/1)
    |> Enum.join(", ")
    |> case do
      "" -> job.location || "Remote / flexible"
      value -> value
    end
  end

  def salary(job) do
    cond do
      job.salary_min && job.salary_max && job.salary_currency ->
        min = round(job.salary_min)
        max = round(job.salary_max)
        period = if job.salary_period, do: " / #{job.salary_period}", else: ""
        "#{job.salary_currency} #{min}-#{max}#{period}"

      job.salary not in [nil, ""] ->
        job.salary

      true ->
        nil
    end
  end

  def source_label(source), do: source |> to_string() |> String.capitalize()

  def employment_label(%{employment_type: value}) when value not in [nil, ""],
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  def employment_label(_job), do: nil

  def remote_label(%{remote: 1}), do: "Remote"
  def remote_label(%{location_scope: scope}) when scope in ["remote", "Remote"], do: "Remote"
  def remote_label(_job), do: nil

  def pluralize(1, singular), do: "1 #{singular}"
  def pluralize(count, singular), do: "#{count || 0} #{singular}s"

  def posted_label(%{published_at: value}) when value not in [nil, ""] do
    case Date.from_iso8601(String.slice(value, 0, 10)) do
      {:ok, date} -> relative_date(date)
      _ -> "Recently indexed"
    end
  end

  def posted_label(%{updated_at: value}) when value not in [nil, ""],
    do: "Indexed #{String.slice(value, 0, 10)}"

  def posted_label(_job), do: "Recently indexed"

  def job_tags(job) do
    (parsed_tags(job) ++ [job.category, source_label(job.source)])
    |> Enum.reject(&is_nil_or_empty?/1)
    |> Enum.map(&String.trim(to_string(&1)))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def company_initials(job) do
    source = source_label(Map.get(job, :source))

    (Map.get(job, :company) || source || "Caio")
    |> to_string()
    |> String.split(~r/[^a-zA-Z0-9]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", fn part -> part |> String.first() |> String.upcase() end)
    |> case do
      "" -> "C"
      value -> value
    end
  end

  defp parsed_tags(%{tags_json: value}) when value not in [nil, ""] do
    case Jason.decode(value) do
      {:ok, tags} when is_list(tags) -> tags
      {:ok, %{"tags" => tags}} when is_list(tags) -> tags
      _ -> []
    end
  end

  defp parsed_tags(_job), do: []

  defp relative_date(date) do
    days = Date.diff(Date.utc_today(), date)

    cond do
      days <= 0 -> "Posted today"
      days == 1 -> "Posted yesterday"
      days < 30 -> "Posted #{days}d ago"
      days < 60 -> "Posted 1mo ago"
      true -> "Posted #{div(days, 30)}mo ago"
    end
  end

  def clean_description(nil),
    do: "No description indexed yet. Open the original posting for full details."

  def clean_description(text) do
    text
    |> to_string()
    |> decode_html_entities()
    |> html_to_text()
    |> decode_html_entities()
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
    |> String.slice(0, 1_600)
    |> case do
      "" -> clean_description(nil)
      value -> value
    end
  end

  defp is_nil_or_empty?(value), do: is_nil(value) or value == ""

  def description_html(nil), do: "<p>#{clean_description(nil)}</p>"

  def description_html(text) do
    text
    |> to_string()
    |> decode_html_entities()
    |> normalize_breaks()
    |> sanitize_description_html()
    |> normalize_description_html()
    |> case do
      "" -> description_html(nil)
      value -> value
    end
  end

  defp normalize_breaks(text) do
    text
    |> String.replace(~r/(?:<\s*br\s*\/?\s*>\s*){2,}/i, "</p><p>")
    |> String.replace(~r/<\s*br\s*\/?\s*>/i, "<br>")
  end

  defp sanitize_description_html(text) do
    text
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.replace(~r/<\s*(script|style)[^>]*>.*?<\s*\/\s*\1\s*>/is, "")
    |> String.replace(~r/<\/?([a-zA-Z0-9]+)(?:\s[^>]*)?\s*\/?>/, &sanitize_tag/1)
    |> decode_html_entities()
  end

  defp sanitize_tag(raw_tag) do
    tag =
      case Regex.run(~r/^<\s*\/?\s*([a-zA-Z0-9]+)/, raw_tag) do
        [_, tag_name] -> String.downcase(tag_name)
        _ -> ""
      end

    closing? = String.starts_with?(raw_tag, "</")
    self_closing? = String.ends_with?(raw_tag, "/>") or tag == "br"

    cond do
      tag in ~w(div section article span) ->
        ""

      tag in ~w(p ul ol li strong b em i h2 h3 h4 blockquote) ->
        if closing?, do: "</#{tag}>", else: "<#{tag}>"

      tag == "br" and self_closing? ->
        "<br>"

      true ->
        ""
    end
  end

  defp normalize_description_html(text) do
    text
    |> String.replace(~r/\r\n?/, "\n")
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.replace(~r/<p>\s*(<(?:ul|ol)\b)/i, "\\1")
    |> String.replace(~r{(</(?:ul|ol)>)\s*</p>}i, "\\1")
    |> String.trim()
    |> wrap_plain_description()
  end

  defp wrap_plain_description(""), do: ""

  defp wrap_plain_description(text) do
    if Regex.match?(~r/<(p|ul|ol|li|h2|h3|h4|blockquote|br)\b/i, text) do
      text
    else
      paragraphs =
        text
        |> String.split(~r/\n{2,}/, trim: true)
        |> Enum.map_join(
          "",
          &"<p>#{Phoenix.HTML.html_escape(&1) |> Phoenix.HTML.safe_to_string()}</p>"
        )

      paragraphs
    end
  end

  defp html_to_text(text) do
    text
    |> String.replace(~r/<\s*br\s*\/?\s*>/i, "\n")
    |> String.replace(~r/<\s*\/?\s*(p|div|section|article|h[1-6]|ul|ol)[^>]*>/i, "\n")
    |> String.replace(~r/<\s*li[^>]*>/i, "\n- ")
    |> String.replace(~r/<[^>]+>/, " ")
  end

  defp decode_html_entities(text) do
    Regex.replace(~r/&#(x[0-9a-fA-F]+|\d+);|&(lt|gt|amp|quot|apos|nbsp);/, text, fn
      match, numeric, "" -> decode_numeric_entity(numeric) || match
      _match, "", named -> named_entity(named)
    end)
  end

  defp decode_numeric_entity("x" <> hex) do
    with {codepoint, ""} <- Integer.parse(hex, 16),
         true <- valid_codepoint?(codepoint) do
      <<codepoint::utf8>>
    else
      _ -> nil
    end
  end

  defp decode_numeric_entity(decimal) do
    with {codepoint, ""} <- Integer.parse(decimal),
         true <- valid_codepoint?(codepoint) do
      <<codepoint::utf8>>
    else
      _ -> nil
    end
  end

  defp valid_codepoint?(codepoint) do
    codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF
  end

  defp named_entity("lt"), do: "<"
  defp named_entity("gt"), do: ">"
  defp named_entity("amp"), do: "&"
  defp named_entity("quot"), do: "\""
  defp named_entity("apos"), do: "'"
  defp named_entity("nbsp"), do: " "
end

defmodule PortalWeb.JobHTML do
  use PortalWeb, :html

  embed_templates "job_html/*"

  attr :job, :map, required: true

  def job_card(assigns) do
    ~H"""
    <a href={~p"/jobs/#{@job.id}"} class="job-card">
      <div>
        <p class="source-pill">{source_label(@job.source)}</p>
        <h3>{@job.title}</h3>
        <p class="job-meta">
          <span>{@job.company || "Company"}</span>
          <span>{compact_location(@job)}</span>
          <%= if salary(@job) do %>
            <span>{salary(@job)}</span>
          <% end %>
        </p>
      </div>
      <span class="open-arrow">→</span>
    </a>
    """
  end

  attr :return_to, :string, required: true
  attr :params, :map, default: %{}

  def lead_form(assigns) do
    ~H"""
    <form id="unlock" action={~p"/leads"} method="post" class="lead-form">
      <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
      <input type="hidden" name="lead[return_to]" value={@return_to} />
      <input name="lead[email]" type="email" placeholder="you@example.com" required />
      <input name="lead[linkedin_url]" type="url" placeholder="LinkedIn profile URL (optional)" />
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
        <span>Send me relevant job-search help and role recommendations.</span>
      </label>
      <button type="submit">Unlock free search</button>
    </form>
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

  def clean_description(nil),
    do: "No description indexed yet. Open the original posting for full details."

  def clean_description(text) do
    text
    |> to_string()
    |> String.slice(0, 1_600)
  end

  defp is_nil_or_empty?(value), do: is_nil(value) or value == ""
end

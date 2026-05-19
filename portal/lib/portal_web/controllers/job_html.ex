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
    |> sanitize_description_html()
    |> normalize_description_html()
    |> case do
      "" -> description_html(nil)
      value -> value
    end
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

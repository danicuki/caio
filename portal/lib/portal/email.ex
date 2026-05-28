defmodule Portal.Email do
  @moduledoc false

  require Logger

  alias Portal.Accounts.Lead

  @resend_url ~c"https://api.resend.com/emails"

  def welcome_email_text do
    """
    Hey, welcome to Caio. This is Daniel here (I am a real person).

    Search, scrape, download, and use whatever helps you find a better job.

    I know applying online can be exhausting. I went through it recently and hated how much time disappeared into forms, CV tweaks, and dead-end listings.

    That's why I built Caio: a job agent that can find good matches, adapt your CV, and handle the repetitive applications, so you can spend more time preparing for interviews and learning useful things.

    If you want me to set up Caio as your agent too, just reply here.

    Daniel
    """
    |> String.trim()
  end

  def welcome_email_html do
    welcome_email_text()
    |> String.split("\n\n")
    |> Enum.map_join("", fn paragraph ->
      "<p>#{Phoenix.HTML.html_escape(paragraph) |> Phoenix.HTML.safe_to_string()}</p>"
    end)
  end

  def deliver_welcome_async(%Lead{} = lead) do
    if enabled?() do
      Task.Supervisor.start_child(Portal.EmailSupervisor, fn -> deliver_welcome(lead) end)
    else
      :disabled
    end
  end

  def deliver_welcome(%Lead{} = lead) do
    payload =
      %{
        from: config(:from),
        to: [lead.email],
        subject: "Welcome to Caio",
        text: welcome_email_text(),
        html: welcome_email_html()
      }
      |> maybe_put(:reply_to, config(:reply_to))

    request(payload)
  end

  def enabled? do
    truthy?(config(:enabled)) and present?(config(:api_key)) and present?(config(:from))
  end

  defp request(payload) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    body = Jason.encode!(payload)

    headers = [
      {~c"authorization", ~c"Bearer #{config(:api_key)}"},
      {~c"content-type", ~c"application/json"}
    ]

    case :httpc.request(:post, {@resend_url, headers, ~c"application/json", body}, [], []) do
      {:ok, {{_, status, _}, _headers, response_body}} when status in 200..299 ->
        {:ok, Jason.decode!(to_string(response_body))}

      {:ok, {{_, status, _}, _headers, response_body}} ->
        Logger.warning("Resend welcome email failed with #{status}: #{inspect(response_body)}")
        {:error, status}

      {:error, reason} ->
        Logger.warning("Resend welcome email failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.warning("Resend welcome email raised: #{Exception.message(error)}")
      {:error, error}
  end

  defp config(key) do
    :portal
    |> Application.get_env(:email, [])
    |> case do
      config when is_list(config) -> Keyword.get(config, key)
      _ -> nil
    end
  end

  defp maybe_put(payload, _key, value) when value in [nil, ""], do: payload
  defp maybe_put(payload, key, value), do: Map.put(payload, key, value)

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp truthy?(value), do: value in [true, "1", "true", "TRUE", "yes", "YES"]
end

defmodule Portal.Analytics do
  @moduledoc false

  require Logger

  def browser_config do
    config = config()

    if enabled?(config) do
      %{
        apiKey: config[:public_key],
        apiHost: config[:host],
        sessionReplay: config[:session_replay]
      }
    end
  end

  def capture(_event, _distinct_id, _properties \\ %{})

  def capture(_event, distinct_id, _properties) when distinct_id in [nil, ""], do: :ok

  def capture(event, distinct_id, properties) when is_binary(event) do
    config = config()

    if enabled?(config) do
      payload = %{
        api_key: config[:public_key],
        event: event,
        distinct_id: to_string(distinct_id),
        properties: sanitize_properties(properties)
      }

      Task.start(fn -> post_capture(config[:host], payload) end)
    end

    :ok
  end

  defp config, do: Application.get_env(:portal, :posthog, [])

  defp enabled?(config), do: config[:enabled] && present?(config[:public_key])

  defp post_capture(host, payload) do
    url = String.trim_trailing(host || "https://us.i.posthog.com", "/") <> "/capture/"
    body = Jason.encode!(payload)
    headers = [{~c"content-type", ~c"application/json"}]

    request = {String.to_charlist(url), headers, ~c"application/json", body}

    case :httpc.request(:post, request, [], []) do
      {:ok, {{_, status, _}, _headers, _body}} when status in 200..299 ->
        :ok

      {:ok, {{_, status, _}, _headers, body}} ->
        Logger.debug("PostHog capture failed with #{status}: #{inspect(body)}")

      {:error, reason} ->
        Logger.debug("PostHog capture failed: #{inspect(reason)}")
    end
  rescue
    error -> Logger.debug("PostHog capture raised: #{Exception.message(error)}")
  end

  defp sanitize_properties(properties) when is_map(properties) do
    properties
    |> Enum.reject(fn {key, _value} ->
      key
      |> to_string()
      |> String.downcase()
      |> sensitive_key?()
    end)
    |> Map.new()
  end

  defp sanitize_properties(_properties), do: %{}

  defp sensitive_key?(key),
    do:
      String.contains?(key, "email") or String.contains?(key, "token") or
        String.contains?(key, "secret")

  defp present?(value), do: is_binary(value) && String.trim(value) != ""
end

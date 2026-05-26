defmodule Portal.GitHubOAuth do
  @moduledoc false

  @access_token_url "https://github.com/login/oauth/access_token"
  @user_url "https://api.github.com/user"
  @emails_url "https://api.github.com/user/emails"

  def configured? do
    present?(client_id()) and present?(client_secret())
  end

  def client_id, do: System.get_env("GITHUB_CLIENT_ID")
  def client_secret, do: System.get_env("GITHUB_CLIENT_SECRET")

  def exchange_code(code, redirect_uri) do
    with {:ok, token} <- access_token(code, redirect_uri),
         {:ok, user} <- user(token),
         {:ok, emails} <- emails(token),
         {:ok, email} <- primary_email(user, emails) do
      {:ok, %{email: email, github_login: user["login"]}}
    end
  end

  defp access_token(code, redirect_uri) do
    post_form(@access_token_url, %{
      "client_id" => client_id(),
      "client_secret" => client_secret(),
      "code" => code,
      "redirect_uri" => redirect_uri
    })
    |> case do
      {:ok, %{"access_token" => token}} when is_binary(token) -> {:ok, token}
      {:ok, %{"error_description" => message}} -> {:error, message}
      {:ok, %{"error" => message}} -> {:error, message}
      {:ok, _} -> {:error, "GitHub did not return an access token."}
      {:error, reason} -> {:error, reason}
    end
  end

  defp user(token), do: get_json(@user_url, token)
  defp emails(token), do: get_json(@emails_url, token)

  defp primary_email(%{"email" => email}, _emails) when is_binary(email) and email != "" do
    {:ok, email}
  end

  defp primary_email(_user, emails) when is_list(emails) do
    email =
      Enum.find(emails, &(&1["primary"] == true and &1["verified"] == true)) ||
        Enum.find(emails, &(&1["verified"] == true))

    case email do
      %{"email" => value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "GitHub did not return a verified email address."}
    end
  end

  defp primary_email(_user, _emails), do: {:error, "GitHub did not return an email address."}

  defp post_form(url, form) do
    body = URI.encode_query(form)

    headers = [
      {~c"accept", ~c"application/json"},
      {~c"content-type", ~c"application/x-www-form-urlencoded"},
      {~c"user-agent", ~c"Caio"}
    ]

    request(:post, {url, headers, ~c"application/x-www-form-urlencoded", body})
  end

  defp get_json(url, token) do
    headers = [
      {~c"accept", ~c"application/vnd.github+json"},
      {~c"authorization", String.to_charlist("Bearer #{token}")},
      {~c"user-agent", ~c"Caio"},
      {~c"x-github-api-version", ~c"2022-11-28"}
    ]

    request(:get, {url, headers})
  end

  defp request(method, request) do
    request =
      case request do
        {url, headers} ->
          {String.to_charlist(url), headers}

        {url, headers, content_type, body} ->
          {String.to_charlist(url), headers, content_type, String.to_charlist(body)}
      end

    case :httpc.request(method, request, http_options(), body_format: :binary) do
      {:ok, {{_, status, _}, _headers, body}} when status in 200..299 ->
        Jason.decode(body)

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, "GitHub returned HTTP #{status}: #{String.slice(body, 0, 160)}"}

      {:error, reason} ->
        {:error, "GitHub request failed: #{inspect(reason)}"}
    end
  end

  defp http_options do
    [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end

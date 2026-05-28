defmodule Portal.Scripts.SendWelcomeEmails do
  @moduledoc false

  import Ecto.Query

  alias Portal.Accounts.Lead
  alias Portal.{Email, Repo}

  def run do
    start_repo!()

    leads = load_leads()
    dry_run? = System.get_env("WELCOME_EMAIL_SEND") != "true"
    sleep_ms = env_int("WELCOME_EMAIL_SLEEP_MS", 500)

    if not dry_run? and not Email.enabled?() do
      abort!("Resend is disabled. Check RESEND_ENABLED, RESEND_API_KEY, and RESEND_FROM.")
    end

    IO.puts("welcome email backfill")
    IO.puts("mode=#{if(dry_run?, do: "dry-run", else: "send")}")
    IO.puts("leads=#{length(leads)}")
    IO.puts("sleep_ms=#{sleep_ms}")

    result =
      Enum.reduce(leads, %{ok: 0, error: 0, skipped: 0}, fn lead, acc ->
        if dry_run? do
          IO.puts("dry-run lead=#{lead.id} email=#{lead.email}")
          %{acc | skipped: acc.skipped + 1}
        else
          send_one(lead, acc, sleep_ms)
        end
      end)

    IO.inspect(result, label: "done")
  end

  defp start_repo! do
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:ecto_sqlite3)
    Application.ensure_all_started(:exqlite)
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    case Repo.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> abort!("could not start repo: #{inspect(reason)}")
    end
  end

  defp load_leads do
    Lead
    |> where([lead], not is_nil(lead.email))
    |> maybe_filter_id()
    |> order_by([lead], asc: lead.id)
    |> maybe_limit()
    |> Repo.all()
  end

  defp maybe_filter_id(query) do
    case System.get_env("WELCOME_EMAIL_LEAD_ID") do
      nil -> query
      "" -> query
      value -> where(query, [lead], lead.id == ^String.to_integer(value))
    end
  end

  defp maybe_limit(query) do
    case System.get_env("WELCOME_EMAIL_LIMIT") do
      nil -> query
      "" -> query
      value -> limit(query, ^String.to_integer(value))
    end
  end

  defp send_one(lead, acc, sleep_ms) do
    IO.puts("sending lead=#{lead.id} email=#{lead.email}")

    case Email.deliver_welcome(lead) do
      {:ok, response} ->
        IO.puts("ok lead=#{lead.id} resend_id=#{response["id"]}")
        Process.sleep(sleep_ms)
        %{acc | ok: acc.ok + 1}

      other ->
        IO.puts("error lead=#{lead.id} result=#{inspect(other)}")
        Process.sleep(sleep_ms)
        %{acc | error: acc.error + 1}
    end
  end

  defp env_int(name, default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      value -> String.to_integer(value)
    end
  end

  defp abort!(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end

Portal.Scripts.SendWelcomeEmails.run()

defmodule PortalWeb.AdminHTML do
  @moduledoc false

  use PortalWeb, :html

  embed_templates "admin_html/*"

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, default: nil

  def metric(assigns) do
    ~H"""
    <article class="rounded-xl border border-[var(--line)] bg-[var(--paper)] p-5 shadow-sm">
      <p class="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">{@label}</p>
      <strong class="mt-2 block text-3xl text-[var(--ink)]">{@value}</strong>
      <p :if={@detail} class="mt-1 truncate text-sm text-[var(--muted)]">{@detail}</p>
    </article>
    """
  end

  def format_count(nil), do: "0"

  def format_count(number) when is_integer(number) do
    number
    |> to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def format_count(number) when is_float(number), do: number |> round() |> format_count()
  def format_count(number), do: number

  def percent(_part, total) when total in [nil, 0], do: "0.0%"

  def percent(part, total) do
    "#{Float.round(to_number(part) / max(to_number(total), 1) * 100, 1)}%"
  end

  def per_1k(_part, total) when total in [nil, 0], do: "0.0"

  def per_1k(part, total) do
    Float.round(to_number(part) / max(to_number(total), 1) * 1_000, 1)
  end

  def bar_width(value, max_value) do
    width =
      if to_number(max_value) <= 0 do
        0
      else
        to_number(value) / to_number(max_value) * 100
      end

    "width: #{Float.round(width, 1)}%"
  end

  def max_value(rows, key) do
    rows
    |> Enum.map(&to_number(Map.get(&1, key)))
    |> Enum.max(fn -> 0 end)
  end

  def stale_style(nil), do: "color: var(--red)"

  def stale_style(timestamp) do
    case NaiveDateTime.from_iso8601(normalize_timestamp(timestamp)) do
      {:ok, time} ->
        if NaiveDateTime.diff(NaiveDateTime.utc_now(), time, :minute) > 60 do
          "color: var(--amber-2)"
        else
          "color: var(--green)"
        end

      _ ->
        "color: var(--muted)"
    end
  end

  defp normalize_timestamp(value) do
    value
    |> to_string()
    |> String.replace(" UTC", "")
    |> String.replace("Z", "")
  end

  defp to_number(nil), do: 0
  defp to_number(number) when is_integer(number), do: number
  defp to_number(number) when is_float(number), do: number

  defp to_number(number) when is_binary(number) do
    case Float.parse(number) do
      {value, _} -> value
      :error -> 0
    end
  end
end

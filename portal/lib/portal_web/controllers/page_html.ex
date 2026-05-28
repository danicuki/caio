defmodule PortalWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PortalWeb, :html

  embed_templates "page_html/*"

  @default_description "Caio is a cleaner search engine for public tech jobs, with searchable salary, location, company, and source signals."
  @default_image "/images/caio-social-preview.png"

  def meta_title(assigns) do
    case assigns[:page_title] do
      nil -> "Caio · Tech job search"
      title -> "#{title} · Caio"
    end
  end

  def meta_description(assigns), do: assigns[:meta_description] || @default_description

  def canonical_url(assigns) do
    path = assigns[:canonical_path] || current_path(assigns)
    absolute_url(path)
  end

  def og_image_url(_assigns), do: URI.merge(site_url(), @default_image) |> URI.to_string()

  def absolute_url(path) do
    URI.merge(site_url(), path) |> URI.to_string()
  end

  def delimit(number) do
    number
    |> to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp current_path(%{conn: conn}), do: Phoenix.Controller.current_path(conn)
  defp current_path(_assigns), do: "/"

  defp site_url do
    host = System.get_env("PHX_HOST") || "caio-jobs.com"
    scheme = if host in ["localhost", "127.0.0.1"], do: "http", else: "https"
    "#{scheme}://#{host}"
  end
end

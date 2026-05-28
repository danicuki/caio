defmodule PortalWeb.Admin.Actions do
  @moduledoc false

  import Ecto.Query

  def read_only(default_actions), do: Keyword.take(default_actions, [:show])
  def editable(default_actions), do: Keyword.take(default_actions, [:show, :edit])

  # Backpex adds `distinct: field(item, primary_key)` when loading one record.
  # SQLite cannot compile Ecto's generated `distinct: [asc: field]` form, and
  # these admin resources do not use joins that need deduplication.
  def sqlite_item_query(query, _live_action, _assigns), do: exclude(query, :distinct)
end

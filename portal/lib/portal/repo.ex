defmodule Portal.Repo do
  use Ecto.Repo,
    otp_app: :portal,
    adapter: Ecto.Adapters.SQLite3
end

defmodule PortalWeb.Admin.Changesets do
  @moduledoc false

  import Ecto.Changeset

  alias Portal.Accounts.Lead
  alias Portal.FounderChat.Conversation
  alias Portal.Jobs.Company

  def lead(%Lead{} = lead, attrs, _metadata), do: Lead.changeset(lead, attrs)

  def company(%Company{} = company, attrs, _metadata) do
    cast(company, attrs, [:name, :logo_url, :website_url, :description])
  end

  def conversation(%Conversation{} = conversation, attrs, _metadata) do
    conversation
    |> Conversation.changeset(attrs)
    |> validate_inclusion(:status, ["open", "closed"])
  end
end

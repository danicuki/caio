defmodule Portal.EmailTest do
  use Portal.DataCase

  alias Portal.Email

  test "welcome email copy is short and founder-led" do
    text = Email.welcome_email_text()

    assert text =~ "Hey, welcome to Caio."
    assert text =~ "Search, scrape, download"
    assert text =~ "applying online can be exhausting"
    assert text =~ "forms, CV tweaks, and dead-end listings"
    assert text =~ "preparing for interviews"
    assert text =~ "reply here"
    assert text =~ "Daniel"
    assert String.length(text) < 700
  end

  test "email delivery is disabled without explicit Resend config" do
    previous = Application.get_env(:portal, :email)

    Application.put_env(:portal, :email,
      enabled: false,
      api_key: nil,
      from: "Daniel <contact@caio-jobs.com>",
      reply_to: "contact@caio-jobs.com"
    )

    refute Email.enabled?()

    on_exit(fn -> restore_email_config(previous) end)
  end

  defp restore_email_config(nil), do: Application.delete_env(:portal, :email)
  defp restore_email_config(value), do: Application.put_env(:portal, :email, value)
end

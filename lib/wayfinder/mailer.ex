defmodule Wayfinder.Mailer do
  use Swoosh.Mailer, otp_app: :wayfinder

  @doc """
  The `{name, address}` every email is sent from.

  Configured with `config :wayfinder, :mail_from, ...` (see config/runtime.exs).
  """
  def default_from do
    Application.get_env(:wayfinder, :mail_from, {"Wayfinder", "no-reply@example.com"})
  end
end

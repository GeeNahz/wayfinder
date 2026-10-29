defmodule Wayfinder.Repo do
  use Ecto.Repo,
    otp_app: :wayfinder,
    adapter: Ecto.Adapters.Postgres
end

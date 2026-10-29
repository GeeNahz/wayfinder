defmodule Wayfinder.Directory.Janitor do
  @moduledoc """
  A small background process that tidies up once an hour:

    * deletes churches whose email was never verified (after 48 hours)
    * deletes expired verification/manage tokens

  It's started from `Wayfinder.Application` (but not in tests, see
  `config/test.exs`).
  """
  use GenServer

  require Logger

  alias Wayfinder.Directory

  @interval :timer.hours(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Wait a minute after boot before the first clean-up.
    schedule(:timer.minutes(1))
    {:ok, %{}}
  end

  @impl true
  def handle_info(:clean_up, state) do
    churches = Directory.delete_expired_unverified_churches()
    tokens = Directory.delete_expired_tokens()

    if churches + tokens > 0 do
      Logger.info("Janitor removed #{churches} unverified churches and #{tokens} expired tokens")
    end

    schedule(@interval)
    {:noreply, state}
  end

  defp schedule(after_ms), do: Process.send_after(self(), :clean_up, after_ms)
end

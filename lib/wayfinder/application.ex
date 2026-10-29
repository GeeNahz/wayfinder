defmodule Wayfinder.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WayfinderWeb.Telemetry,
      Wayfinder.Repo,
      {DNSCluster, query: Application.get_env(:wayfinder, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Wayfinder.PubSub},
      # Hourly clean-up of unverified churches and expired links
      janitor(),
      # Start to serve requests, typically the last entry
      WayfinderWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wayfinder.Supervisor]
    Supervisor.start_link(Enum.reject(children, &is_nil/1), opts)
  end

  defp janitor do
    if Application.get_env(:wayfinder, :start_janitor, true) do
      Wayfinder.Directory.Janitor
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WayfinderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

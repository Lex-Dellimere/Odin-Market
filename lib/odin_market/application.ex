defmodule OdinMarket.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OdinMarketWeb.Telemetry,
      OdinMarket.Repo,
      {DNSCluster, query: Application.get_env(:odin_market, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OdinMarket.PubSub},
      # Start a worker by calling: OdinMarket.Worker.start_link(arg)
      # {OdinMarket.Worker, arg},
      # Start to serve requests, typically the last entry
      OdinMarketWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OdinMarket.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OdinMarketWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

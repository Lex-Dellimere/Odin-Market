defmodule OdinMarket.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OdinMarketWeb.Telemetry,
      OdinMarket.Repo,
      {DNSCluster, query: Application.get_env(:odin_market, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OdinMarket.PubSub},
      OdinMarketWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :odin_market]}
    ]

    opts = [strategy: :one_for_one, name: OdinMarket.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    OdinMarketWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

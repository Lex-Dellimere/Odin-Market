defmodule OdinMarket.Repo do
  use AshPostgres.Repo,
    otp_app: :odin_market

  @impl true
  def installed_extensions do
    # extensions the migration generator installs
    ["ash-functions", "citext"]
  end

  # ash 4 will default this to false
  @impl true
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end

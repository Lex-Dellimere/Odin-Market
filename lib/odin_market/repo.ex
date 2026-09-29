defmodule OdinMarket.Repo do
  use Ecto.Repo,
    otp_app: :odin_market,
    adapter: Ecto.Adapters.Postgres
end

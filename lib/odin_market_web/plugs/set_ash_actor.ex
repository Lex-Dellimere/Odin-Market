defmodule OdinMarketWeb.Plugs.SetAshActor do
  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil -> conn
      user -> Ash.PlugHelpers.set_actor(conn, user)
    end
  end
end

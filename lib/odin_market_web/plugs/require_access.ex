defmodule OdinMarketWeb.Plugs.RequireAccess do
  @moduledoc """
  Phoenix plugs that sit in front of signed-in and vendor LiveViews.
  """

  use OdinMarketWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  def init(mode), do: mode

  def call(conn, :authenticated) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        conn
        |> put_flash(:error, "Sign in to continue.")
        |> put_session(:return_to, safe_return_to(current_path(conn)))
        |> redirect(to: ~p"/sign-in")
        |> halt()

      closed?(user) ->
        conn
        |> redirect(to: ~p"/sign-out")
        |> halt()

      true ->
        conn
    end
  end

  def call(conn, :staff) do
    user = OdinMarket.Accounts.fresh_user(conn.assigns[:current_user])

    cond do
      is_nil(user) or closed?(user) ->
        conn
        |> put_flash(:error, "Sign in to continue.")
        |> redirect(to: ~p"/sign-in")
        |> halt()

      OdinMarket.Moderation.staff?(user) ->
        assign(conn, :current_user, user)

      true ->
        conn
        |> redirect(to: ~p"/")
        |> halt()
    end
  end

  def call(conn, :vendor) do
    user = OdinMarket.Accounts.fresh_user(conn.assigns[:current_user])

    cond do
      is_nil(conn.assigns[:current_user]) ->
        conn
        |> put_flash(:error, "Sign in to continue.")
        |> put_session(:return_to, safe_return_to(current_path(conn)))
        |> redirect(to: ~p"/sign-in")
        |> halt()

      OdinMarket.Accounts.vendor?(user) ->
        conn

      true ->
        conn
        |> put_flash(:error, "Subscribe to Vendor to sell.")
        |> redirect(to: ~p"/vendor/pricing")
        |> halt()
    end
  end

  defp safe_return_to("/" <> _ = path) do
    if String.starts_with?(path, "//") or String.contains?(path, "://") do
      "/"
    else
      path
    end
  end

  defp safe_return_to(_), do: "/"

  defp closed?(%{deleted_at: deleted_at}) when not is_nil(deleted_at), do: true

  defp closed?(%{id: _id} = user) do
    case OdinMarket.Accounts.fresh_user(user) do
      %{deleted_at: deleted_at} when not is_nil(deleted_at) -> true
      nil -> true
      _ -> false
    end
  end

  defp closed?(_), do: true
end

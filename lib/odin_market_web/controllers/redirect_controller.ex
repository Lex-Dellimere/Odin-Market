defmodule OdinMarketWeb.RedirectController do
  use OdinMarketWeb, :controller

  def account(conn, _params), do: redirect(conn, to: ~p"/dashboard/settings")
  def orders(conn, _params), do: redirect(conn, to: ~p"/dashboard/orders")

  def order(conn, %{"id" => id}), do: redirect(conn, to: ~p"/dashboard/orders/#{id}")

  def vendor(conn, _params), do: redirect(conn, to: ~p"/dashboard")
  def shop(conn, _params), do: redirect(conn, to: ~p"/dashboard/shop")
  def sales(conn, _params), do: redirect(conn, to: ~p"/dashboard/sales")

  def sale(conn, %{"id" => id}), do: redirect(conn, to: ~p"/dashboard/sales/#{id}")

  def listings(conn, _params), do: redirect(conn, to: ~p"/dashboard/listings")
  def new_listing(conn, _params), do: redirect(conn, to: ~p"/dashboard/listings/new")

  def edit_listing(conn, %{"id" => id}) do
    redirect(conn, to: ~p"/dashboard/listings/#{id}/edit")
  end
end

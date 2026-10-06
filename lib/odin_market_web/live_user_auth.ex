defmodule OdinMarketWeb.LiveUserAuth do
  @moduledoc """
  Loads the signed-in user, shop navigation, and inbox badge for LiveViews.
  """

  import Phoenix.Component
  use OdinMarketWeb, :verified_routes

  def on_mount(:live_user_optional, _params, _session, socket) do
    socket =
      if socket.assigns[:current_user] do
        socket
      else
        assign(socket, :current_user, nil)
      end

    continue(shell(socket))
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      continue(shell(socket))
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Sign in to continue.")
       |> Phoenix.LiveView.redirect(to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_staff_required, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if OdinMarket.Moderation.staff?(user) do
      {:cont, assign(socket, :staff_role, user.role)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:live_vendor_required, _params, _session, socket) do
    user = socket.assigns[:current_user]
    profile = OdinMarket.Accounts.profile_for(user)

    if OdinMarket.Accounts.vendor?(user) do
      {:cont, assign(socket, :vendor_profile, profile)}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Subscribe to Vendor to sell.")
       |> Phoenix.LiveView.redirect(to: ~p"/vendor/pricing")}
    end
  end

  defp continue({:halt, socket}), do: {:halt, socket}
  defp continue(socket), do: {:cont, socket}

  defp shell(socket) do
    user =
      OdinMarket.Accounts.fresh_user(socket.assigns[:current_user]) ||
        socket.assigns[:current_user]

    if user && user.deleted_at do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-out")}
    else
      mount_shell(socket, user)
    end
  end

  defp mount_shell(socket, user) do
    if Phoenix.LiveView.connected?(socket) && user do
      Phoenix.PubSub.subscribe(OdinMarket.PubSub, "chat:user:#{user.id}")
    end

    socket
    |> assign(:current_user, user)
    |> assign(:current_scope, %{user: user, cart_count: OdinMarket.Orders.cart_count(user)})
    |> assign(:vendor_profile, socket.assigns[:vendor_profile])
    |> assign(:nav_categories, OdinMarket.Catalog.list_categories())
    |> assign(:nav_query, socket.assigns[:nav_query] || "")
    |> assign(:unread_count, OdinMarket.Messaging.unread_count(user))
    |> Phoenix.LiveView.attach_hook(:inbox_unread, :handle_info, &inbox_hook/2)
  end

  defp inbox_hook(:inbox, socket) do
    {:cont,
     assign(socket, :unread_count, OdinMarket.Messaging.unread_count(socket.assigns.current_user))}
  end

  defp inbox_hook(_message, socket), do: {:cont, socket}
end

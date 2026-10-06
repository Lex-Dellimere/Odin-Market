defmodule OdinMarketWeb.VendorPricingLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Accounts
  alias OdinMarket.Billing
  alias OdinMarket.Errors

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Vendor")
     |> assign(:plans, Billing.plans())
     |> assign(:profile, user && Accounts.profile_for(user))
     |> assign(:vendor?, Accounts.vendor?(user))}
  end

  @impl true
  def handle_event("subscribe", %{"plan" => plan}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, redirect(socket, to: ~p"/sign-in")}

      user ->
        case Billing.checkout(user, plan) do
          {:ok, url} ->
            {:noreply, redirect(socket, external: url)}

          {:error, reason} when is_atom(reason) ->
            {:noreply, put_flash(socket, :error, Errors.message(reason))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, Errors.message(:subscription_unconfigured))}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.market_layout
      flash={@flash}
      current_scope={@current_scope}
      nav_categories={@nav_categories}
      unread_count={@unread_count}
      nav_query={@nav_query}
    >
      <.flex id="vendor-pricing" direction="col" gap="gap-8" class="w-full">
        <.flex direction="col" gap="small">
          <h1>Vendor</h1>
          <p>
            One subscription for a shop on Odin. List embedded boards, modules, and custom hardware. Prices are in Australian dollars. GST is not added yet.
          </p>
          <p :if={!@current_user}>
            Sign up as a member first. Vendor is a subscription you add after the account exists.
          </p>
          <p :if={@vendor?}>This account already has an active Vendor subscription.</p>
          <p :if={@profile && !@vendor?}>
            The shop is paused until the subscription is active again. Past sales stay on the dashboard.
          </p>
        </.flex>

        <.grid cols="grid-cols-1 md:grid-cols-3" gap="gap-6" class="w-full items-stretch">
          <.card
            :for={plan <- @plans}
            id={"plan-#{plan.id}"}
            variant="base"
            color="natural"
            rounded="small"
            padding="medium"
            space="medium"
            class="h-full"
          >
            <h2>{plan.name}</h2>
            <p class="text-[1.4em] font-semibold">{plan.amount}</p>
            <p>{plan.detail}</p>
            <%= if @vendor? do %>
              <.button_link
                navigate={~p"/dashboard"}
                variant="outline"
                color="natural"
                size="medium"
                rounded="small"
              >
                Open dashboard
              </.button_link>
            <% else %>
              <%= if @current_user do %>
                <.button
                  id={"subscribe-#{plan.id}"}
                  type="button"
                  variant="default"
                  color="dark"
                  size="medium"
                  rounded="small"
                  phx-click="subscribe"
                  phx-value-plan={plan.id}
                >
                  Subscribe
                </.button>
              <% else %>
                <.button_link
                  id={"subscribe-#{plan.id}"}
                  navigate={~p"/register"}
                  variant="default"
                  color="dark"
                  size="medium"
                  rounded="small"
                >
                  Create an account
                </.button_link>
              <% end %>
            <% end %>
          </.card>
        </.grid>
      </.flex>
    </.market_layout>
    """
  end
end

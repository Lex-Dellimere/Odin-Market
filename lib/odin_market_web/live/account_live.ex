defmodule OdinMarketWeb.AccountLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Accounts
  alias OdinMarket.Billing
  alias OdinMarket.Errors
  alias OdinMarket.Payments

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    title = if socket.assigns.live_action == :billing, do: "Billing", else: "Settings"

    {:ok,
     socket
     |> assign(:page_title, title)
     |> assign(:form, profile_form(user))
     |> assign(:delete_form, delete_form(user))
     |> assign(:cards, Accounts.list_cards(user))
     |> assign(:profile, Accounts.profile_for(user))
     |> assign(:vendor?, Accounts.vendor?(user))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["card"] do
        "saved" ->
          put_flash(socket, :info, "If Stripe confirmed the card, it is listed below.")

        "cancelled" ->
          put_flash(socket, :info, "Card saving was cancelled.")

        _ ->
          socket
      end

    user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:cards, Accounts.list_cards(user))
     |> assign(:profile, Accounts.profile_for(user))
     |> assign(:vendor?, Accounts.vendor?(user))}
  end

  @impl true
  def handle_event("save-profile", %{"profile" => params}, socket) do
    case Accounts.save_profile(socket.assigns.current_user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:current_scope, %{
           user: user,
           cart_count: socket.assigns.current_scope.cart_count
         })
         |> assign(:form, profile_form(user))
         |> put_flash(:info, "Account updated.")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("clear-address", _params, socket) do
    blank = %{
      "ship_name" => "",
      "ship_line1" => "",
      "ship_line2" => "",
      "ship_city" => "",
      "ship_region" => "",
      "ship_postal_code" => "",
      "ship_country" => ""
    }

    case Accounts.save_profile(socket.assigns.current_user, blank) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:form, profile_form(user))
         |> put_flash(:info, "Address cleared.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "The address could not be cleared.")}
    end
  end

  def handle_event("save-card", _params, socket) do
    case Payments.start_card_setup(socket.assigns.current_user) do
      {:ok, url, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> redirect(external: url)}

      {:error, reason} when is_atom(reason) ->
        {:noreply, put_flash(socket, :error, Errors.message(reason))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, Errors.message(:not_configured))}
    end
  end

  def handle_event("remove-card", %{"id" => id}, socket) do
    card = Enum.find(socket.assigns.cards, &(&1.id == id))

    result =
      if card do
        Accounts.remove_card(card, socket.assigns.current_user)
      else
        {:error, :not_found}
      end

    case result do
      :ok ->
        {:noreply, refresh_cards(socket, "Card removed.")}

      {:ok, _} ->
        {:noreply, refresh_cards(socket, "Card removed.")}

      {:error, reason} when is_atom(reason) ->
        {:noreply, put_flash(socket, :error, Errors.message(reason))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That card could not be removed.")}
    end
  end

  def handle_event("manage-subscription", _params, socket) do
    case Billing.portal(socket.assigns.current_user) do
      {:ok, url} ->
        {:noreply, redirect(socket, external: url)}

      {:error, reason} when is_atom(reason) ->
        {:noreply, put_flash(socket, :error, Errors.message(reason))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, Errors.message(:subscription_unconfigured))}
    end
  end

  def handle_event("delete-account", %{"account" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.delete_form, params: params) do
      {:ok, _user} ->
        {:noreply, redirect(socket, to: ~p"/sign-out")}

      {:error, form} ->
        {:noreply, assign(socket, :delete_form, to_form(form))}
    end
  end

  defp refresh_cards(socket, message) do
    socket
    |> assign(:cards, Accounts.list_cards(socket.assigns.current_user))
    |> put_flash(:info, message)
  end

  defp profile_form(user) do
    user
    |> AshPhoenix.Form.for_update(:save_profile,
      domain: Accounts,
      actor: user,
      as: "profile"
    )
    |> to_form()
  end

  defp delete_form(user) do
    user
    |> AshPhoenix.Form.for_update(:delete_account,
      domain: Accounts,
      actor: user,
      as: "account"
    )
    |> to_form()
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
      <.flex direction="col" gap="gap-10" class="w-full">
        <.flex direction="col" gap="small">
          <h1>{if(@live_action == :billing, do: "Billing", else: "Settings")}</h1>
          <p>{to_string(@current_user.email)}</p>
        </.flex>

        <.dashboard_links
          vendor?={@vendor?}
          current={if(@live_action == :billing, do: :billing, else: :settings)}
        />

        <%= if @live_action == :settings do %>
          <.form_wrapper
            for={@form}
            id="account-form"
            phx-submit="save-profile"
            variant="transparent"
            space="medium"
            rounded="small"
          >
            <.card
              id="settings-profile"
              variant="base"
              color="natural"
              rounded="small"
              padding="medium"
              space="medium"
            >
              <h2>Profile</h2>
              <.text_field
                field={@form[:username]}
                label="Username"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.text_field
                field={@form[:display_name]}
                label="Display name"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
                Save profile
              </.button>
            </.card>
          </.form_wrapper>

          <p>Email and password changes stay on the sign-in screens.</p>

          <.flex :if={@current_user.role != :admin} id="delete-account" direction="col" gap="medium">
            <.button
              type="button"
              variant="outline"
              color="danger"
              size="medium"
              rounded="small"
              phx-click={show_modal("delete-account-modal")}
            >
              Delete account
            </.button>
            <.modal
              id="delete-account-modal"
              title="Delete account"
              variant="base"
              color="natural"
              rounded="small"
              padding="medium"
            >
              <.flex direction="col" gap="medium">
                <p>
                  This signs you out, removes saved cards and the cart, archives your listings, and hides your shop.
                  Open orders must finish first. Past orders stay, and your name becomes “Deleted account”.
                </p>
                <.form_wrapper
                  for={@delete_form}
                  id="delete-account-form"
                  phx-submit="delete-account"
                  variant="transparent"
                  space="medium"
                  rounded="small"
                >
                  <.password_field
                    field={@delete_form[:current_password]}
                    label="Current password"
                    autocomplete="current-password"
                    size="medium"
                    rounded="small"
                    color="natural"
                  />
                  <.button
                    id="delete-account-button"
                    type="submit"
                    variant="default"
                    color="danger"
                    size="medium"
                    rounded="small"
                  >
                    Delete account
                  </.button>
                </.form_wrapper>
              </.flex>
            </.modal>
          </.flex>
        <% else %>
          <.form_wrapper
            for={@form}
            id="address-form"
            phx-submit="save-profile"
            variant="transparent"
            space="medium"
            rounded="small"
          >
            <.card
              id="settings-address"
              variant="base"
              color="natural"
              rounded="small"
              padding="medium"
              space="medium"
            >
              <h2>Address</h2>
              <p>This address is copied onto an order when you check out.</p>
              <.text_field
                field={@form[:ship_name]}
                label="Recipient"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.text_field
                field={@form[:ship_line1]}
                label="Street address"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.text_field
                field={@form[:ship_line2]}
                label="Apartment, suite (optional)"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.grid cols="grid-cols-1 md:grid-cols-3" gap="medium" class="w-full">
                <.text_field
                  field={@form[:ship_city]}
                  label="City"
                  size="medium"
                  rounded="small"
                  color="natural"
                />
                <.text_field
                  field={@form[:ship_region]}
                  label="State or region"
                  size="medium"
                  rounded="small"
                  color="natural"
                />
                <.text_field
                  field={@form[:ship_postal_code]}
                  label="Postal code"
                  size="medium"
                  rounded="small"
                  color="natural"
                />
              </.grid>
              <.text_field
                field={@form[:ship_country]}
                label="Country"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.flex align="center" gap="small">
                <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
                  Save address
                </.button>
                <.button
                  id="clear-address"
                  type="button"
                  variant="outline"
                  color="natural"
                  size="medium"
                  rounded="small"
                  phx-click="clear-address"
                >
                  Clear address
                </.button>
              </.flex>
            </.card>
          </.form_wrapper>

          <.flex id="account-billing" direction="col" gap="medium">
            <h2>Saved cards</h2>
            <.flex id="saved-cards" direction="col" gap="medium">
              <.flex align="center" justify="between" gap="medium">
                <p>
                  The card number is entered on Stripe. Remove a card here when you no longer want it used.
                </p>
                <.button
                  id="save-card"
                  type="button"
                  variant="default"
                  color="dark"
                  size="medium"
                  rounded="small"
                  phx-click="save-card"
                >
                  Save a card
                </.button>
              </.flex>
              <.alert :if={@cards == []} id="cards-empty" kind={:natural} title="No saved cards">
                Save a card when you want Stripe to offer it at checkout.
              </.alert>
              <.flex id="card-list" direction="col" gap="medium">
                <.card
                  :for={card <- @cards}
                  id={"card-#{card.id}"}
                  variant="base"
                  color="natural"
                  rounded="small"
                  padding="medium"
                  space="medium"
                >
                  <.flex align="center" justify="between" gap="medium">
                    <.flex direction="col" gap="medium">
                      <p>{card.brand} ···· {card.last4}</p>
                      <p :if={card.exp_month && card.exp_year}>
                        Expires {card.exp_month}/{card.exp_year}
                      </p>
                    </.flex>
                    <.button
                      type="button"
                      variant="outline"
                      color="natural"
                      size="medium"
                      rounded="small"
                      phx-click={show_modal("remove-card-#{card.id}")}
                    >
                      Remove
                    </.button>
                  </.flex>
                </.card>
                <.modal
                  :for={card <- @cards}
                  id={"remove-card-#{card.id}"}
                  title="Remove card"
                  variant="base"
                  color="natural"
                  rounded="small"
                  padding="medium"
                >
                  <.flex direction="col" gap="medium">
                    <p>Remove {card.brand} ···· {card.last4} from this account.</p>
                    <.button
                      type="button"
                      variant="default"
                      color="danger"
                      size="medium"
                      rounded="small"
                      phx-click="remove-card"
                      phx-value-id={card.id}
                    >
                      Remove card
                    </.button>
                  </.flex>
                </.modal>
              </.flex>
            </.flex>
          </.flex>

          <.card
            id="vendor-subscription"
            variant="base"
            color="natural"
            rounded="small"
            padding="medium"
            space="medium"
          >
            <h2>Vendor subscription</h2>
            <p :if={@vendor?}>Vendor is active. Manage or cancel it in Stripe.</p>
            <p :if={@profile && !@vendor?}>
              Vendor is {@profile.subscription_status}. The shop stays off the market until you subscribe again.
            </p>
            <p :if={!@profile}>
              A Vendor subscription lets this account list embedded electronics. A$25 a month, A$70 every 3 months, or A$240 a year.
            </p>
            <.flex align="center" gap="small">
              <.button_link
                navigate={~p"/vendor/pricing"}
                variant="outline"
                color="natural"
                size="medium"
                rounded="small"
              >
                {if(@vendor?, do: "Pricing", else: "Become a vendor")}
              </.button_link>
              <.button
                :if={@profile}
                id="manage-subscription"
                type="button"
                variant="default"
                color="dark"
                size="medium"
                rounded="small"
                phx-click="manage-subscription"
              >
                Manage in Stripe
              </.button>
            </.flex>
          </.card>
        <% end %>
      </.flex>
    </.market_layout>
    """
  end
end

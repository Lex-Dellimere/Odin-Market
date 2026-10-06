defmodule OdinMarketWeb.VendorDashboardLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Catalog
  alias OdinMarket.Catalog.Listing
  alias OdinMarket.Uploads

  @impl true
  def mount(_params, _session, socket) do
    profile = socket.assigns.vendor_profile
    user = socket.assigns.current_user
    listings = Catalog.vendor_listings(profile, user)

    {:ok,
     socket
     |> assign(:page_title, "Vendor")
     |> assign(:listings, listings)
     |> assign(:listing, nil)
     |> assign(:photo_error, nil)
     |> assign(:category_groups, Catalog.category_menu(Catalog.list_categories()))
     |> assign(:form, new_listing_form(user))
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 4,
       max_file_size: 5_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate", %{"listing" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, prepare_params(params))
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"listing" => params}, socket) do
    params = prepare_params(params)

    if publishing_without_photo?(socket, params) do
      {:noreply,
       assign(
         socket,
         :photo_error,
         "Add a photo before publishing. Save as a draft if the photo is not ready."
       )}
    else
      save_listing(socket, params)
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    listing = Enum.find(socket.assigns.listings, &(&1.id == id))
    user = socket.assigns.current_user

    case listing && Ash.update(listing, %{}, action: :archive, actor: user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:listings, Catalog.vendor_listings(socket.assigns.vendor_profile, user))
         |> put_flash(:info, "Listing archived.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not archive that listing.")}
    end
  end

  def handle_event("set-stock", %{"id" => id, "stock" => %{"qty" => qty}}, socket) do
    listing = Enum.find(socket.assigns.listings, &(&1.id == id))

    case listing && Catalog.set_stock(listing, qty, socket.assigns.current_user) do
      {:ok, _listing} ->
        listings =
          Catalog.vendor_listings(socket.assigns.vendor_profile, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:listings, listings)
         |> put_flash(:info, "Stock updated.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Enter a stock quantity of zero or more.")}
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
      <.flex direction="col" gap="gap-10">
        <.flex direction="col" gap="small">
          <h1>{@vendor_profile.shop_name}</h1>
          <p>
            Publish a listing, set the stock, and follow sales. The same account can still buy parts.
          </p>
        </.flex>
        <.dashboard_links vendor?={true} current={:listings} />
        <.grid cols="grid-cols-1 sm:grid-cols-3" gap="medium" class="w-full">
          <.card variant="base" color="natural" rounded="small" padding="medium" space="small">
            <p>Listings</p>
            <h2>{length(@listings)}</h2>
          </.card>
          <.card variant="base" color="natural" rounded="small" padding="medium" space="small">
            <p>Active</p>
            <h2>{count_status(@listings, :active)}</h2>
          </.card>
          <.card variant="base" color="natural" rounded="small" padding="medium" space="small">
            <p>In stock</p>
            <h2>{count_stock(@listings)}</h2>
          </.card>
        </.grid>
        <.flex direction="col" gap="medium" class="w-full">
          <h2>New listing</h2>
          <.listing_editor
            form={@form}
            category_groups={@category_groups}
            photo_error={@photo_error}
            listing={@listing}
            uploads={@uploads}
          />
        </.flex>
        <h2>Your listings</h2>
        <.listing_table listings={@listings} />
        <h2>Stock</h2>
        <.stock_manager listings={stock_listings(@listings)} />
      </.flex>
    </.market_layout>
    """
  end

  attr :listings, :list, required: true

  defp listing_table(assigns) do
    ~H"""
    <.alert :if={@listings == []} kind={:natural} title="No listings">
      Publish a part so buyers can find it.
    </.alert>
    <.table
      :if={@listings != []}
      id="vendor-listings"
      rows={@listings}
      variant="base"
      color="natural"
      rounded="small"
      padding="medium"
    >
      <:col :let={listing} label="Title">{listing.title}</:col>
      <:col :let={listing} label="Category">{category_label(listing.category)}</:col>
      <:col :let={listing} label="Price">{money(listing.price_cents)}</:col>
      <:col :let={listing} label="Shipping">{shipping_label(listing)}</:col>
      <:col :let={listing} label="Stock">{stock_text(listing)}</:col>
      <:col :let={listing} label="Status">{status_label(listing.status)}</:col>
      <:col :let={listing} label="">
        <.flex align="center" gap="medium" wrap="nowrap">
          <.button_link
            id={"edit-listing-#{listing.id}"}
            navigate={~p"/dashboard/listings/#{listing.id}/edit"}
            variant="outline"
            color="natural"
            size="medium"
            rounded="small"
          >
            Edit
          </.button_link>
          <.button
            :if={listing.status != :archived}
            id={"delete-listing-#{listing.id}"}
            type="button"
            variant="outline"
            color="danger"
            size="medium"
            rounded="small"
            phx-click="archive"
            phx-value-id={listing.id}
          >
            Delete
          </.button>
        </.flex>
      </:col>
    </.table>
    """
  end

  attr :listings, :list, required: true

  defp stock_manager(assigns) do
    ~H"""
    <.alert :if={@listings == []} id="stock-empty" kind={:natural} title="No stock listings">
      Custom builds do not track a quantity. Publish an in-stock part to manage it here.
    </.alert>
    <.flex id="stock-manager" direction="col" gap="medium">
      <.card
        :for={listing <- @listings}
        id={"stock-#{listing.id}"}
        variant="base"
        color="natural"
        rounded="small"
        padding="medium"
        space="medium"
      >
        <p>{listing.title}</p>
        <p>
          {money(listing.price_cents)} · {shipping_label(listing)} · {status_label(listing.status)}
        </p>
        <.form_wrapper
          for={to_form(%{"qty" => listing.qty_available}, as: :stock)}
          id={"stock-form-#{listing.id}"}
          phx-submit="set-stock"
          variant="transparent"
          space="medium"
          rounded="small"
        >
          <.flex align="center" gap="medium">
            <.number_field
              name="stock[qty]"
              id={"stock-qty-#{listing.id}"}
              value={listing.qty_available}
              label="Quantity"
              min="0"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.button
              type="submit"
              name="id"
              value={listing.id}
              variant="default"
              color="dark"
              size="medium"
              rounded="small"
            >
              Save stock
            </.button>
          </.flex>
        </.form_wrapper>
      </.card>
    </.flex>
    """
  end

  defp stock_listings(listings), do: Enum.filter(listings, &(&1.kind == :stock))

  defp count_status(listings, status), do: Enum.count(listings, &(&1.status == status))

  defp count_stock(listings) do
    Enum.count(listings, &(&1.kind == :stock and &1.status != :archived))
  end

  defp stock_text(%{qty_available: qty}) when is_integer(qty), do: to_string(qty)
  defp stock_text(_), do: "0"

  defp new_listing_form(actor) do
    Listing
    |> AshPhoenix.Form.for_create(:publish,
      domain: Catalog,
      actor: actor,
      as: "listing",
      params: %{"kind" => "stock", "status" => "draft"}
    )
    |> to_form()
  end

  defp prepare_params(params) do
    params =
      case params["shipping_cents"] do
        blank when blank in [nil, ""] -> Map.put(params, "shipping_cents", "0")
        _ -> params
      end

    case params["kind"] do
      "custom" -> Map.drop(params, ["qty_available"])
      _ -> Map.drop(params, ["lead_days"])
    end
  end

  defp publishing_without_photo?(socket, params) do
    params["status"] == "active" and is_nil(socket.assigns.listing) and upload_count(socket) < 1
  end

  defp upload_count(socket) do
    case socket.assigns[:uploads] do
      %{images: %{entries: entries}} -> length(entries)
      _ -> 0
    end
  end

  defp save_listing(socket, params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, listing} ->
        urls = Uploads.persist(socket, listing.id)
        user = socket.assigns.current_user

        case Catalog.add_images(listing, urls, user) do
          :ok ->
            {:noreply,
             socket
             |> assign(:listings, Catalog.vendor_listings(socket.assigns.vendor_profile, user))
             |> assign(:form, new_listing_form(user))
             |> assign(:photo_error, nil)
             |> put_flash(:info, "Listing saved.")}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "The listing was saved, but a photo was not.")
             |> push_navigate(to: ~p"/dashboard/listings/#{listing.id}/edit")}
        end

      {:error, form} ->
        {:noreply, assign(socket, form: form, photo_error: nil)}
    end
  end
end

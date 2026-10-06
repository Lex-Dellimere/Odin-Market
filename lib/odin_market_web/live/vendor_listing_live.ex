defmodule OdinMarketWeb.VendorListingLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Catalog
  alias OdinMarket.Catalog.Listing
  alias OdinMarket.Uploads

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Listings",
       listing: nil,
       missing: false,
       photo_error: nil,
       category_groups: Catalog.category_menu(Catalog.list_categories())
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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

  def handle_event("archive", _params, socket) do
    case Ash.update(socket.assigns.listing, %{},
           action: :archive,
           actor: socket.assigns.current_user
         ) do
      {:ok, _listing} ->
        {:noreply,
         socket
         |> put_flash(:info, "Listing archived.")
         |> push_navigate(to: ~p"/dashboard/listings")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not archive that listing.")}
    end
  end

  def handle_event("delete-image", %{"id" => id}, socket) do
    listing = socket.assigns.listing
    image = Enum.find(image_list(listing), &(&1.id == id))

    socket =
      if image do
        Catalog.delete_image(image, socket.assigns.current_user)

        case Catalog.get_owned(listing.id, socket.assigns.current_user) do
          {:ok, fresh} -> assign(socket, :listing, fresh)
          _ -> socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  defp save_listing(socket, params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, listing} ->
        urls = Uploads.persist(socket, listing.id)

        case Catalog.add_images(listing, urls, socket.assigns.current_user) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Listing saved.")
             |> push_navigate(to: ~p"/dashboard/listings")}

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

  defp publishing_without_photo?(socket, params) do
    params["status"] == "active" and is_nil(socket.assigns.listing) and upload_count(socket) < 1
  end

  defp upload_count(socket) do
    case socket.assigns[:uploads] do
      %{images: %{entries: entries}} -> length(entries)
      _ -> 0
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New listing")
    |> assign(:listing, nil)
    |> assign(:missing, false)
    |> assign(:form, listing_form(socket.assigns.current_user, nil))
    |> maybe_uploads(nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Catalog.get_owned(id, socket.assigns.current_user) do
      {:ok, listing} ->
        socket
        |> assign(:page_title, "Edit listing")
        |> assign(:listing, listing)
        |> assign(:missing, false)
        |> assign(:form, listing_form(socket.assigns.current_user, listing))
        |> maybe_uploads(listing)

      _ ->
        assign(socket, listing: nil, missing: true, page_title: "Not found")
    end
  end

  defp listing_form(actor, nil) do
    Listing
    |> AshPhoenix.Form.for_create(:publish,
      domain: Catalog,
      actor: actor,
      as: "listing",
      params: %{"kind" => "stock", "status" => "draft"}
    )
    |> to_form()
  end

  defp listing_form(actor, listing) do
    listing
    |> AshPhoenix.Form.for_update(:save,
      domain: Catalog,
      actor: actor,
      as: "listing",
      params: form_params(listing)
    )
    |> to_form()
  end

  defp form_params(listing) do
    specs = listing.specs || %{}

    %{
      "title" => listing.title,
      "description" => listing.description,
      "kind" => Atom.to_string(listing.kind),
      "price_cents" => listing.price_cents,
      "shipping_cents" => listing.shipping_cents || 0,
      "qty_available" => listing.qty_available,
      "lead_days" => listing.lead_days,
      "category_id" => listing.category_id,
      "status" =>
        if(listing.status in [:draft, :active], do: Atom.to_string(listing.status), else: "draft"),
      "voltage" => specs["voltage"],
      "package" => specs["package"],
      "interface" => specs["interface"],
      "mcu" => specs["mcu"]
    }
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

  defp maybe_uploads(socket, listing) do
    remaining = 4 - image_count(listing)
    uploads = socket.assigns[:uploads]

    cond do
      remaining < 1 ->
        socket

      uploads && uploads[:images] ->
        socket

      true ->
        allow_upload(socket, :images,
          accept: ~w(.jpg .jpeg .png .webp),
          max_entries: remaining,
          max_file_size: 5_000_000,
          auto_upload: true
        )
    end
  end

  defp image_count(listing), do: length(image_list(listing))

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
      <.alert :if={@missing} id="not-found" kind={:danger} title="Not found">
        That listing is not in your shop.
      </.alert>

      <.flex
        :if={@live_action in [:new, :edit] and not @missing}
        direction="col"
        gap="medium"
        class="w-full"
      >
        <h1>
          {if @live_action == :new, do: "New listing", else: "Edit listing"}
        </h1>
        <.dashboard_links vendor?={true} current={:listings} />
        <.listing_editor
          form={@form}
          category_groups={@category_groups}
          photo_error={@photo_error}
          listing={@listing}
          uploads={@uploads}
        />
      </.flex>
    </.market_layout>
    """
  end
end

defmodule OdinMarket.Catalog do
  use Ash.Domain, otp_app: :odin_market, extensions: [AshAdmin.Domain]

  require Ash.Query

  alias OdinMarket.Catalog.Category
  alias OdinMarket.Catalog.Listing
  alias OdinMarket.Catalog.ListingImage

  admin do
    show? true
  end

  resources do
    resource Category
    resource Listing
    resource ListingImage
  end

  @page_size 12

  def list_categories do
    Category
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(authorize?: false)
  end

  def families(categories) when is_list(categories) do
    Enum.filter(categories, &is_nil(&1.parent_id))
  end

  def category_menu(categories) when is_list(categories) do
    grouped = Enum.group_by(categories, & &1.parent_id)

    categories
    |> families()
    |> Enum.map(fn parent ->
      children = grouped |> Map.get(parent.id, []) |> Enum.sort_by(& &1.name)
      %{parent: parent, children: children}
    end)
  end

  def search(params \\ %{}, opts \\ []) do
    page = page_number(fetch(params, "page"))

    query =
      Listing
      |> Ash.Query.for_read(:search, search_args(params), actor: opts[:actor])

    case Ash.read(query, page: [offset: (page - 1) * @page_size, limit: @page_size, count: true]) do
      {:ok, %Ash.Page.Offset{} = result} ->
        count = result.count || length(result.results)
        pages = div(count + @page_size - 1, @page_size)

        {:ok,
         %{
           results: result.results,
           page: page,
           total_pages: if(pages < 1, do: 1, else: pages),
           count: count
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  def get_by_slug(slug) when is_binary(slug) do
    Listing
    |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
    |> Ash.Query.load([:images, :vendor, category: :parent])
    |> Ash.read_one()
    |> normalize_one()
  end

  def get_by_slug(_), do: {:error, :not_found}

  def get_listing(id) do
    with {:ok, uuid} <- cast_uuid(id) do
      Listing
      |> Ash.Query.filter(id == ^uuid)
      |> Ash.Query.load([:images, :vendor, category: :parent])
      |> Ash.read_one(authorize?: false)
      |> normalize_one()
    end
  end

  def get_owned(id, actor) do
    with {:ok, uuid} <- cast_uuid(id) do
      Listing
      |> Ash.Query.filter(id == ^uuid)
      |> Ash.Query.load([:images, :vendor, category: :parent])
      |> Ash.read_one(actor: actor)
      |> normalize_one()
    end
  end

  def set_stock(listing, qty, actor) do
    Ash.update(listing, %{qty_available: parse_stock(qty)}, action: :set_stock, actor: actor)
  end

  def vendor_listings(profile, actor) do
    Listing
    |> Ash.Query.filter(vendor_id == ^profile.id)
    |> Ash.Query.sort(updated_at: :desc)
    |> Ash.Query.load([:images, category: :parent])
    |> Ash.read!(actor: actor)
  end

  def add_images(listing, urls, actor) when is_list(urls) do
    start = next_position(listing)

    urls
    |> Enum.with_index(start)
    |> Enum.reduce_while(:ok, fn {url, position}, :ok ->
      case Ash.create(
             ListingImage,
             %{listing_id: listing.id, url: url, position: position},
             action: :create,
             actor: actor
           ) do
        {:ok, _image} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp parse_stock(qty) when is_integer(qty), do: qty

  defp parse_stock(qty) when is_binary(qty) do
    case Integer.parse(String.trim(qty)) do
      {parsed, ""} -> parsed
      _ -> -1
    end
  end

  defp parse_stock(_qty), do: -1

  def delete_image(image, actor) do
    case Ash.destroy(image, actor: actor) do
      :ok ->
        OdinMarket.Uploads.delete_file(image.url)
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp next_position(listing) do
    images =
      case listing.images do
        list when is_list(list) -> list
        _ -> []
      end

    images
    |> Enum.map(& &1.position)
    |> Enum.max(fn -> -1 end)
    |> Kernel.+(1)
  end

  defp search_args(params) do
    [
      :q,
      :category_id,
      :kind,
      :vendor_id,
      :min_price,
      :max_price,
      :in_stock,
      :max_lead_days,
      :sort
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case fetch(params, Atom.to_string(key)) do
        value when value in [nil, ""] -> acc
        value -> Map.put(acc, key, to_string(value))
      end
    end)
  end

  defp fetch(params, key) when is_map(params) do
    Map.get(params, key) || Map.get(params, atom_key(key))
  end

  defp fetch(_, _), do: nil

  defp atom_key("q"), do: :q
  defp atom_key("category_id"), do: :category_id
  defp atom_key("kind"), do: :kind
  defp atom_key("vendor_id"), do: :vendor_id
  defp atom_key("min_price"), do: :min_price
  defp atom_key("max_price"), do: :max_price
  defp atom_key("in_stock"), do: :in_stock
  defp atom_key("max_lead_days"), do: :max_lead_days
  defp atom_key("sort"), do: :sort
  defp atom_key("page"), do: :page
  defp atom_key(_), do: nil

  defp page_number(value) do
    case Integer.parse(to_string(value || "")) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp cast_uuid(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      _ -> {:error, :not_found}
    end
  end

  defp cast_uuid(_), do: {:error, :not_found}

  defp normalize_one({:ok, nil}), do: {:error, :not_found}
  defp normalize_one({:ok, record}), do: {:ok, record}
  defp normalize_one({:error, _}), do: {:error, :not_found}
end

defmodule OdinMarket.Catalog.Preparations.SearchListings do
  use Ash.Resource.Preparation

  require Ash.Query

  alias OdinMarket.Catalog.Category

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> Ash.Query.filter(status == :active and vendor.status == :active and vendor.held == false)
    |> filter_text()
    |> filter_category()
    |> filter_kind()
    |> filter_vendor()
    |> filter_price()
    |> filter_stock()
    |> filter_lead()
    |> sort_results()
    |> Ash.Query.load([:images, :vendor, category: :parent])
  end

  defp filter_text(query) do
    case like_term(Ash.Query.get_argument(query, :q)) do
      nil ->
        query

      term ->
        Ash.Query.filter(query, ilike(title, ^term) or ilike(description, ^term))
    end
  end

  defp filter_category(query) do
    case uuid(Ash.Query.get_argument(query, :category_id)) do
      nil ->
        query

      id ->
        ids = category_ids(id)
        Ash.Query.filter(query, category_id in ^ids)
    end
  end

  defp category_ids(id) do
    children =
      Category
      |> Ash.Query.filter(parent_id == ^id)
      |> Ash.read!(authorize?: false)

    [id | Enum.map(children, & &1.id)]
  end

  defp filter_kind(query) do
    case kind(Ash.Query.get_argument(query, :kind)) do
      nil -> query
      value -> Ash.Query.filter(query, kind == ^value)
    end
  end

  defp filter_vendor(query) do
    case uuid(Ash.Query.get_argument(query, :vendor_id)) do
      nil -> query
      id -> Ash.Query.filter(query, vendor_id == ^id)
    end
  end

  defp filter_price(query) do
    query
    |> maybe_min(cents(Ash.Query.get_argument(query, :min_price)))
    |> maybe_max(cents(Ash.Query.get_argument(query, :max_price)))
  end

  defp maybe_min(query, nil), do: query
  defp maybe_min(query, min), do: Ash.Query.filter(query, price_cents >= ^min)

  defp maybe_max(query, nil), do: query
  defp maybe_max(query, max), do: Ash.Query.filter(query, price_cents <= ^max)

  defp filter_stock(query) do
    if truthy?(Ash.Query.get_argument(query, :in_stock)) do
      Ash.Query.filter(query, kind == :custom or qty_available > 0)
    else
      query
    end
  end

  defp filter_lead(query) do
    case integer(Ash.Query.get_argument(query, :max_lead_days)) do
      nil -> query
      days -> Ash.Query.filter(query, is_nil(lead_days) or lead_days <= ^days)
    end
  end

  defp sort_results(query) do
    case Ash.Query.get_argument(query, :sort) do
      "price_asc" -> Ash.Query.sort(query, price_cents: :asc, inserted_at: :desc)
      "price_desc" -> Ash.Query.sort(query, price_cents: :desc, inserted_at: :desc)
      _ -> Ash.Query.sort(query, inserted_at: :desc)
    end
  end

  defp like_term(value) when is_binary(value) do
    cleaned = value |> String.trim() |> String.replace(["%", "_"], "")

    if cleaned == "" do
      nil
    else
      "%" <> cleaned <> "%"
    end
  end

  defp like_term(_), do: nil

  defp uuid(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, id} -> id
      _ -> nil
    end
  end

  defp uuid(_), do: nil

  defp kind("stock"), do: :stock
  defp kind("custom"), do: :custom
  defp kind(_), do: nil

  defp cents(value) when is_integer(value) and value >= 0, do: value

  defp cents(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} when number >= 0 -> round(number * 100)
      _ -> nil
    end
  end

  defp cents(_), do: nil

  defp integer(value) when is_integer(value) and value >= 0, do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {number, ""} when number >= 0 -> number
      _ -> nil
    end
  end

  defp integer(_), do: nil

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false
end

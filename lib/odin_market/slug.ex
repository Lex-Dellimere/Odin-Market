defmodule OdinMarket.Slug do
  def unique(value, exists?) when is_function(exists?, 1) do
    base = parameterize(value)
    base = if base == "", do: "item", else: base

    if exists?.(base) do
      next(base, 2, exists?)
    else
      base
    end
  end

  def parameterize(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> String.slice(0, 60)
    |> String.trim("-")
  end

  defp next(base, n, exists?) do
    candidate = "#{String.slice(base, 0, 56)}-#{n}"

    if exists?.(candidate) do
      next(base, n + 1, exists?)
    else
      candidate
    end
  end
end

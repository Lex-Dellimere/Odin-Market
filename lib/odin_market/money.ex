defmodule OdinMarket.Money do
  def format_cents(cents) when is_integer(cents) do
    sign = if cents < 0, do: "-", else: ""
    cents = abs(cents)
    dollars = div(cents, 100)
    remainder = rem(cents, 100)
    "#{sign}A$#{dollars}.#{String.pad_leading(Integer.to_string(remainder), 2, "0")}"
  end

  def format_cents(_), do: "A$0.00"
end

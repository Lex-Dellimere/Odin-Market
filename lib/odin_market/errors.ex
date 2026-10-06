defmodule OdinMarket.Errors do
  def message(:own_listing), do: "You can't buy or message your own listing."
  def message(:inactive), do: "This listing is not available."
  def message(:suspended), do: "This shop is not accepting new messages."
  def message(:above_stock), do: "That quantity is more than the seller has in stock."
  def message(:bad_qty), do: "Enter a quantity of at least 1."
  def message(:not_configured), do: "Card payments are not configured yet."

  def message(:subscription_unconfigured),
    do: "Vendor checkout is not configured yet."

  def message(:not_found), do: "We couldn't find that."
  def message(:unauthenticated), do: "Sign in to continue."
  def message(:empty_cart), do: "Your cart is empty."

  def message(:address_required),
    do: "Add a recipient, street, city, and country before paying."

  def message(:not_a_card), do: "Only cards can be saved here."

  def message(:blank), do: "Write a message first."
  def message(:too_long), do: "Messages can be up to 2000 characters."
  def message(_other), do: "Something went wrong. Try again."
end

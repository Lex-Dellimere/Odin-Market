defmodule OdinMarket.ChatTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Messaging

  setup do
    vendor = register_user(%{role: :vendor, display_name: "Rig"})
    buyer = register_user(%{display_name: "Ada"})
    category = ensure_category("Custom", "custom-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Custom hub",
        kind: :custom,
        lead_days: 5,
        qty_available: nil
      })

    %{buyer: buyer, vendor: vendor, listing: listing}
  end

  test "opening a listing thread twice returns the same conversation", %{
    buyer: buyer,
    listing: listing
  } do
    assert {:ok, first} = Messaging.open_for_listing(buyer, listing.id)
    assert {:ok, second} = Messaging.open_for_listing(buyer, listing.id)
    assert first.id == second.id
  end

  test "a blank message is rejected", %{buyer: buyer, listing: listing} do
    assert {:ok, conversation} = Messaging.open_for_listing(buyer, listing.id)
    assert {:error, :blank} = Messaging.send(buyer, conversation.id, "   ")
  end

  test "a reply is stored and the other side is marked read", %{
    buyer: buyer,
    vendor: vendor,
    listing: listing
  } do
    assert {:ok, conversation} = Messaging.open_for_listing(buyer, listing.id)
    assert {:ok, message} = Messaging.send(buyer, conversation.id, "Is the lead time firm?")
    assert {:ok, _} = Messaging.send(vendor, conversation.id, "Yes, five days.")

    touched =
      Ash.get!(OdinMarket.Chat.Conversation, conversation.id, authorize?: false)

    assert DateTime.compare(touched.updated_at, conversation.updated_at) != :lt

    assert {:ok, _} = Messaging.get_thread(vendor, conversation.id)

    reloaded = Ash.get!(OdinMarket.Chat.Message, message.id, authorize?: false)
    assert reloaded.read_at
  end
end

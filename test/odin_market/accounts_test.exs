defmodule OdinMarket.AccountsTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Accounts.User
  alias OdinMarket.Catalog
  alias OdinMarket.Orders
  alias OdinMarket.Orders.Order

  test "deleting an account anonymizes it and blocks the old password" do
    user = register_user(%{display_name: "Ada"})
    email = to_string(user.email)

    assert {:ok, deleted} =
             Ash.update(user, %{current_password: "password123456"},
               action: :delete_account,
               actor: user
             )

    assert deleted.display_name == "Deleted account"
    assert deleted.deleted_at
    assert to_string(deleted.email) =~ "deleted-"

    strategy = AshAuthentication.Info.strategy!(User, :password)

    assert {:error, _} =
             AshAuthentication.Strategy.action(strategy, :sign_in, %{
               "email" => email,
               "password" => "password123456"
             })
  end

  test "a wrong password does not delete the account" do
    user = register_user(%{display_name: "Ada"})

    assert {:error, _} =
             Ash.update(user, %{current_password: "not-the-password"},
               action: :delete_account,
               actor: user
             )

    assert {:ok, fresh} = Ash.get(User, user.id, authorize?: false)
    assert fresh.display_name == "Ada"
    assert is_nil(fresh.deleted_at)
  end

  test "an open order blocks account deletion" do
    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    buyer = register_user(%{display_name: "Ada"})
    category = ensure_category("Power", "power-#{System.unique_integer([:positive])}")
    listing = create_listing(vendor, %{category_id: category.id, title: "Buck", qty_available: 2})

    assert {:ok, _order} = Orders.open(buyer, listing.id, 1, nil)

    assert {:error, error} =
             Ash.update(buyer, %{current_password: "password123456"},
               action: :delete_account,
               actor: buyer
             )

    assert Exception.message(error) =~ "open orders"
  end

  test "a finished order stays after the buyer deletes the account" do
    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    buyer = register_user(%{display_name: "Ada"})
    category = ensure_category("Power", "power-done-#{System.unique_integer([:positive])}")
    listing = create_listing(vendor, %{category_id: category.id, title: "Buck", qty_available: 2})

    assert {:ok, order} = Orders.open(buyer, listing.id, 1, nil)
    assert {:ok, order} = Ash.update(order, %{}, action: :mark_paid, authorize?: false)
    assert {:ok, order} = Orders.advance(order, vendor, :in_progress)
    assert {:ok, order} = Orders.advance(order, vendor, :shipped)
    assert {:ok, order} = Orders.advance(order, vendor, :complete)

    assert {:ok, _} =
             Ash.update(buyer, %{current_password: "password123456"},
               action: :delete_account,
               actor: buyer
             )

    assert {:ok, saved} = Ash.get(Order, order.id, authorize?: false, load: :buyer)
    assert saved.status == :complete
    assert saved.buyer.display_name == "Deleted account"
  end

  test "deleting a vendor archives listings and suspends the shop" do
    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    category = ensure_category("Boards", "boards-del-#{System.unique_integer([:positive])}")
    listing = create_listing(vendor, %{category_id: category.id, title: "Dev board"})

    assert {:ok, _} =
             Ash.update(vendor, %{current_password: "password123456"},
               action: :delete_account,
               actor: vendor
             )

    assert {:ok, saved} = Catalog.get_owned(listing.id, vendor)
    assert saved.status == :archived
    assert OdinMarket.Accounts.profile_for(vendor).status == :suspended
  end

  test "an admin account cannot be deleted" do
    user = register_user(%{display_name: "Root"})
    assert {:ok, admin} = Ash.update(user, %{role: :admin}, action: :set_role, authorize?: false)

    assert {:error, error} =
             Ash.update(admin, %{current_password: "password123456"},
               action: :delete_account,
               actor: admin
             )

    assert Exception.message(error) =~ "Admin"
  end
end

defmodule OdinMarket.BillingTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Accounts
  alias OdinMarket.Accounts.User
  alias OdinMarket.Billing

  test "a member cannot turn selling on" do
    user = register_user(%{display_name: "Ada"})

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(user, %{selling: true}, action: :set_selling, actor: user)
  end

  test "grant and pause follow the subscription" do
    user = register_user(%{display_name: "Volt"})
    refute user.selling

    assert {:ok, vendor} =
             Accounts.grant_vendor(user, %{
               stripe_subscription_id: "sub_test",
               stripe_price_id: "price_test",
               subscription_status: :active
             })

    assert vendor.selling
    profile = Accounts.profile_for(vendor)
    assert profile.status == :active
    assert profile.subscription_status == :active
    assert profile.stripe_subscription_id == "sub_test"

    assert {:ok, paused} = Accounts.pause_vendor(vendor, %{subscription_status: :past_due})
    refute paused.selling
    assert Accounts.profile_for(paused).status == :suspended
    assert Accounts.profile_for(paused).subscription_status == :past_due
    assert Accounts.profile_for(paused).stripe_subscription_id == "sub_test"
  end

  test "a subscription webhook grants and then pauses the shop" do
    user = register_user(%{display_name: "Webhook"})

    assert :ok =
             Billing.apply_event("customer.subscription.updated", %{
               "id" => "sub_hook",
               "status" => "active",
               "metadata" => %{"user_id" => user.id},
               "items" => %{"data" => [%{"price" => %{"id" => "price_year"}}]}
             })

    {:ok, selling} = Ash.get(User, user.id, authorize?: false)
    assert selling.selling
    assert Accounts.profile_for(selling).stripe_price_id == "price_year"

    assert :ok =
             Billing.apply_event("invoice.payment_failed", %{
               "subscription" => "sub_hook",
               "customer" => "cus_missing"
             })

    {:ok, paused} = Ash.get(User, user.id, authorize?: false)
    refute paused.selling
    assert Accounts.profile_for(paused).subscription_status == :past_due
  end
end

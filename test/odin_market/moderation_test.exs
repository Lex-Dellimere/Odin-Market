defmodule OdinMarket.ModerationTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Accounts.User
  alias OdinMarket.Chat.Message
  alias OdinMarket.Forum
  alias OdinMarket.Forum.Post
  alias OdinMarket.Moderation

  test "registration stores the terms agreement" do
    user = register_user(%{display_name: "Ada"})
    assert user.role == :member
    assert user.selling == false
    assert user.policy_version == OdinMarket.Policy.version()
    assert user.policy_accepted_at

    assert {:error, error} =
             Ash.create(
               User,
               %{
                 email: "plain-#{System.unique_integer([:positive])}@odin.test",
                 password: "password123456",
                 password_confirmation: "password123456",
                 username: "plain#{System.unique_integer([:positive])}",
                 policy_accepted: false
               },
               action: :register_with_password,
               authorize?: false
             )

    assert Exception.message(error) =~ "Agree to the terms"
  end

  test "a member cannot change roles" do
    member = register_user(%{display_name: "Ada"})
    other = register_user(%{display_name: "Bea"})

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(other, %{role: :admin}, action: :set_role, actor: member)
  end

  test "forum and vendor desks stay on their own reports" do
    author = register_user(%{display_name: "Author"})
    reporter = register_user(%{display_name: "Reporter"})
    buyer = register_user(%{display_name: "Buyer"})
    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    forum_mod = promote(register_user(%{display_name: "Forum"}), :forum_moderator)
    vendor_mod = promote(register_user(%{display_name: "Market"}), :vendor_moderator)
    stranger = register_user(%{display_name: "Stranger"})

    {:ok, board} = Forum.get_board("help")
    {:ok, thread} = Forum.open_thread(board, author, "Power rail", "The rail sags under load.")
    {:ok, loaded} = Forum.get_thread(thread.id)
    post = Enum.find(loaded.posts, & &1.opening)

    assert {:ok, forum_report} =
             Moderation.file_report(reporter, %{
               target_type: :forum_post,
               target_id: post.id,
               reason: :spam,
               note: "Copied advert"
             })

    assert forum_report.excerpt =~ "rail sags"
    assert forum_report.status == :open

    assert {:error, "You already reported this."} =
             Moderation.file_report(reporter, %{
               target_type: :forum_post,
               target_id: post.id,
               reason: :other
             })

    assert {:error, "You cannot report your own post."} =
             Moderation.file_report(author, %{
               target_type: :forum_post,
               target_id: post.id,
               reason: :spam
             })

    category = ensure_category("Power", "power-mod-#{System.unique_integer([:positive])}")
    listing = create_listing(vendor, %{category_id: category.id, title: "Buck module"})
    assert {:ok, conversation} = OdinMarket.Messaging.open_for_listing(buyer, listing.id)
    assert {:ok, message} = OdinMarket.Messaging.send(vendor, conversation.id, "Ships tomorrow.")

    assert {:ok, message_report} =
             Moderation.file_report(buyer, %{
               target_type: :message,
               target_id: message.id,
               reason: :harassment,
               note: "Not about the part"
             })

    assert {:error, "That is not available to report."} =
             Moderation.file_report(stranger, %{
               target_type: :message,
               target_id: message.id,
               reason: :spam
             })

    assert_raise Ash.Error.Forbidden, fn ->
      Moderation.list_reports(stranger)
    end

    assert Enum.map(Moderation.list_reports(forum_mod), & &1.id) == [forum_report.id]
    assert Enum.map(Moderation.list_reports(vendor_mod), & &1.id) == [message_report.id]

    assert {:error, reason} = Moderation.get_report(forum_mod, message_report.id)
    assert reason in [:forbidden, :missing]
    assert {:error, reason} = Moderation.get_report(vendor_mod, forum_report.id)
    assert reason in [:forbidden, :missing]

    assert [] = Ash.read!(Message, actor: forum_mod)
    assert {:error, %Ash.Error.Forbidden{}} = Forum.delete_post(post, vendor_mod)
    assert {:error, :forbidden} = Moderation.revoke(forum_mod, author.id)
    assert {:error, :forbidden} = Moderation.revoke(vendor_mod, author.id)
    assert {:error, :forbidden} = Moderation.set_role(forum_mod, author.id, :admin)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(
               OdinMarket.Accounts.profile_for(vendor),
               %{held: true},
               action: :set_hold,
               actor: vendor_mod
             )

    assert {:ok, :removed} = Moderation.remove_target(forum_mod, forum_report.id)
    assert {:error, %Ash.Error.Invalid{}} = Ash.get(Post, post.id, authorize?: false)

    assert {:ok, :removed} = Moderation.remove_target(vendor_mod, message_report.id)
    assert {:error, %Ash.Error.Invalid{}} = Ash.get(Message, message.id, authorize?: false)

    forum_audits = Moderation.list_audits(forum_mod)
    assert Enum.any?(forum_audits, &(&1.action == :delete_thread))
    refute Enum.any?(forum_audits, &(&1.action == :delete_message))

    vendor_audits = Moderation.list_audits(vendor_mod)
    assert Enum.any?(vendor_audits, &(&1.action == :delete_message))
    refute Enum.any?(vendor_audits, &(&1.action == :delete_thread))
  end

  test "a vendor moderator can hold a shop without clearing it on renewal" do
    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    vendor_mod = promote(register_user(%{display_name: "Market"}), :vendor_moderator)
    category = ensure_category("Boards", "boards-hold-#{System.unique_integer([:positive])}")
    listing = create_listing(vendor, %{category_id: category.id, title: "Dev board"})

    assert :ok = Moderation.hold_shop(vendor_mod, vendor.id)
    refute OdinMarket.Accounts.vendor?(OdinMarket.Accounts.fresh_user(vendor))
    assert {:error, :not_found} = OdinMarket.Catalog.get_by_slug(listing.slug)

    assert {:ok, _} = OdinMarket.Accounts.grant_vendor(OdinMarket.Accounts.fresh_user(vendor))
    profile = OdinMarket.Accounts.profile_for(vendor)
    assert profile.held
    refute OdinMarket.Accounts.vendor?(OdinMarket.Accounts.fresh_user(vendor))

    assert :ok = Moderation.release_shop(vendor_mod, vendor.id)
    assert OdinMarket.Accounts.vendor?(OdinMarket.Accounts.fresh_user(vendor))
  end

  test "only an admin can revoke, and a revoked account cannot sign in" do
    admin = promote(register_user(%{display_name: "Root"}), :admin)
    other_admin = promote(register_user(%{display_name: "Second"}), :admin)
    member = register_user(%{display_name: "Ada"})
    email = to_string(member.email)

    assert {:error, message} = Moderation.revoke(admin, admin.id)
    assert message =~ "own account"

    assert {:error, message} = Moderation.revoke(admin, other_admin.id)
    assert message =~ "Demote"

    assert {:ok, revoked} = Moderation.revoke(admin, member.id, "spam")
    assert revoked.deleted_at
    assert revoked.role == :member
    assert revoked.display_name == "Deleted account"

    strategy = AshAuthentication.Info.strategy!(User, :password)

    assert {:error, _} =
             AshAuthentication.Strategy.action(strategy, :sign_in, %{
               "email" => email,
               "password" => "password123456"
             })

    audits = Moderation.list_audits(admin)
    assert Enum.any?(audits, &(&1.action == :revoke_account))
    forum_mod = promote(register_user(%{display_name: "Forum"}), :forum_moderator)
    refute Enum.any?(Moderation.list_audits(forum_mod), &(&1.action == :revoke_account))

    assert {:error, :revoked} =
             OdinMarket.Accounts.grant_vendor(OdinMarket.Accounts.fresh_user(member))
  end

  test "an admin cannot change their own role" do
    admin = promote(register_user(%{display_name: "Root"}), :admin)
    other = promote(register_user(%{display_name: "Second"}), :admin)

    assert {:error, message} = Moderation.set_role(admin, admin.id, :member)
    assert message =~ "Another admin"

    assert {:ok, demoted} = Moderation.set_role(other, admin.id, :forum_moderator)
    assert demoted.role == :forum_moderator
  end

  defp promote(user, role) do
    {:ok, updated} = Ash.update(user, %{role: role}, action: :set_role, authorize?: false)
    updated
  end
end

defmodule OdinMarket.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use OdinMarket.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias OdinMarket.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import OdinMarket.DataCase
    end
  end

  setup tags do
    OdinMarket.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(OdinMarket.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  def register_user(attrs \\ %{}) do
    email = attrs[:email] || "user-#{System.unique_integer([:positive])}@odin.test"
    display_name = attrs[:display_name] || "Tester"
    username = attrs[:username] || username_for(display_name)

    {:ok, user} =
      Ash.create(
        OdinMarket.Accounts.User,
        %{
          email: email,
          password: "password123456",
          password_confirmation: "password123456",
          username: username,
          display_name: display_name,
          policy_accepted: true
        },
        action: :register_with_password,
        authorize?: false
      )

    {:ok, user} = Ash.update(user, %{}, action: :mark_confirmed, authorize?: false)

    if attrs[:role] == :vendor do
      {:ok, user} = OdinMarket.Accounts.grant_vendor(user)
      user
    else
      user
    end
  end

  defp username_for(display_name) do
    base =
      display_name
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "")
      |> String.slice(0, 10)

    base = if String.length(base) < 3, do: "member", else: base

    suffix =
      System.unique_integer([:positive])
      |> Integer.to_string()
      |> String.slice(-6, 6)
      |> String.pad_leading(6, "0")

    base <> suffix
  end

  def ensure_category(name, slug) do
    {:ok, category} =
      Ash.create(OdinMarket.Catalog.Category, %{name: name, slug: slug},
        action: :create,
        authorize?: false
      )

    category
  end

  def create_listing(actor, attrs) do
    params =
      Map.merge(
        %{
          title: "Listing #{System.unique_integer([:positive])}",
          description: "A part for the bench",
          kind: :stock,
          price_cents: 1_200,
          qty_available: 5,
          category_id: attrs[:category_id],
          status: :active
        },
        Map.new(attrs)
      )

    {:ok, listing} =
      Ash.create(OdinMarket.Catalog.Listing, params, action: :publish, actor: actor)

    listing
  end
end

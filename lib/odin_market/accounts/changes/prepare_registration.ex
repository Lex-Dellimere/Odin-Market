defmodule OdinMarket.Accounts.Changes.PrepareRegistration do
  use Ash.Resource.Change

  @username ~r/^[A-Za-z0-9_]{3,20}$/

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> require_policy()
    |> set_profile_fields()
  end

  defp require_policy(changeset) do
    accepted = Ash.Changeset.get_argument(changeset, :policy_accepted)

    if accepted in [true, "true"] do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      changeset
      |> Ash.Changeset.force_change_attribute(:policy_accepted_at, now)
      |> Ash.Changeset.force_change_attribute(:policy_version, OdinMarket.Policy.version())
    else
      Ash.Changeset.add_error(changeset,
        field: :policy_accepted,
        message: "Agree to the terms to create an account."
      )
    end
  end

  defp set_profile_fields(changeset) do
    username = changeset |> Ash.Changeset.get_argument(:username) |> to_string() |> String.trim()

    if Regex.match?(@username, username) do
      {:ok, cast} = Ash.Type.cast_input(Ash.Type.CiString, username)
      display = display_name(changeset, username)

      changeset
      |> Ash.Changeset.force_change_attribute(:username, cast)
      |> Ash.Changeset.force_change_attribute(:display_name, display)
      |> Ash.Changeset.force_change_attribute(:role, :member)
      |> Ash.Changeset.force_change_attribute(:selling, false)
    else
      Ash.Changeset.add_error(changeset,
        field: :username,
        message: "Use 3 to 20 letters, numbers, or underscores."
      )
    end
  end

  defp display_name(changeset, username) do
    display = Ash.Changeset.get_argument(changeset, :display_name)

    if is_binary(display) and String.trim(display) != "" do
      String.trim(display)
    else
      username
    end
  end
end

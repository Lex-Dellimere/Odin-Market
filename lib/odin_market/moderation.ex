defmodule OdinMarket.Moderation do
  use Ash.Domain, otp_app: :odin_market

  require Ash.Query

  alias OdinMarket.Accounts.User
  alias OdinMarket.Catalog.Listing
  alias OdinMarket.Chat.Message
  alias OdinMarket.Forum.Post
  alias OdinMarket.Forum.Thread
  alias OdinMarket.Moderation.AuditEntry
  alias OdinMarket.Moderation.Report

  resources do
    resource Report
    resource AuditEntry
  end

  @roles [:member, :forum_moderator, :vendor_moderator, :admin]

  def staff?(%{role: role}) when role in [:forum_moderator, :vendor_moderator, :admin], do: true
  def staff?(_), do: false

  def admin?(%{role: :admin}), do: true
  def admin?(_), do: false

  def forum_staff?(%{role: role}) when role in [:forum_moderator, :admin], do: true
  def forum_staff?(_), do: false

  def vendor_staff?(%{role: role}) when role in [:vendor_moderator, :admin], do: true
  def vendor_staff?(_), do: false

  def file_report(actor, attrs) when is_map(attrs) do
    case Ash.create(Report, attrs, action: :file, actor: actor) do
      {:ok, report} -> {:ok, report}
      {:error, error} -> {:error, ash_message(error)}
    end
  end

  def get_report(actor, id) do
    case Ash.get(Report, id, actor: actor) do
      {:ok, %Report{} = report} -> {:ok, report}
      {:ok, nil} -> {:error, :missing}
      {:error, %Ash.Error.Forbidden{}} -> {:error, :forbidden}
      _ -> {:error, :missing}
    end
  end

  def list_reports(actor) do
    Report
    |> Ash.Query.filter(status == :open)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.limit(100)
    |> Ash.read!(actor: actor)
  end

  def list_audits(actor) do
    AuditEntry
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(20)
    |> Ash.read!(actor: actor)
  end

  def dismiss(actor, report_id, note \\ nil) do
    with {:ok, report} <- open_report(actor, report_id),
         :ok <- not_self(actor, report),
         {:ok, updated} <-
           Ash.update(report, %{resolution_note: note}, action: :dismiss, actor: actor) do
      record(actor, :dismiss_report, report.target_type, report.target_id, "dismissed")
      {:ok, updated}
    end
  end

  def remove_target(actor, report_id) do
    with {:ok, report} <- open_report(actor, report_id),
         :ok <- not_self(actor, report),
         :ok <- remove(actor, report),
         {:ok, _} <- Ash.update(report, %{}, action: :close, actor: actor) do
      {:ok, :removed}
    end
  end

  def delete_forum_post(actor, %Post{} = post) do
    if forum_staff?(actor) do
      case OdinMarket.Forum.delete_post(post, actor) do
        :ok ->
          audit_post(actor, post)
          :ok

        {:ok, result} ->
          audit_post(actor, post)
          {:ok, result}

        other ->
          other
      end
    else
      {:error, :forbidden}
    end
  end

  def hold_shop(actor, user_id) do
    with true <- vendor_staff?(actor) || {:error, :forbidden},
         {:ok, profile} <- shop_profile(user_id),
         {:ok, _} <- Ash.update(profile, %{held: true}, action: :set_hold, authorize?: false) do
      record(actor, :hold_shop, :vendor_profile, profile.id, nil)
      :ok
    end
  end

  def release_shop(actor, user_id) do
    with true <- vendor_staff?(actor) || {:error, :forbidden},
         {:ok, profile} <- shop_profile(user_id),
         {:ok, _} <- Ash.update(profile, %{held: false}, action: :set_hold, authorize?: false) do
      record(actor, :release_shop, :vendor_profile, profile.id, nil)
      :ok
    end
  end

  def shop_summary(actor, user_id) do
    if vendor_staff?(actor) do
      case OdinMarket.Accounts.profile_for(%{id: user_id}) do
        nil ->
          {:ok, nil}

        profile ->
          {:ok, %{id: profile.id, shop_name: profile.shop_name, held: profile.held == true}}
      end
    else
      {:error, :forbidden}
    end
  end

  def revoke(actor, user_id, note \\ nil) do
    with true <- admin?(actor) || {:error, :forbidden},
         {:ok, %User{} = user} <- Ash.get(User, user_id, authorize?: false) do
      case Ash.update(user, %{note: blank(note)}, action: :revoke, actor: actor) do
        {:ok, revoked} ->
          record(actor, :revoke_account, :user, user.id, blank(note))
          {:ok, revoked}

        {:error, error} ->
          {:error, ash_message(error)}
      end
    else
      {:ok, nil} -> {:error, :missing}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, %Ash.Error.Invalid{}} -> {:error, :missing}
      other -> other
    end
  end

  def set_role(actor, user_id, role) when role in @roles do
    with true <- admin?(actor) || {:error, :forbidden},
         {:ok, %User{} = user} <- Ash.get(User, user_id, authorize?: false) do
      case Ash.update(user, %{role: role}, action: :set_role, actor: actor) do
        {:ok, updated} ->
          record(actor, :set_role, :user, user.id, "#{user.role} to #{role}")
          {:ok, updated}

        {:error, error} ->
          {:error, ash_message(error)}
      end
    else
      {:ok, nil} -> {:error, :missing}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, %Ash.Error.Invalid{}} -> {:error, :missing}
      other -> other
    end
  end

  def set_role(_actor, _user_id, _role), do: {:error, :forbidden}

  def lookup(actor, username) do
    name = username |> to_string() |> String.trim()

    cond do
      not admin?(actor) ->
        {:error, :forbidden}

      name == "" ->
        {:error, :missing}

      true ->
        case User |> Ash.Query.filter(username == ^name) |> Ash.read_one(authorize?: false) do
          {:ok, %User{} = user} -> {:ok, person(user)}
          _ -> {:error, :missing}
        end
    end
  end

  defp remove(actor, %{target_type: type} = report)
       when type in [:forum_post, :forum_thread] do
    if forum_staff?(actor) do
      remove_forum(actor, report)
    else
      {:error, :forbidden}
    end
  end

  defp remove(actor, %{target_type: :message, target_id: id}) do
    # chats stay participant-only. staff removal is only this path, and only from a report.
    if vendor_staff?(actor) do
      case Ash.get(Message, id, authorize?: false) do
        {:ok, %Message{} = message} ->
          case Ash.destroy(message, action: :remove, authorize?: false) do
            :ok ->
              record(actor, :delete_message, :message, id, nil)
              :ok

            {:ok, _} ->
              record(actor, :delete_message, :message, id, nil)
              :ok

            other ->
              other
          end

        _ ->
          {:error, :missing}
      end
    else
      {:error, :forbidden}
    end
  end

  defp remove(actor, %{target_type: :listing, target_id: id}) do
    if vendor_staff?(actor) do
      case Ash.get(Listing, id, authorize?: false) do
        {:ok, %Listing{} = listing} ->
          case Ash.update(listing, %{}, action: :archive, authorize?: false) do
            {:ok, _} ->
              record(actor, :archive_listing, :listing, listing.id, nil)
              :ok

            other ->
              other
          end

        _ ->
          {:error, :missing}
      end
    else
      {:error, :forbidden}
    end
  end

  defp remove(_actor, _report), do: {:error, :unsupported}

  defp remove_forum(actor, %{target_type: :forum_post, target_id: id}) do
    case Ash.get(Post, id, authorize?: false) do
      {:ok, %Post{} = post} ->
        case delete_forum_post(actor, post) do
          :ok -> :ok
          {:ok, _} -> :ok
          other -> other
        end

      _ ->
        {:error, :missing}
    end
  end

  defp remove_forum(actor, %{target_type: :forum_thread, target_id: id}) do
    case Ash.get(Thread, id, authorize?: false) do
      {:ok, %Thread{} = thread} ->
        case Ash.destroy(thread, actor: actor) do
          :ok ->
            record(actor, :delete_thread, :forum_thread, thread.id, nil)
            :ok

          {:ok, _} ->
            record(actor, :delete_thread, :forum_thread, thread.id, nil)
            :ok

          other ->
            other
        end

      _ ->
        {:error, :missing}
    end
  end

  defp open_report(actor, id) do
    case Ash.get(Report, id, actor: actor) do
      {:ok, %Report{status: :open} = report} -> {:ok, report}
      {:ok, %Report{}} -> {:error, :closed}
      {:ok, nil} -> {:error, :missing}
      {:error, %Ash.Error.Forbidden{}} -> {:error, :forbidden}
      _ -> {:error, :missing}
    end
  end

  defp not_self(%{role: :admin}, _report), do: :ok

  defp not_self(%{id: id}, %{subject_id: id}) when not is_nil(id), do: {:error, :forbidden}

  defp not_self(_actor, _report), do: :ok

  defp shop_profile(user_id) do
    case OdinMarket.Accounts.profile_for(%{id: user_id}) do
      nil -> {:error, :no_shop}
      profile -> {:ok, profile}
    end
  end

  defp audit_post(actor, %{opening: true, thread_id: thread_id}) do
    record(actor, :delete_thread, :forum_thread, thread_id, nil)
  end

  defp audit_post(actor, %{id: id}) do
    record(actor, :delete_post, :forum_post, id, nil)
  end

  defp record(actor, action, target_type, target_id, note) do
    Ash.create(
      AuditEntry,
      %{
        actor_id: actor.id,
        action: action,
        target_type: target_type,
        target_id: target_id,
        note: blank(note)
      },
      action: :record,
      authorize?: false
    )
  end

  defp person(user) do
    %{
      id: user.id,
      username: to_string(user.username),
      display_name: user.display_name,
      role: user.role,
      selling: user.selling,
      deleted: not is_nil(user.deleted_at)
    }
  end

  defp blank(nil), do: nil

  defp blank(value) do
    text = value |> to_string() |> String.trim() |> String.slice(0, 500)
    if text == "", do: nil, else: text
  end

  defp ash_message(error) do
    case field_message(error) do
      nil -> "That could not be saved."
      message -> message
    end
  end

  defp field_message(%{errors: errors}) when is_list(errors) do
    Enum.find_value(errors, &field_message/1)
  end

  defp field_message(%{message: message}) when is_binary(message) and message != "" do
    message
  end

  defp field_message(%{message: {message, _opts}}) when is_binary(message) and message != "" do
    message
  end

  defp field_message(_), do: nil
end

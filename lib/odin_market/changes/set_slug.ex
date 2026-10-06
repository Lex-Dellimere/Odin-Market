defmodule OdinMarket.Changes.SetSlug do
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, opts, _context) do
    source = Keyword.fetch!(opts, :from)
    resource = changeset.resource

    changeset =
      case Ash.Changeset.get_attribute(changeset, :slug) do
        slug when is_binary(slug) and slug != "" -> changeset
        _ -> Ash.Changeset.force_change_attribute(changeset, :slug, "pending")
      end

    Ash.Changeset.before_action(changeset, fn changeset ->
      current = Ash.Changeset.get_attribute(changeset, :slug)

      if is_binary(current) and current != "" and current != "pending" do
        changeset
      else
        base = Ash.Changeset.get_attribute(changeset, source) || "item"

        slug =
          OdinMarket.Slug.unique(base, fn candidate ->
            resource
            |> Ash.Query.filter(slug == ^candidate)
            |> Ash.exists?(authorize?: false)
          end)

        Ash.Changeset.force_change_attribute(changeset, :slug, slug)
      end
    end)
  end
end

defmodule OdinMarket.Accounts.Preparations.RejectDeleted do
  @moduledoc false
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Ash.Query.filter(query, is_nil(deleted_at))
  end
end

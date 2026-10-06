defmodule OdinMarket.PromoteTest do
  use OdinMarket.DataCase, async: true

  test "promoting a role is refused outside dev" do
    assert_raise Mix.Error, ~r/only runs in dev/, fn ->
      Mix.Tasks.Odin.Promote.run(["ada", "admin"])
    end
  end
end

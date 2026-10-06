defmodule OdinMarketWeb.StaffLiveTest do
  use OdinMarketWeb.ConnCase, async: true

  test "the desk is hidden from members and open to staff", %{conn: conn} do
    member = register_user(%{display_name: "Ada"})
    assert {:error, {:redirect, %{to: "/"}}} = live(log_in(conn, member), ~p"/staff")

    {:ok, home, _} = live(log_in(conn, member), ~p"/")
    refute has_element?(home, "#nav-staff")

    forum = promote(register_user(%{display_name: "Forum"}), :forum_moderator)
    {:ok, desk, _} = live(log_in(conn, forum), ~p"/staff")
    assert has_element?(desk, "#staff-desk")
    assert has_element?(desk, "#staff-reports-link")
    refute has_element?(desk, "#staff-people-link")
    assert has_element?(desk, "#nav-staff")

    assert {:error, {:live_redirect, %{to: "/staff"}}} =
             live(log_in(conn, forum), ~p"/staff/people")

    admin = promote(register_user(%{display_name: "Root"}), :admin)
    {:ok, people, _} = live(log_in(conn, admin), ~p"/staff/people")
    assert has_element?(people, "#staff-lookup")
    assert has_element?(people, "#staff-people-link")
  end

  test "the register page requires the terms", %{conn: conn} do
    {:ok, register, html} = live(conn, ~p"/register")
    assert has_element?(register, "#register-policy")
    refute has_element?(register, "#register-policy[checked]")
    assert has_element?(register, "#register-terms")
    assert html =~ "no refund"

    html =
      register
      |> form("#user-password-register-with-password", %{
        "user" => %{
          "email" => "ada@example.com",
          "password" => "password123456",
          "password_confirmation" => "password123456",
          "username" => "ada_box",
          "policy_accepted" => "true"
        }
      })
      |> render_change()

    assert html =~ ~s(id="register-policy")
    assert has_element?(register, "#register-policy[checked]")
  end

  defp promote(user, role) do
    {:ok, updated} =
      Ash.update(user, %{role: role}, action: :set_role, authorize?: false)

    updated
  end
end

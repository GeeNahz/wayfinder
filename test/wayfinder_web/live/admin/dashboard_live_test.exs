defmodule WayfinderWeb.Admin.DashboardLiveTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "access control" do
    test "redirects anonymous visitors to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin")
    end

    test "redirects logged-in users who are not super admins", %{conn: conn} do
      conn = log_in_user(conn, Wayfinder.AccountsFixtures.user_fixture())

      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin")
    end
  end

  describe "as a super admin" do
    setup :register_and_log_in_super_admin

    test "renders the dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert has_element?(view, "#admin-dashboard-title")
    end
  end
end

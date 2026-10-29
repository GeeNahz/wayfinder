defmodule WayfinderWeb.Admin.DashboardLiveTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wayfinder.DirectoryFixtures

  describe "access control" do
    test "redirects anonymous visitors to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin")
    end

    test "redirects logged-in users who are not super admins", %{conn: conn} do
      conn = log_in_user(conn, Wayfinder.AccountsFixtures.user_fixture())

      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin")
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/churches")
    end
  end

  describe "as a super admin" do
    setup :register_and_log_in_super_admin

    test "shows counts and recent submissions", %{conn: conn} do
      pending = church_fixture(%{}, :pending)
      church_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin")

      assert has_element?(view, "#admin-dashboard-title")
      assert has_element?(view, "#stat-pending", "1")
      assert has_element?(view, "#stat-approved", "1")
      assert has_element?(view, "#recent_churches-#{pending.id}")
    end
  end
end

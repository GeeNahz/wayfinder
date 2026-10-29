defmodule WayfinderWeb.Admin.ChurchLiveTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Directory
  alias Wayfinder.Repo

  setup :register_and_log_in_super_admin

  describe "index" do
    test "filters by status tab and search", %{conn: conn} do
      pending = church_fixture(%{"name" => "Pending Place"}, :pending)
      approved = church_fixture(%{"name" => "Approved Place"})

      {:ok, view, _html} = live(conn, ~p"/admin/churches")
      assert has_element?(view, "#churches-#{pending.id}")
      assert has_element?(view, "#churches-#{approved.id}")

      view |> element("#tab-pending") |> render_click()
      assert_patch(view, ~p"/admin/churches?status=pending")
      refute has_element?(view, "#churches-#{approved.id}")

      view |> form("#church-search", search: %{q: "nothing matches"}) |> render_change()
      assert has_element?(view, "#churches-empty")
    end
  end

  describe "show" do
    test "approves a pending church and emails the submitter", %{conn: conn} do
      church = church_fixture(%{}, :pending)
      {:ok, view, _html} = live(conn, ~p"/admin/churches/#{church}")

      view |> element("#approve-church") |> render_click()

      assert has_element?(view, "#church-status", "Approved")
      assert Repo.reload!(church).status == :approved
      assert_email_sent(subject: "#{church.name} is now on Wayfinder")
    end

    test "can't approve while a denomination request is open", %{conn: conn} do
      church = church_fixture(%{"requested_denomination" => "Brand New"}, :pending)
      {:ok, view, _html} = live(conn, ~p"/admin/churches/#{church}")

      assert has_element?(view, "#denomination-pending-note")
      assert has_element?(view, "#approve-church[disabled]")
    end

    test "rejects with a reason", %{conn: conn} do
      church = church_fixture(%{}, :pending)
      {:ok, view, _html} = live(conn, ~p"/admin/churches/#{church}")

      view |> element("#reject-church") |> render_click()
      view |> form("#reject-form", rejection: %{reason: "  "}) |> render_submit()
      assert has_element?(view, "#reject-form", "please give a reason")

      view |> form("#reject-form", rejection: %{reason: "Duplicate"}) |> render_submit()
      assert has_element?(view, "#church-status", "Rejected")
      assert Repo.reload!(church).rejection_reason == "Duplicate"
    end

    test "suspends, unsuspends and revokes links", %{conn: conn} do
      church = church_fixture()
      token = Directory.create_manage_token(church)
      {:ok, view, _html} = live(conn, ~p"/admin/churches/#{church}")

      view |> element("#suspend-church") |> render_click()
      assert has_element?(view, "#church-status", "Suspended")

      view |> element("#unsuspend-church") |> render_click()
      assert has_element?(view, "#church-status", "Approved")

      view |> element("#revoke-links") |> render_click()
      assert Directory.get_church_by_manage_token(token) == nil
    end

    test "deletes a church", %{conn: conn} do
      church = church_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/churches/#{church}")

      view |> element("#delete-church") |> render_click()
      assert_redirect(view, ~p"/admin/churches")
      refute Repo.get(Wayfinder.Directory.Church, church.id)
    end
  end

  describe "edit" do
    test "saves changes", %{conn: conn} do
      church = church_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/churches/#{church}/edit")

      view |> form("#church-form", church: %{"name" => "Renamed"}) |> render_submit()

      assert_redirect(view, ~p"/admin/churches/#{church}")
      assert Repo.reload!(church).name == "Renamed"
    end
  end
end

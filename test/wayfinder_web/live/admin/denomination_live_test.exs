defmodule WayfinderWeb.Admin.DenominationLiveTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Denominations

  setup :register_and_log_in_super_admin

  test "creates a denomination", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/denominations")

    view |> element("#new-denomination") |> render_click()
    assert_patch(view, ~p"/admin/denominations/new")

    view |> form("#denomination-form", denomination: %{name: ""}) |> render_change()
    assert has_element?(view, "#denomination-form", "can't be blank")

    view |> form("#denomination-form", denomination: %{name: "Methodist"}) |> render_submit()
    assert_patch(view, ~p"/admin/denominations")

    [denomination] = Denominations.list_active_denominations()
    assert has_element?(view, "#denominations-#{denomination.id}", "Methodist")
  end

  test "edits and archives a denomination", %{conn: conn} do
    denomination = denomination_fixture(%{name: "Anglican"})
    {:ok, view, _html} = live(conn, ~p"/admin/denominations/#{denomination}/edit")

    view
    |> form("#denomination-form", denomination: %{name: "Anglican Communion"})
    |> render_submit()

    assert has_element?(view, "#denominations-#{denomination.id}", "Anglican Communion")

    view |> element("#toggle-archive-#{denomination.id}") |> render_click()
    assert has_element?(view, "#denominations-#{denomination.id}", "Archived")
    assert Denominations.list_active_denominations() == []
  end
end

defmodule WayfinderWeb.DirectoryLiveTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wayfinder.DirectoryFixtures

  setup do
    baptist = denomination_fixture(%{name: "Baptist"})

    lagos =
      church_fixture(%{
        "name" => "Lagos Baptist",
        "city" => "Lagos",
        "denomination_id" => baptist.id,
        "activities" => %{
          "0" => %{"name" => "Bible Study", "days" => ["3"], "starts_at" => "18:00"}
        }
      })

    abuja =
      church_fixture(%{
        "name" => "Abuja Chapel",
        "city" => "Abuja",
        "latitude" => "9.0765",
        "longitude" => "7.3986"
      })

    pending = church_fixture(%{"name" => "Hidden Pending"}, :pending)

    %{lagos: lagos, abuja: abuja, pending: pending}
  end

  test "lists approved churches on the map and in the list", %{
    conn: conn,
    lagos: lagos,
    abuja: abuja,
    pending: pending
  } do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#churches-#{lagos.id}")
    assert has_element?(view, "#churches-#{abuja.id}")
    refute has_element?(view, "#churches-#{pending.id}")
    assert has_element?(view, "#directory-map[phx-hook=ChurchMap]")
    assert has_element?(view, "#results-count", "2 churches")
  end

  test "filters update the URL and the results", %{conn: conn, lagos: lagos, abuja: abuja} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> form("#filters-form", filters: %{q: "abuja"}) |> render_change()
    assert_patch(view, ~p"/?q=abuja")
    assert has_element?(view, "#churches-#{abuja.id}")
    refute has_element?(view, "#churches-#{lagos.id}")
    assert_push_event(view, "map:churches", %{markers: [%{name: "Abuja Chapel"}]})
  end

  test "filters by denomination and day from the URL", %{conn: conn, lagos: lagos, abuja: abuja} do
    {:ok, view, _html} = live(conn, ~p"/?denomination=baptist")
    assert has_element?(view, "#churches-#{lagos.id}")
    refute has_element?(view, "#churches-#{abuja.id}")

    {:ok, view, _html} = live(conn, ~p"/?day=3")
    assert has_element?(view, "#churches-#{lagos.id}")
    refute has_element?(view, "#churches-#{abuja.id}")
  end

  test "shows an empty state when nothing matches", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?q=atlantis")
    assert has_element?(view, "#results-count", "0 churches")
  end

  test "near me sorts by distance and shows it", %{conn: conn, abuja: abuja} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_hook(view, "located", %{"lat" => 9.05, "lng" => 7.4})
    assert_patch(view, ~p"/?lat=9.05&lng=7.4")

    assert has_element?(view, "#churches-#{abuja.id}", "km")
    assert has_element?(view, "#clear-location")

    view |> element("#clear-location") |> render_click()
    assert_patch(view, ~p"/")
  end

  test "explains when the location can't be read", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    html = render_hook(view, "locate_failed", %{"message" => "No permission"})
    assert html =~ "No permission"
  end

  test "ignores nonsense filter values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?day=9&lat=abc&lng=1")
    assert has_element?(view, "#results-count", "2 churches")
  end
end

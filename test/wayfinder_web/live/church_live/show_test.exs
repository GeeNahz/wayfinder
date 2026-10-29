defmodule WayfinderWeb.ChurchLive.ShowTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wayfinder.DirectoryFixtures

  test "shows the church, its schedule and map links", %{conn: conn} do
    church =
      church_fixture(%{
        "name" => "Grace Chapel",
        "activities" => %{
          "0" => %{
            "name" => "Sunday Service",
            "days" => ["7"],
            "starts_at" => "09:00",
            "ends_at" => "11:00"
          },
          "1" => %{"name" => "Bible Study", "days" => ["3", "5"], "starts_at" => "18:00"}
        }
      })

    {:ok, view, _html} = live(conn, ~p"/churches/#{church.slug}")

    assert has_element?(view, "#church-name", "Grace Chapel")
    assert has_element?(view, "#schedule-sunday", "9:00 AM – 11:00 AM")
    assert has_element?(view, "#schedule-wednesday", "Bible Study")
    assert has_element?(view, "#schedule-friday", "Bible Study")
    refute has_element?(view, "#schedule-monday")
    assert has_element?(view, "#church-map[phx-hook=ChurchMap]")
    assert has_element?(view, "#directions-link[href*='google.com/maps/dir']")
    assert has_element?(view, "#google-maps-link[href*='google.com/maps/search']")
  end

  test "churches that aren't approved are not found", %{conn: conn} do
    church = church_fixture(%{}, :pending)

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/churches/#{church.slug}")
    end
  end
end

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

defmodule WayfinderWeb.ChurchLive.ShowEditRequestTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.EditRequests

  setup %{conn: conn} do
    church = church_fixture()
    {:ok, view, _html} = live(conn, ~p"/churches/#{church.slug}")
    view |> element("#open-edit-request") |> render_click()

    %{church: church, view: view}
  end

  defp stub_turnstile(success?) do
    Req.Test.stub(Wayfinder.Turnstile, &Req.Test.json(&1, %{"success" => success?}))
  end

  test "opens the request form", %{view: view} do
    assert has_element?(view, "#edit-request-form")
    assert has_element?(view, "#edit-request-turnstile[phx-hook=Turnstile]")
  end

  test "stores a request for the registered email", %{church: church, view: view} do
    stub_turnstile(true)

    view
    |> form("#edit-request-form", edit_request: %{email: church.contact_email})
    |> render_submit(%{"cf-turnstile-response" => "token"})

    assert has_element?(view, "#edit-request-sent")
    assert EditRequests.count_pending_edit_requests() == 1
  end

  test "shows the same message for an unknown email", %{view: view} do
    stub_turnstile(true)

    view
    |> form("#edit-request-form", edit_request: %{email: "stranger@example.com"})
    |> render_submit(%{"cf-turnstile-response" => "token"})

    assert has_element?(view, "#edit-request-sent")
    assert EditRequests.count_pending_edit_requests() == 0
  end

  test "requires the spam check", %{church: church, view: view} do
    stub_turnstile(false)

    view
    |> form("#edit-request-form", edit_request: %{email: church.contact_email})
    |> render_submit(%{"cf-turnstile-response" => "token"})

    refute has_element?(view, "#edit-request-sent")
    assert_push_event(view, "turnstile:reset", %{})
    assert EditRequests.count_pending_edit_requests() == 0
  end

  test "validates the email", %{view: view} do
    view |> form("#edit-request-form", edit_request: %{email: "nope"}) |> render_change()
    assert has_element?(view, "#edit-request-form", "must be a valid email address")
  end
end

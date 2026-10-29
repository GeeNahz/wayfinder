defmodule WayfinderWeb.ChurchLive.RegisterTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Directory.Church
  alias Wayfinder.Repo

  defp form_params(denomination) do
    %{
      "name" => "Grace Chapel",
      "denomination_id" => denomination.id,
      "address_line1" => "1 Hope Street",
      "city" => "Lagos",
      "country" => "Nigeria",
      "contact_email" => "pastor@example.com",
      "activities" => %{
        "0" => %{"name" => "Sunday Service", "days" => ["", "7"], "starts_at" => "09:00"}
      }
    }
  end

  # Latitude/longitude are hidden inputs filled by the map, so tests set them
  # the same way the browser does: by "moving the pin".
  defp place_pin(view), do: render_hook(view, "pin_moved", %{"lat" => 6.5244, "lng" => 3.3792})

  defp stub_turnstile(success?) do
    Req.Test.stub(Wayfinder.Turnstile, &Req.Test.json(&1, %{"success" => success?}))
  end

  setup do
    %{denomination: denomination_fixture(%{name: "Baptist"})}
  end

  test "renders the form with one activity row and the spam check", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/churches/new")

    assert has_element?(view, "#church-form")
    assert has_element?(view, "#church-map-picker[phx-hook=MapPicker]")
    assert has_element?(view, "#turnstile-widget[data-sitekey]")
    assert has_element?(view, "#activity-0")
    assert has_element?(view, "option", "Baptist")
  end

  test "shows errors while typing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/churches/new")

    view
    |> form("#church-form", church: %{"name" => "", "contact_email" => "nope"})
    |> render_change()

    assert has_element?(view, "#church-form", "must be a valid email address")
  end

  # The add/remove buttons use JS.dispatch("change"), which sends the form
  # with the button's name/value. We send those params directly here.
  test "adds and removes activity rows", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/churches/new")
    assert has_element?(view, "#add-activity[name='church[activities_sort][]'][value=new]")

    view
    |> element("#church-form")
    |> render_change(%{"church" => %{"activities_sort" => ["0", "new"]}})

    assert has_element?(view, "#activity-1")

    view
    |> element("#church-form")
    |> render_change(%{
      "church" => %{"activities_sort" => ["0", "1"], "activities_drop" => ["0"]}
    })

    refute has_element?(view, "#activity-1")
    assert has_element?(view, "#activity-0")
  end

  test "Find on map fills in the coordinates", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/churches/new")

    view
    |> form("#church-form", church: %{"address_line1" => "1 Hope Street"})
    |> render_change()

    view |> element("#geocode-button") |> render_click()
    assert has_element?(view, "#geocode-results")

    view |> element("#place-0") |> render_click()

    assert_push_event(view, "map:set_pin", %{lat: 6.5244, lng: 3.3792})
    assert has_element?(view, "input[name='church[latitude]'][value='6.5244']")
    assert has_element?(view, "input[name='church[city]'][value='Lagos']")
    refute has_element?(view, "#geocode-results")
  end

  test "Find on map explains when nothing is found", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/churches/new")

    view |> form("#church-form", church: %{"address_line1" => "nowhere"}) |> render_change()
    view |> element("#geocode-button") |> render_click()

    assert has_element?(view, "#geocode-error")
  end

  test "moving the pin updates the coordinates", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/churches/new")

    render_hook(view, "pin_moved", %{"lat" => 9.0765, "lng" => 7.3986})
    assert has_element?(view, "input[name='church[longitude]'][value='7.3986']")
  end

  test "submits the church and sends a verification email", %{
    conn: conn,
    denomination: denomination
  } do
    stub_turnstile(true)
    {:ok, view, _html} = live(conn, ~p"/churches/new")
    place_pin(view)

    view
    |> form("#church-form", church: form_params(denomination))
    |> render_submit(%{"cf-turnstile-response" => "token"})

    assert has_element?(view, "#registration-submitted")

    church = Repo.get_by!(Church, contact_email: "pastor@example.com")
    assert church.status == :unverified
    assert_email_sent(subject: "Confirm your church listing")
  end

  test "does not save when the spam check fails", %{conn: conn, denomination: denomination} do
    stub_turnstile(false)
    {:ok, view, _html} = live(conn, ~p"/churches/new")
    place_pin(view)

    view
    |> form("#church-form", church: form_params(denomination))
    |> render_submit(%{"cf-turnstile-response" => "token"})

    refute has_element?(view, "#registration-submitted")
    assert_push_event(view, "turnstile:reset", %{})
    assert Repo.aggregate(Church, :count) == 0
  end

  test "shows a location error when no pin was placed", %{conn: conn, denomination: denomination} do
    {:ok, view, _html} = live(conn, ~p"/churches/new")
    view |> form("#church-form", church: form_params(denomination)) |> render_submit()

    assert has_element?(view, "#location-error")
  end
end

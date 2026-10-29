defmodule WayfinderWeb.Admin.DenominationRequestLiveTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.{Denominations, Directory, Repo}

  setup :register_and_log_in_super_admin

  setup do
    {church, token} = registered_church_fixture(%{"requested_denomination" => "Grace Fellowship"})
    {:ok, _church} = Directory.verify_church(token)
    [request] = Denominations.list_pending_requests()

    %{church: church, request: request}
  end

  test "approves a request as a new denomination", %{conn: conn, church: church, request: request} do
    {:ok, view, _html} = live(conn, ~p"/admin/denomination-requests")
    assert has_element?(view, "#requests-#{request.id}", church.name)

    view |> element("#approve-request-#{request.id}") |> render_click()

    view
    |> form("#approve-request-form", denomination: %{name: "Grace Fellowship Church"})
    |> render_submit()

    refute has_element?(view, "#requests-#{request.id}")
    church = Repo.reload!(church) |> Repo.preload(:denomination)
    assert church.denomination.name == "Grace Fellowship Church"
  end

  test "merges a request into an existing denomination", %{
    conn: conn,
    church: church,
    request: request
  } do
    existing = denomination_fixture(%{name: "Pentecostal"})
    {:ok, view, _html} = live(conn, ~p"/admin/denomination-requests")

    view |> element("#merge-request-#{request.id}") |> render_click()

    view
    |> form("#merge-request-form", merge: %{denomination_id: existing.id})
    |> render_submit()

    refute has_element?(view, "#requests-#{request.id}")
    assert Repo.reload!(church).denomination_id == existing.id
  end
end

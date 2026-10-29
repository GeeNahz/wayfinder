defmodule WayfinderWeb.Admin.EditRequestLiveTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.EditRequests

  setup :register_and_log_in_super_admin

  setup do
    church = church_fixture()
    :ok = EditRequests.request_edit(church, %{"email" => church.contact_email, "message" => "Hi"})
    [request] = EditRequests.list_pending_edit_requests()

    %{church: church, request: request}
  end

  test "grants a request and emails the manage link", %{
    conn: conn,
    church: church,
    request: request
  } do
    {:ok, view, _html} = live(conn, ~p"/admin/edit-requests")
    assert has_element?(view, "#edit_requests-#{request.id}", church.name)

    view |> element("#grant-#{request.id}") |> render_click()

    refute has_element?(view, "#edit_requests-#{request.id}")

    assert_email_sent(fn email ->
      assert email.to == [{"", church.contact_email}]
      assert email.text_body =~ "/churches/#{church.slug}/manage/"
    end)
  end

  test "rejects a request", %{conn: conn, request: request} do
    {:ok, view, _html} = live(conn, ~p"/admin/edit-requests")

    view |> element("#reject-#{request.id}") |> render_click()

    refute has_element?(view, "#edit_requests-#{request.id}")
    assert EditRequests.count_pending_edit_requests() == 0
    assert_no_email_sent()
  end
end

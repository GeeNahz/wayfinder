defmodule WayfinderWeb.ChurchLive.ManageTest do
  use WayfinderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Directory
  alias Wayfinder.Repo

  setup do
    church = church_fixture(%{"name" => "Grace Chapel"})
    %{church: church, token: Directory.create_manage_token(church)}
  end

  test "edits the church through a valid link", %{conn: conn, church: church, token: token} do
    {:ok, view, _html} = live(conn, ~p"/churches/#{church.slug}/manage/#{token}")

    assert has_element?(view, "#church-form")
    assert has_element?(view, "input[name='church[name]'][value='Grace Chapel']")

    view
    |> form("#church-form", church: %{"name" => "Grace Chapel Lagos"})
    |> render_submit()

    church = Repo.reload!(church)
    assert church.name == "Grace Chapel Lagos"
    assert church.last_edited_at
    # existing activities are kept
    assert [_activity] = Repo.preload(church, :activities).activities
  end

  test "shows form errors", %{conn: conn, church: church, token: token} do
    {:ok, view, _html} = live(conn, ~p"/churches/#{church.slug}/manage/#{token}")

    view |> form("#church-form", church: %{"name" => ""}) |> render_submit()
    assert has_element?(view, "#church-form", "can't be blank")
  end

  test "rejects invalid or revoked links", %{conn: conn, church: church, token: token} do
    {:ok, view, _html} = live(conn, ~p"/churches/#{church.slug}/manage/nonsense")
    assert has_element?(view, "#manage-link-invalid")

    Directory.revoke_manage_links(church)
    {:ok, view, _html} = live(conn, ~p"/churches/#{church.slug}/manage/#{token}")
    assert has_element?(view, "#manage-link-invalid")
  end

  test "a link only works for its own church", %{conn: conn, token: token} do
    other = church_fixture()

    {:ok, view, _html} = live(conn, ~p"/churches/#{other.slug}/manage/#{token}")
    assert has_element?(view, "#manage-link-invalid")
  end

  test "notes when the church isn't public", %{conn: conn} do
    church = church_fixture(%{}, :suspended)
    token = Directory.create_manage_token(church)

    {:ok, view, _html} = live(conn, ~p"/churches/#{church.slug}/manage/#{token}")
    assert has_element?(view, "#manage-status-note", "suspended")
  end
end

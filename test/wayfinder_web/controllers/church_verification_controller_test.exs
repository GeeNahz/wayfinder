defmodule WayfinderWeb.ChurchVerificationControllerTest do
  use WayfinderWeb.ConnCase, async: true

  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Repo

  test "confirms the email and queues the church for review", %{conn: conn} do
    {church, token} = registered_church_fixture(%{"requested_denomination" => "New"})

    conn = get(conn, ~p"/churches/verify/#{token}")

    assert html_response(conn, 200) =~ "church-verified"
    assert Repo.reload!(church).status == :pending
  end

  test "explains when the link is invalid", %{conn: conn} do
    conn = get(conn, ~p"/churches/verify/nonsense")
    assert html_response(conn, 404) =~ "church-verification-invalid"
  end
end

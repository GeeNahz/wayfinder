defmodule WayfinderWeb.PageControllerTest do
  use WayfinderWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Find a church near you"
  end
end

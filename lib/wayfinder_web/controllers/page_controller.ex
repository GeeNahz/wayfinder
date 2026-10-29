defmodule WayfinderWeb.PageController do
  use WayfinderWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

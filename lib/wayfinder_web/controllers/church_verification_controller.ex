defmodule WayfinderWeb.ChurchVerificationController do
  @moduledoc """
  Handles the link in the "Confirm your church listing" email.
  """
  use WayfinderWeb, :controller

  alias Wayfinder.Directory

  def show(conn, %{"token" => token}) do
    case Directory.verify_church(token) do
      {:ok, church} ->
        render(conn, :verified, church: church, page_title: "Email confirmed")

      :error ->
        conn
        |> put_status(:not_found)
        |> render(:invalid, page_title: "Link expired")
    end
  end
end

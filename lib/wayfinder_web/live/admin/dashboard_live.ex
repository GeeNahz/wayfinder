defmodule WayfinderWeb.Admin.DashboardLive do
  use WayfinderWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Admin dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:dashboard}>
      <.header>
        <span id="admin-dashboard-title">Dashboard</span>
      </.header>
    </Layouts.admin>
    """
  end
end

defmodule WayfinderWeb.Admin.DashboardLive do
  use WayfinderWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Admin dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h1 id="admin-dashboard-title" class="text-2xl font-semibold">Admin dashboard</h1>
    </Layouts.app>
    """
  end
end

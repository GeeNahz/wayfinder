defmodule WayfinderWeb.Admin.DashboardLive do
  @moduledoc """
  Super admin overview: what needs attention, plus recent submissions.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.AdminComponents

  alias Wayfinder.{Denominations, Directory, EditRequests}
  alias Wayfinder.Directory.Church

  @impl true
  def mount(_params, _session, socket) do
    counts = Directory.count_churches_by_status()

    {:ok,
     socket
     |> assign(:page_title, "Admin dashboard")
     |> assign(:pending_count, Map.get(counts, :pending, 0))
     |> assign(:approved_count, Map.get(counts, :approved, 0))
     |> assign(:denomination_request_count, Denominations.count_pending_requests())
     |> assign(:edit_request_count, EditRequests.count_pending_edit_requests())
     |> stream(:recent_churches, Directory.list_recent_churches(8))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:dashboard}>
      <.header>
        <span id="admin-dashboard-title">Dashboard</span>
        <:subtitle>What needs your attention today.</:subtitle>
      </.header>

      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <.stat_card
          id="stat-pending"
          label="Churches to review"
          value={@pending_count}
          icon="hero-clock"
          navigate={~p"/admin/churches?status=pending"}
          highlight={@pending_count > 0}
        />
        <.stat_card
          id="stat-denomination-requests"
          label="Denomination requests"
          value={@denomination_request_count}
          icon="hero-inbox-arrow-down"
          navigate={~p"/admin/denomination-requests"}
          highlight={@denomination_request_count > 0}
        />
        <.stat_card
          id="stat-edit-requests"
          label="Edit requests"
          value={@edit_request_count}
          icon="hero-pencil-square"
          navigate={~p"/admin/edit-requests"}
          highlight={@edit_request_count > 0}
        />
        <.stat_card
          id="stat-approved"
          label="Live churches"
          value={@approved_count}
          icon="hero-check-badge"
          navigate={~p"/admin/churches?status=approved"}
        />
      </div>

      <div class="mt-10">
        <div class="mb-4 flex items-center justify-between">
          <h2 class="text-base font-semibold">Recent submissions</h2>
          <.link navigate={~p"/admin/churches"} class="text-sm font-medium text-brand hover:underline">
            View all
          </.link>
        </div>

        <ul
          id="recent-churches"
          phx-update="stream"
          class="divide-y divide-line overflow-hidden rounded-2xl border border-line bg-surface"
        >
          <li id="recent-churches-empty" class="hidden p-6 text-center text-sm text-muted only:block">
            No submissions yet.
          </li>
          <li :for={{dom_id, church} <- @streams.recent_churches} id={dom_id}>
            <.link
              navigate={~p"/admin/churches/#{church}"}
              class="flex items-center justify-between gap-4 px-5 py-4 transition hover:bg-surface-2"
            >
              <div class="min-w-0">
                <p class="truncate font-medium">{church.name}</p>
                <p class="truncate text-sm text-muted">
                  {Church.denomination_name(church)} · {church.city}, {church.country}
                </p>
              </div>
              <div class="flex shrink-0 items-center gap-3">
                <span class="hidden text-xs text-muted sm:inline">
                  {format_date(church.inserted_at)}
                </span>
                <.status_badge status={church.status} />
              </div>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.admin>
    """
  end
end

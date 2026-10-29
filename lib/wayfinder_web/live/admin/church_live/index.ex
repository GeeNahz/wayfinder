defmodule WayfinderWeb.Admin.ChurchLive.Index do
  @moduledoc """
  All verified churches, filterable by status tab and text search.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.AdminComponents

  alias Wayfinder.Directory
  alias Wayfinder.Directory.Church

  @tabs [
    {"All", nil},
    {"Pending", "pending"},
    {"Approved", "approved"},
    {"Rejected", "rejected"},
    {"Suspended", "suspended"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Churches")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = Map.take(params, ["status", "q"])
    churches = Directory.list_churches(filters)
    counts = Directory.count_churches_by_status()

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(
       :tabs,
       Enum.map(@tabs, fn {label, status} -> {label, status, tab_count(counts, status)} end)
     )
     |> assign(:search_form, to_form(%{"q" => filters["q"]}, as: :search))
     |> assign(:empty?, churches == [])
     |> stream(:churches, churches, reset: true)}
  end

  defp tab_count(counts, nil), do: counts |> Map.values() |> Enum.sum()
  defp tab_count(counts, status), do: Map.get(counts, String.to_existing_atom(status), 0)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:churches}>
      <.header>
        Churches
        <:subtitle>Review new submissions and manage listed churches.</:subtitle>
      </.header>

      <div class="mb-6 flex flex-wrap items-center justify-between gap-4">
        <nav
          id="status-tabs"
          class="flex flex-wrap gap-1 rounded-xl border border-line bg-surface p-1"
        >
          <.link
            :for={{label, status, count} <- @tabs}
            id={"tab-#{status || "all"}"}
            patch={~p"/admin/churches?#{reject_blank(%{"status" => status, "q" => @filters["q"]})}"}
            class={[
              "flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm font-medium transition",
              if(@filters["status"] == status,
                do: "bg-brand-soft text-brand",
                else: "text-muted hover:text-ink"
              )
            ]}
          >
            {label}
            <span class="rounded-full bg-surface-2 px-1.5 text-xs tabular-nums">{count}</span>
          </.link>
        </nav>

        <.form
          for={@search_form}
          id="church-search"
          phx-change="search"
          phx-submit="search"
          class="w-full sm:w-72"
        >
          <.input
            field={@search_form[:q]}
            type="search"
            placeholder="Search name, city or email"
            phx-debounce="300"
          />
        </.form>
      </div>

      <p
        :if={@empty?}
        id="churches-empty"
        class="rounded-2xl border border-dashed border-line p-10 text-center text-sm text-muted"
      >
        No churches here.
      </p>

      <.table
        :if={!@empty?}
        id="churches"
        rows={@streams.churches}
        row_click={fn {_id, church} -> JS.navigate(~p"/admin/churches/#{church}") end}
      >
        <:col :let={{_id, church}} label="Church">
          <p class="font-medium">{church.name}</p>
          <p class="text-xs text-muted">{church.contact_email}</p>
        </:col>
        <:col :let={{_id, church}} label="Denomination">
          {Church.denomination_name(church)}
          <.badge :if={is_nil(church.denomination_id)} color="warning" class="ml-1">
            requested
          </.badge>
        </:col>
        <:col :let={{_id, church}} label="Location">{church.city}, {church.country}</:col>
        <:col :let={{_id, church}} label="Status"><.status_badge status={church.status} /></:col>
        <:col :let={{_id, church}} label="Submitted">{format_date(church.inserted_at)}</:col>
      </.table>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    params = reject_blank(%{"status" => socket.assigns.filters["status"], "q" => q})
    {:noreply, push_patch(socket, to: ~p"/admin/churches?#{params}")}
  end

  defp reject_blank(params), do: Map.reject(params, fn {_key, value} -> value in [nil, ""] end)
end

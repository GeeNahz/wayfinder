defmodule WayfinderWeb.ChurchLive.Show do
  @moduledoc """
  Public page for one approved church: details, map, directions and the
  weekly schedule.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.ChurchHelpers

  alias Wayfinder.Directory
  alias Wayfinder.Directory.Church

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    church = Directory.get_public_church_by_slug!(slug)

    {:ok,
     socket
     |> assign(:page_title, church.name)
     |> assign(:church, church)
     |> assign(:schedule, schedule_by_day(church.activities))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} width="wide">
      <.link
        navigate={~p"/"}
        class="mb-6 inline-flex items-center gap-1 text-sm font-medium text-muted transition hover:text-ink"
      >
        <.icon name="hero-arrow-left-mini" class="size-4" /> All churches
      </.link>

      <div class="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <.badge :if={Church.denomination_name(@church)} color="brand" class="mb-3">
            {Church.denomination_name(@church)}
          </.badge>
          <h1 id="church-name" class="text-3xl font-semibold tracking-tight">{@church.name}</h1>
          <p class="mt-2 flex items-start gap-1.5 text-muted">
            <.icon name="hero-map-pin" class="mt-0.5 size-5 shrink-0" />
            {Church.full_address(@church)}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <.button
            href={directions_url(@church)}
            target="_blank"
            rel="noopener"
            variant="primary"
            id="directions-link"
          >
            <.icon name="hero-arrow-top-right-on-square-mini" class="size-4" /> Get directions
          </.button>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1fr_24rem]">
        <div class="space-y-6">
          <.card :if={@church.description}>
            <:title>About</:title>
            <p class="whitespace-pre-line text-sm leading-relaxed text-ink">{@church.description}</p>
          </.card>

          <.card id="church-schedule">
            <:title>Weekly schedule</:title>
            <p :if={@schedule == []} class="text-sm text-muted">
              No weekly activities have been listed yet.
            </p>
            <div class="divide-y divide-line">
              <div
                :for={{day, activities} <- @schedule}
                id={"schedule-#{String.downcase(day)}"}
                class="grid gap-2 py-4 first:pt-0 last:pb-0 sm:grid-cols-[8rem_1fr]"
              >
                <h3 class="text-sm font-semibold text-ink">{day}</h3>
                <ul class="space-y-2">
                  <li :for={activity <- activities} class="text-sm">
                    <div class="flex flex-wrap items-baseline gap-x-3">
                      <span class="font-medium tabular-nums text-brand">
                        {format_time_range(activity)}
                      </span>
                      <span class="text-ink">{activity.name}</span>
                    </div>
                    <p :if={activity.description} class="text-xs text-muted">
                      {activity.description}
                    </p>
                  </li>
                </ul>
              </div>
            </div>
          </.card>
        </div>

        <div class="space-y-6">
          <div class="overflow-hidden rounded-2xl border border-line">
            <div
              id="church-map"
              phx-hook="ChurchMap"
              phx-update="ignore"
              data-markers={Jason.encode!([map_marker(@church, nil)])}
              class="z-0 h-64"
            >
            </div>
            <a
              href={google_maps_url(@church)}
              target="_blank"
              rel="noopener"
              id="google-maps-link"
              class="flex items-center justify-center gap-1.5 border-t border-line bg-surface px-4 py-3 text-sm font-medium text-brand transition hover:bg-surface-2"
            >
              Open in Google Maps <.icon name="hero-arrow-top-right-on-square-mini" class="size-4" />
            </a>
          </div>

          <.card :if={@church.phone || @church.website}>
            <:title>Contact</:title>
            <ul class="space-y-2 text-sm">
              <li :if={@church.phone} class="flex items-center gap-2">
                <.icon name="hero-phone" class="size-4 text-muted" />
                <a href={"tel:#{@church.phone}"} class="hover:text-brand">{@church.phone}</a>
              </li>
              <li :if={@church.website} class="flex items-center gap-2">
                <.icon name="hero-globe-alt" class="size-4 text-muted" />
                <a
                  href={@church.website}
                  target="_blank"
                  rel="noopener nofollow"
                  class="truncate hover:text-brand"
                >
                  {URI.parse(@church.website).host}
                </a>
              </li>
            </ul>
          </.card>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

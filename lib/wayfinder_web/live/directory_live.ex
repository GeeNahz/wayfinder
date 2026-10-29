defmodule WayfinderWeb.DirectoryLive do
  @moduledoc """
  The home page: a map and list of approved churches, with filters.

  Filters live in the URL (e.g. `/?q=lagos&day=7`), so searches can be
  shared and the back button works. Every change goes through
  `push_patch/2` -> `handle_params/3`, which reloads the results.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.ChurchHelpers

  alias Wayfinder.{Denominations, Directory}
  alias Wayfinder.Directory.{Activity, Church}

  @filter_keys ~w(q denomination day lat lng)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Find a church")
     |> assign(:denomination_options, denomination_options())
     |> assign(:day_options, Enum.map(Activity.weekdays(), fn {day, name} -> {name, day} end))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    params = Map.take(params, @filter_keys)
    filters = parse_filters(params)
    churches = Directory.list_public_churches(filters)
    markers = Enum.map(churches, &map_marker(&1, ~p"/churches/#{&1.slug}"))
    origin = with {lat, lng} <- filters["near"], do: %{lat: lat, lng: lng}

    {:noreply,
     socket
     |> assign(:params, params)
     |> assign(:form, to_form(params, as: :filters))
     |> assign(:near?, origin != nil)
     |> assign(:count, length(churches))
     # Only used for the map's first render; later updates go via push_event.
     |> assign_new(:initial_markers, fn -> markers end)
     |> stream(:churches, churches, reset: true)
     |> push_event("map:churches", %{markers: markers, origin: origin})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} width="full">
      <div class="flex flex-col lg:grid lg:h-[calc(100dvh-4rem)] lg:grid-cols-[26rem_1fr]">
        <section class="flex flex-col lg:overflow-hidden lg:border-r lg:border-line">
          <div class="space-y-4 border-b border-line p-4 sm:p-5">
            <div>
              <h1 class="text-xl font-semibold tracking-tight">Find a church</h1>
              <p class="text-sm text-muted">Search by name or place, or see what's near you.</p>
            </div>

            <.form for={@form} id="filters-form" phx-change="filter" phx-submit="filter">
              <.input
                field={@form[:q]}
                type="search"
                placeholder="Church name, city or region"
                phx-debounce="300"
                autocomplete="off"
              />
              <div class="grid grid-cols-2 gap-3">
                <.input
                  field={@form[:denomination]}
                  type="select"
                  prompt="All denominations"
                  options={@denomination_options}
                />
                <.input field={@form[:day]} type="select" prompt="Any day" options={@day_options} />
              </div>
            </.form>

            <div class="flex items-center gap-2">
              <.button
                type="button"
                id="near-me-button"
                phx-hook="NearMe"
                size="sm"
                variant={if(@near?, do: "primary", else: "secondary")}
              >
                <.icon name="hero-map-pin-mini" class="size-4" /> Near me
              </.button>
              <.button
                :if={@near?}
                type="button"
                id="clear-location"
                phx-click="clear_location"
                variant="ghost"
                size="sm"
              >
                Clear location
              </.button>
              <.link
                :if={@params != %{}}
                patch={~p"/"}
                id="reset-filters"
                class="ml-auto text-xs font-medium text-muted hover:text-ink"
              >
                Reset
              </.link>
            </div>
          </div>

          <p id="results-count" class="px-4 pt-3 text-xs font-medium text-muted sm:px-5">
            {ngettext("1 church", "%{count} churches", @count)}{if @near?, do: ", nearest first"}
          </p>

          <div
            id="churches"
            phx-update="stream"
            class="space-y-3 p-4 sm:px-5 lg:flex-1 lg:overflow-y-auto"
          >
            <div
              id="churches-empty"
              class="hidden rounded-2xl border border-dashed border-line p-8 text-center only:block"
            >
              <.icon name="hero-magnifying-glass" class="mx-auto size-8 text-muted" />
              <p class="mt-2 text-sm font-medium">No churches match your search</p>
              <p class="mt-1 text-sm text-muted">
                Try a different place, or <.link
                  navigate={~p"/churches/new"}
                  class="font-medium text-brand hover:underline"
                >add your church</.link>.
              </p>
            </div>
            <.church_card :for={{dom_id, church} <- @streams.churches} id={dom_id} church={church} />
          </div>
        </section>

        <div class="order-first h-72 border-b border-line sm:h-96 lg:order-none lg:h-full lg:border-b-0">
          <div
            id="directory-map"
            phx-hook="ChurchMap"
            phx-update="ignore"
            data-markers={Jason.encode!(@initial_markers)}
            class="z-0 h-full w-full"
          >
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :church, Church, required: true

  defp church_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={~p"/churches/#{@church.slug}"}
      class="group block rounded-2xl border border-line bg-surface p-4 shadow-xs transition hover:-translate-y-0.5 hover:border-brand/40 hover:shadow-md"
    >
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <h2 class="truncate font-semibold text-ink group-hover:text-brand">{@church.name}</h2>
          <p class="truncate text-sm text-muted">
            {Church.denomination_name(@church)} · {@church.city}
          </p>
        </div>
        <.badge :if={@church.distance_km} color="brand">
          {format_distance(@church.distance_km)}
        </.badge>
      </div>
      <ul :if={@church.activities != []} class="mt-3 space-y-1 text-xs text-muted">
        <li :for={line <- schedule_summary(@church.activities)} class="flex items-center gap-1.5">
          <.icon name="hero-clock-micro" class="size-3.5 shrink-0" /> {line}
        </li>
      </ul>
    </.link>
    """
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    params =
      socket.assigns.params
      |> Map.merge(Map.take(filters, ~w(q denomination day)))
      |> reject_blank()

    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("located", %{"lat" => lat, "lng" => lng}, socket) do
    # Rounded to ~100 m: precise enough for sorting, kinder to privacy in URLs.
    params =
      Map.merge(socket.assigns.params, %{"lat" => round_coord(lat), "lng" => round_coord(lng)})

    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("locate_failed", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_event("clear_location", _params, socket) do
    params = Map.drop(socket.assigns.params, ["lat", "lng"])
    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  # Turns URL params (all strings) into the filters Directory expects.
  defp parse_filters(params) do
    %{
      "q" => params["q"],
      "denomination" => params["denomination"],
      "day" => parse_day(params["day"]),
      "near" => parse_location(params["lat"], params["lng"])
    }
  end

  defp parse_day(day) when is_binary(day) do
    case Integer.parse(day) do
      {day, ""} when day in 1..7 -> day
      _ -> nil
    end
  end

  defp parse_day(_day), do: nil

  defp parse_location(lat, lng) when is_binary(lat) and is_binary(lng) do
    with {lat, ""} <- Float.parse(lat),
         {lng, ""} <- Float.parse(lng),
         true <- lat >= -90 and lat <= 90 and lng >= -180 and lng <= 180 do
      {lat, lng}
    else
      _ -> nil
    end
  end

  defp parse_location(_lat, _lng), do: nil

  defp round_coord(number), do: number |> Kernel.*(1.0) |> Float.round(3) |> to_string()

  defp reject_blank(params), do: Map.reject(params, fn {_key, value} -> value in [nil, ""] end)

  defp denomination_options do
    Enum.map(Denominations.list_active_denominations(), &{&1.name, &1.slug})
  end
end

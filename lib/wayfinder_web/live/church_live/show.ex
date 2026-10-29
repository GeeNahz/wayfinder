defmodule WayfinderWeb.ChurchLive.Show do
  @moduledoc """
  Public page for one approved church: details, map, directions and the
  weekly schedule. The person who registered it can also ask to edit it
  from here ("Request to edit").
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.ChurchHelpers

  alias Wayfinder.{Directory, EditRequests, Turnstile}
  alias Wayfinder.Directory.Church
  alias WayfinderWeb.ClientIp

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    church = Directory.get_public_church_by_slug!(slug)

    {:ok,
     socket
     |> assign(:page_title, church.name)
     |> assign(:church, church)
     |> assign(:schedule, schedule_by_day(church.activities))
     |> assign(:client_ip, ClientIp.from_socket(socket))
     |> assign(:edit_request_open?, false)}
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
          <.button type="button" id="open-edit-request" phx-click="open_edit_request">
            <.icon name="hero-pencil-square-mini" class="size-4" /> Request to edit
          </.button>
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

      <.modal
        :if={@edit_request_open?}
        id="edit-request-modal"
        show
        on_cancel={JS.push("close_edit_request")}
      >
        <:title>Request to edit {@church.name}</:title>
        <%= if @edit_request_sent? do %>
          <div id="edit-request-sent" class="text-sm text-muted">
            <p>
              Thanks! If that's the email this church was registered with, our team will review
              your request and email you a private edit link.
            </p>
            <.button type="button" phx-click="close_edit_request" class="mt-6 w-full">
              Close
            </.button>
          </div>
        <% else %>
          <p class="mb-4 text-sm text-muted">
            Use the email address the church was registered with. Once an admin approves,
            we'll send an edit link to that address.
          </p>
          <.form
            for={@edit_request_form}
            id="edit-request-form"
            phx-change="validate_edit_request"
            phx-submit="request_edit"
          >
            <.input field={@edit_request_form[:email]} type="email" label="Email" required />
            <.input
              field={@edit_request_form[:message]}
              type="textarea"
              label="What would you like to change? (optional)"
              rows="3"
            />
            <div
              id="edit-request-turnstile"
              phx-hook="Turnstile"
              phx-update="ignore"
              data-sitekey={Turnstile.site_key()}
              class="mb-4 min-h-16"
            >
            </div>
            <.button
              variant="primary"
              id="submit-edit-request"
              class="w-full"
              phx-disable-with="Sending..."
            >
              Send request
            </.button>
          </.form>
        <% end %>
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("open_edit_request", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_request_open?, true)
     |> assign(:edit_request_sent?, false)
     |> assign(:edit_request_form, to_form(EditRequests.change_edit_request()))}
  end

  def handle_event("close_edit_request", _params, socket) do
    {:noreply, assign(socket, :edit_request_open?, false)}
  end

  def handle_event("validate_edit_request", %{"edit_request" => params}, socket) do
    form =
      params
      |> EditRequests.change_edit_request()
      |> to_form(action: :validate)

    {:noreply, assign(socket, :edit_request_form, form)}
  end

  def handle_event("request_edit", %{"edit_request" => params} = form_data, socket) do
    changeset = EditRequests.change_edit_request(params)

    cond do
      not changeset.valid? ->
        {:noreply, assign(socket, :edit_request_form, to_form(changeset, action: :insert))}

      Turnstile.verify(form_data["cf-turnstile-response"], socket.assigns.client_ip) != :ok ->
        {:noreply,
         socket
         |> put_flash(:error, "Please complete the spam check and try again.")
         |> push_event("turnstile:reset", %{})}

      true ->
        :ok = EditRequests.request_edit(socket.assigns.church, params)
        {:noreply, assign(socket, :edit_request_sent?, true)}
    end
  end
end

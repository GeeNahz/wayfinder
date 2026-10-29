defmodule WayfinderWeb.ChurchLive.Register do
  @moduledoc """
  Public "Register a church" page.

  On submit we check Cloudflare Turnstile, save the church as unverified and
  email a verification link. The church is reviewed by the admin only after
  that link is opened.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.ChurchFormComponents

  alias Wayfinder.{Directory, Turnstile}
  alias Wayfinder.Directory.Church
  alias WayfinderWeb.ChurchLive.FormHelpers
  alias WayfinderWeb.ClientIp

  # Start with one empty activity row.
  @blank_params %{"activities" => %{"0" => %{}}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Register a church")
     |> assign(:denomination_options, FormHelpers.denomination_options())
     |> assign(:client_ip, ClientIp.from_socket(socket))
     |> assign(:places, [])
     |> assign(:geocode_error, nil)
     |> assign(:submitted_church, nil)
     |> assign_form(@blank_params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <%= if @submitted_church do %>
        <.card id="registration-submitted" class="text-center">
          <div class="mx-auto mb-4 grid size-12 place-items-center rounded-full bg-brand-soft text-brand">
            <.icon name="hero-envelope" class="size-6" />
          </div>
          <h1 class="text-xl font-semibold">Check your email</h1>
          <p class="mx-auto mt-2 max-w-md text-sm text-muted">
            We sent a confirmation link to <strong class="text-ink">{@submitted_church.contact_email}</strong>.
            Open it within 48 hours, and our team will review {@submitted_church.name} before it appears on the map.
          </p>
          <.button navigate={~p"/"} class="mt-6">Back to the map</.button>
        </.card>
      <% else %>
        <.header>
          Register a church
          <:subtitle>
            Add your church so people nearby can find it, along with your weekly activities.
          </:subtitle>
        </.header>

        <.form for={@form} id="church-form" phx-change="validate" phx-submit="save">
          <.church_fields
            form={@form}
            denomination_options={@denomination_options}
            places={@places}
            geocode_error={@geocode_error}
          />

          <.card id="church-contact-section" class="mt-6">
            <:title>Your email</:title>
            <p class="-mt-2 mb-4 text-sm text-muted">
              We'll send a link to confirm it. It's never shown publicly, and it's the only
              address we'll send edit links to later.
            </p>
            <.input
              field={@form[:contact_email]}
              type="email"
              label="Email"
              autocomplete="email"
              required
            />

            <div
              id="turnstile-widget"
              phx-hook="Turnstile"
              phx-update="ignore"
              data-sitekey={Turnstile.site_key()}
              class="min-h-16"
            >
            </div>
          </.card>

          <div class="mt-6 flex justify-end">
            <.button variant="primary" id="submit-church" phx-disable-with="Submitting...">
              Submit church
            </.button>
          </div>
        </.form>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"church" => params}, socket) do
    {:noreply, assign_form(socket, params, :validate)}
  end

  def handle_event("geocode", _params, socket) do
    case FormHelpers.geocode(socket.assigns.form) do
      {:ok, places} -> {:noreply, assign(socket, places: places, geocode_error: nil)}
      {:error, message} -> {:noreply, assign(socket, places: [], geocode_error: message)}
    end
  end

  def handle_event("pick_place", %{"index" => index}, socket) do
    place = Enum.at(socket.assigns.places, String.to_integer(index))
    params = FormHelpers.apply_place(socket.assigns.params, socket.assigns.form, place)

    {:noreply,
     socket
     |> assign(:places, [])
     |> assign_form(params, socket.assigns.form.source.action)
     |> push_event("map:set_pin", %{lat: place.latitude, lng: place.longitude})}
  end

  def handle_event("pin_moved", %{"lat" => lat, "lng" => lng}, socket) do
    params = FormHelpers.apply_pin(socket.assigns.params, lat, lng)
    {:noreply, assign_form(socket, params, socket.assigns.form.source.action)}
  end

  def handle_event("save", %{"church" => params} = form_data, socket) do
    changeset = Directory.change_registration(%Church{}, params)

    # 1. Show form errors first (without using up the Turnstile token).
    # 2. Then the spam check. 3. Then save and send the email.
    cond do
      not changeset.valid? ->
        {:noreply, assign_form(socket, params, :insert)}

      Turnstile.verify(form_data["cf-turnstile-response"], socket.assigns.client_ip) != :ok ->
        {:noreply,
         socket
         |> put_flash(:error, "Please complete the spam check and try again.")
         |> push_event("turnstile:reset", %{})
         |> assign_form(params, :insert)}

      true ->
        case Directory.register_church(params, &url(~p"/churches/verify/#{&1}")) do
          {:ok, church} ->
            {:noreply, assign(socket, :submitted_church, church)}

          {:error, changeset} ->
            {:noreply,
             socket
             |> push_event("turnstile:reset", %{})
             |> assign(:params, params)
             |> assign(:form, to_form(changeset))}
        end
    end
  end

  # Rebuilds the form from params. `action` decides whether errors show:
  # nil = no errors yet, :validate/:insert = show them.
  defp assign_form(socket, params, action \\ nil) do
    changeset =
      %Church{}
      |> Directory.change_registration(params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end

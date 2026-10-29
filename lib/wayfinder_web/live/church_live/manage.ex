defmodule WayfinderWeb.ChurchLive.Manage do
  @moduledoc """
  Edit page opened from the private link emailed when the admin grants an
  edit request (`/churches/:slug/manage/:token`). Changes go live straight away.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.ChurchFormComponents

  alias Wayfinder.Directory
  alias Wayfinder.Directory.Policy
  alias WayfinderWeb.ChurchLive.FormHelpers

  @impl true
  def mount(%{"slug" => slug, "token" => token}, _session, socket) do
    church = Directory.get_church_by_slug(slug)
    link_church = Directory.get_church_by_manage_token(token)

    if church && link_church && Policy.can_manage?({:manage_link, link_church}, church) do
      {:ok,
       socket
       |> assign(:page_title, "Edit #{church.name}")
       |> assign(:church, church)
       |> assign(:denomination_options, FormHelpers.denomination_options(church))
       |> assign(:places, [])
       |> assign(:geocode_error, nil)
       |> assign_form(%{})}
    else
      {:ok, assign(socket, page_title: "Link expired", church: nil)}
    end
  end

  @impl true
  def render(%{church: nil} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.card id="manage-link-invalid" class="text-center">
        <div class="mx-auto mb-4 grid size-12 place-items-center rounded-full bg-warning-soft text-warning">
          <.icon name="hero-lock-closed" class="size-6" />
        </div>
        <h1 class="text-xl font-semibold">This edit link has expired</h1>
        <p class="mx-auto mt-2 max-w-md text-sm text-muted">
          Edit links work for 7 days. Open the church's page and choose
          "Request to edit" to get a new one.
        </p>
        <.button navigate={~p"/"} class="mt-6">Back to the map</.button>
      </.card>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Edit {@church.name}
        <:subtitle>
          Changes are published as soon as you save. This private link expires in 7 days.
        </:subtitle>
        <:actions>
          <.button
            :if={@church.status == :approved}
            navigate={~p"/churches/#{@church.slug}"}
            size="sm"
          >
            View public page
          </.button>
        </:actions>
      </.header>

      <div
        :if={@church.status != :approved}
        id="manage-status-note"
        class="mb-6 rounded-xl border border-warning/30 bg-warning-soft p-4 text-sm text-ink"
      >
        This church is currently <strong>{@church.status}</strong> and not shown publicly.
      </div>

      <.form for={@form} id="church-form" phx-change="validate" phx-submit="save">
        <.church_fields
          form={@form}
          denomination_options={@denomination_options}
          places={@places}
          geocode_error={@geocode_error}
        />

        <div class="mt-6 flex justify-end">
          <.button variant="primary" id="save-church" phx-disable-with="Saving...">
            Save changes
          </.button>
        </div>
      </.form>
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

  def handle_event("save", %{"church" => params}, socket) do
    case Directory.update_church(socket.assigns.church, params) do
      {:ok, church} ->
        {:noreply,
         socket
         |> put_flash(:info, "Changes saved.")
         |> assign(:church, church)
         |> assign_form(%{})}

      {:error, changeset} ->
        {:noreply, socket |> assign(:params, params) |> assign(:form, to_form(changeset))}
    end
  end

  defp assign_form(socket, params, action \\ nil) do
    changeset =
      socket.assigns.church
      |> Directory.change_church(params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end

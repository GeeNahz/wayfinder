defmodule WayfinderWeb.Admin.ChurchLive.Edit do
  @moduledoc """
  Admin edit page for a church, using the same form as the public pages.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.ChurchFormComponents

  alias Wayfinder.Directory
  alias Wayfinder.Directory.Policy
  alias WayfinderWeb.ChurchLive.FormHelpers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    church = Directory.get_church!(id)

    # The /admin live_session already requires a super admin; the policy
    # check keeps every edit path going through the same rule.
    true = Policy.can_manage?(socket.assigns.current_scope, church)

    {:ok,
     socket
     |> assign(:page_title, "Edit #{church.name}")
     |> assign(:church, church)
     |> assign(:denomination_options, FormHelpers.denomination_options(church))
     |> assign(:places, [])
     |> assign(:geocode_error, nil)
     |> assign_form(%{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:churches}>
      <.link
        navigate={~p"/admin/churches/#{@church}"}
        class="mb-4 inline-flex items-center gap-1 text-sm font-medium text-muted hover:text-ink"
      >
        <.icon name="hero-arrow-left-mini" class="size-4" /> Back to {@church.name}
      </.link>

      <div class="max-w-3xl">
        <.header>
          Edit {@church.name}
          <:subtitle>Contact email: {@church.contact_email} (can't be changed)</:subtitle>
        </.header>

        <.form for={@form} id="church-form" phx-change="validate" phx-submit="save">
          <.church_fields
            form={@form}
            denomination_options={@denomination_options}
            places={@places}
            geocode_error={@geocode_error}
          />

          <div class="mt-6 flex justify-end gap-2">
            <.button navigate={~p"/admin/churches/#{@church}"} variant="ghost">Cancel</.button>
            <.button variant="primary" id="save-church" phx-disable-with="Saving...">
              Save changes
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.admin>
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
         |> push_navigate(to: ~p"/admin/churches/#{church}")}

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

defmodule WayfinderWeb.Admin.DenominationLive.Index do
  @moduledoc """
  Denominations list with a modal to create (`/new`) or edit (`/:id/edit`).
  Denominations are archived rather than deleted, so churches keep theirs.
  """
  use WayfinderWeb, :live_view

  alias Wayfinder.Denominations
  alias Wayfinder.Denominations.Denomination

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Denominations")
     # Each row is a {denomination, church_count} tuple, so tell the stream how to id it.
     |> stream_configure(:denominations, dom_id: fn {d, _count} -> "denominations-#{d.id}" end)
     |> load_denominations()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :denomination, nil)

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:denomination, %Denomination{})
    |> assign(:form, to_form(Denominations.change_denomination(%Denomination{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    denomination = Denominations.get_denomination!(id)

    socket
    |> assign(:denomination, denomination)
    |> assign(:form, to_form(Denominations.change_denomination(denomination)))
  end

  defp load_denominations(socket) do
    stream(socket, :denominations, Denominations.list_denominations_with_church_counts(),
      reset: true
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:denominations}>
      <.header>
        Denominations
        <:subtitle>The list people choose from when registering a church.</:subtitle>
        <:actions>
          <.button patch={~p"/admin/denominations/new"} variant="primary" id="new-denomination">
            <.icon name="hero-plus-mini" class="size-4" /> New denomination
          </.button>
        </:actions>
      </.header>

      <.table
        id="denominations"
        rows={@streams.denominations}
        row_item={fn {_dom_id, row} -> row end}
      >
        <:col :let={{denomination, _count}} label="Name">
          <p class="font-medium">{denomination.name}</p>
          <p :if={denomination.description} class="max-w-md truncate text-xs text-muted">
            {denomination.description}
          </p>
        </:col>
        <:col :let={{_denomination, count}} label="Churches">
          <span class="tabular-nums">{count}</span>
        </:col>
        <:col :let={{denomination, _count}} label="Status">
          <.badge :if={Denomination.archived?(denomination)}>Archived</.badge>
          <.badge :if={!Denomination.archived?(denomination)} color="success">Active</.badge>
        </:col>
        <:action :let={{denomination, _count}}>
          <.link
            patch={~p"/admin/denominations/#{denomination}/edit"}
            id={"edit-denomination-#{denomination.id}"}
            class="text-brand hover:underline"
          >
            Edit
          </.link>
        </:action>
        <:action :let={{denomination, _count}}>
          <.link
            id={"toggle-archive-#{denomination.id}"}
            phx-click="toggle_archive"
            phx-value-id={denomination.id}
            class="text-muted hover:text-ink"
          >
            {if Denomination.archived?(denomination), do: "Restore", else: "Archive"}
          </.link>
        </:action>
      </.table>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="denomination-modal"
        show
        on_cancel={JS.patch(~p"/admin/denominations")}
      >
        <:title>{if @live_action == :new, do: "New denomination", else: "Edit denomination"}</:title>
        <.form for={@form} id="denomination-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} label="Name" required />
          <.input field={@form[:description]} type="textarea" label="Description (optional)" rows="3" />
          <div class="flex justify-end gap-2">
            <.button type="button" patch={~p"/admin/denominations"} variant="ghost">Cancel</.button>
            <.button variant="primary" id="save-denomination" phx-disable-with="Saving...">
              Save
            </.button>
          </div>
        </.form>
      </.modal>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("validate", %{"denomination" => params}, socket) do
    changeset = Denominations.change_denomination(socket.assigns.denomination, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"denomination" => params}, socket) do
    result =
      case socket.assigns.live_action do
        :new -> Denominations.create_denomination(params)
        :edit -> Denominations.update_denomination(socket.assigns.denomination, params)
      end

    case result do
      {:ok, denomination} ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved #{denomination.name}.")
         |> load_denominations()
         |> push_patch(to: ~p"/admin/denominations")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("toggle_archive", %{"id" => id}, socket) do
    denomination = Denominations.get_denomination!(id)

    {:ok, _denomination} =
      if Denomination.archived?(denomination),
        do: Denominations.unarchive_denomination(denomination),
        else: Denominations.archive_denomination(denomination)

    {:noreply, load_denominations(socket)}
  end
end

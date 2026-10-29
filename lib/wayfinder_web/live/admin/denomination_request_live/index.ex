defmodule WayfinderWeb.Admin.DenominationRequestLive.Index do
  @moduledoc """
  Pending requests for denominations that aren't listed yet. Each one is
  either approved (creating a new denomination) or merged into an
  existing one. Either way, the waiting churches are moved onto it.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.AdminComponents

  alias Wayfinder.Denominations

  @impl true
  def mount(_params, _session, socket) do
    requests = Denominations.list_pending_requests()

    {:ok,
     socket
     |> assign(:page_title, "Denomination requests")
     |> assign(:pending_count, length(requests))
     |> assign(:resolving, nil)
     |> stream(:requests, requests)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:denomination_requests}>
      <.header>
        Denomination requests
        <:subtitle>
          Denominations people asked for while registering. Churches waiting on a request
          can't be approved until it's resolved.
        </:subtitle>
      </.header>

      <p
        :if={@pending_count == 0}
        id="requests-empty"
        class="rounded-2xl border border-dashed border-line p-10 text-center text-sm text-muted"
      >
        No pending requests.
      </p>

      <div id="requests" phx-update="stream" class="space-y-3">
        <div
          :for={{dom_id, request} <- @streams.requests}
          id={dom_id}
          class="flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-line bg-surface p-5"
        >
          <div>
            <p class="font-semibold">{request.name}</p>
            <p class="text-sm text-muted">
              Requested {format_date(request.inserted_at)} · {ngettext(
                "1 church waiting",
                "%{count} churches waiting",
                length(request.churches)
              )}: {Enum.map_join(request.churches, ", ", & &1.name)}
            </p>
          </div>
          <div class="flex gap-2">
            <.button
              id={"approve-request-#{request.id}"}
              phx-click="start_approve"
              phx-value-id={request.id}
              variant="primary"
              size="sm"
            >
              Approve as new
            </.button>
            <.button
              id={"merge-request-#{request.id}"}
              phx-click="start_merge"
              phx-value-id={request.id}
              size="sm"
            >
              Merge into existing
            </.button>
          </div>
        </div>
      </div>

      <.modal :if={@resolving} id="resolve-modal" show on_cancel={JS.push("cancel")}>
        <:title>
          {if @resolving.mode == :approve, do: "Add a new denomination", else: "Merge request"}
        </:title>

        <.form
          :if={@resolving.mode == :approve}
          for={@resolving.form}
          id="approve-request-form"
          phx-submit="approve"
        >
          <p class="mb-4 text-sm text-muted">Tidy up the name if needed before adding it.</p>
          <.input field={@resolving.form[:name]} label="Name" required />
          <.input
            field={@resolving.form[:description]}
            type="textarea"
            label="Description (optional)"
            rows="3"
          />
          <div class="flex justify-end">
            <.button variant="primary" id="confirm-approve">Add denomination</.button>
          </div>
        </.form>

        <.form
          :if={@resolving.mode == :merge}
          for={@resolving.form}
          id="merge-request-form"
          phx-submit="merge"
        >
          <p class="mb-4 text-sm text-muted">
            Churches that asked for <strong class="text-ink">{@resolving.request.name}</strong>
            will be moved to the denomination you pick.
          </p>
          <.input
            field={@resolving.form[:denomination_id]}
            type="select"
            label="Existing denomination"
            prompt="Choose one"
            options={@resolving.options}
            required
          />
          <div class="flex justify-end">
            <.button variant="primary" id="confirm-merge">Merge</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("start_approve", %{"id" => id}, socket) do
    request = Denominations.get_request!(id)
    form = to_form(%{"name" => request.name, "description" => ""}, as: :denomination)
    {:noreply, assign(socket, :resolving, %{mode: :approve, request: request, form: form})}
  end

  def handle_event("start_merge", %{"id" => id}, socket) do
    request = Denominations.get_request!(id)
    options = Enum.map(Denominations.list_active_denominations(), &{&1.name, &1.id})

    {:noreply,
     assign(socket, :resolving, %{
       mode: :merge,
       request: request,
       options: options,
       form: to_form(%{"denomination_id" => ""}, as: :merge)
     })}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :resolving, nil)}
  end

  def handle_event("approve", %{"denomination" => params}, socket) do
    %{request: request} = socket.assigns.resolving

    case Denominations.approve_request(socket.assigns.current_scope, request, params) do
      {:ok, denomination} ->
        {:noreply, resolved(socket, request, "Added #{denomination.name}.")}

      {:error, changeset} ->
        form = to_form(changeset, as: :denomination)
        {:noreply, assign(socket, :resolving, %{socket.assigns.resolving | form: form})}
    end
  end

  def handle_event("merge", %{"merge" => %{"denomination_id" => id}}, socket) when id != "" do
    %{request: request} = socket.assigns.resolving
    denomination = Denominations.get_denomination!(id)

    {:ok, _denomination} =
      Denominations.merge_request(socket.assigns.current_scope, request, denomination)

    {:noreply, resolved(socket, request, "Merged into #{denomination.name}.")}
  end

  def handle_event("merge", _params, socket), do: {:noreply, socket}

  defp resolved(socket, request, message) do
    socket
    |> assign(:resolving, nil)
    |> update(:pending_count, &(&1 - 1))
    |> stream_delete(:requests, request)
    |> put_flash(:info, message <> " Waiting churches can now be approved.")
  end
end

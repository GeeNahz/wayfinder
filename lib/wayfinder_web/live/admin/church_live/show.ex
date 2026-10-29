defmodule WayfinderWeb.Admin.ChurchLive.Show do
  @moduledoc """
  One church in the admin: full details plus moderation actions
  (approve, reject, suspend, edit, revoke edit links, delete).
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.AdminComponents
  import WayfinderWeb.ChurchHelpers

  alias Wayfinder.Directory
  alias Wayfinder.Directory.Church

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:rejecting?, false)
     |> assign_church(Directory.get_church!(id))}
  end

  defp assign_church(socket, church) do
    socket
    |> assign(:page_title, church.name)
    |> assign(:church, church)
    |> assign(:schedule, schedule_by_day(church.activities))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:churches}>
      <.link
        navigate={~p"/admin/churches"}
        class="mb-4 inline-flex items-center gap-1 text-sm font-medium text-muted hover:text-ink"
      >
        <.icon name="hero-arrow-left-mini" class="size-4" /> Churches
      </.link>

      <.header>
        <span class="flex flex-wrap items-center gap-3">
          {@church.name} <.status_badge id="church-status" status={@church.status} />
        </span>
        <:subtitle>{Church.full_address(@church)}</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/churches/#{@church}/edit"} size="sm" id="edit-church">
            <.icon name="hero-pencil-square-mini" class="size-4" /> Edit
          </.button>
          <.button
            :if={@church.status == :approved}
            href={~p"/churches/#{@church.slug}"}
            target="_blank"
            size="sm"
          >
            Public page <.icon name="hero-arrow-top-right-on-square-mini" class="size-4" />
          </.button>
        </:actions>
      </.header>

      <div
        :if={@church.status == :pending and is_nil(@church.denomination_id)}
        id="denomination-pending-note"
        class="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-warning/30 bg-warning-soft p-4 text-sm"
      >
        <span>
          This church asked for a new denomination, <strong>{@church.requested_denomination}</strong>.
          Resolve that request before approving.
        </span>
        <.button navigate={~p"/admin/denomination-requests"} size="sm">Review request</.button>
      </div>

      <.card id="moderation-actions" class="mb-6">
        <:title>Actions</:title>
        <div class="flex flex-wrap gap-2">
          <.button
            :if={@church.status in [:pending, :rejected]}
            id="approve-church"
            phx-click="approve"
            variant="primary"
            disabled={is_nil(@church.denomination_id)}
          >
            <.icon name="hero-check-mini" class="size-4" /> Approve
          </.button>
          <.button
            :if={@church.status in [:pending, :approved]}
            id="reject-church"
            phx-click="open_reject"
          >
            <.icon name="hero-x-mark-mini" class="size-4" /> Reject
          </.button>
          <.button :if={@church.status == :approved} id="suspend-church" phx-click="suspend">
            <.icon name="hero-pause-mini" class="size-4" /> Suspend
          </.button>
          <.button :if={@church.status == :suspended} id="unsuspend-church" phx-click="unsuspend">
            <.icon name="hero-play-mini" class="size-4" /> Unsuspend
          </.button>
          <.button id="revoke-links" phx-click="revoke_links" variant="ghost">
            Revoke edit links
          </.button>
          <.button
            id="delete-church"
            phx-click="delete"
            data-confirm={"Delete #{@church.name}? This can't be undone."}
            variant="danger"
            class="ml-auto"
          >
            <.icon name="hero-trash-mini" class="size-4" /> Delete
          </.button>
        </div>
      </.card>

      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <div class="space-y-6">
          <.card>
            <:title>Details</:title>
            <.list>
              <:item title="Denomination">
                {Church.denomination_name(@church) || "—"}
                <.badge :if={is_nil(@church.denomination_id)} color="warning">requested</.badge>
              </:item>
              <:item title="Contact email">{@church.contact_email}</:item>
              <:item title="Email verified">{format_date(@church.email_verified_at)}</:item>
              <:item title="Phone">{@church.phone || "—"}</:item>
              <:item title="Website">{@church.website || "—"}</:item>
              <:item title="Description">{@church.description || "—"}</:item>
              <:item title="Submitted">{format_date(@church.inserted_at)}</:item>
              <:item title="Approved">{format_date(@church.approved_at)}</:item>
              <:item title="Last edited">{format_date(@church.last_edited_at)}</:item>
              <:item :if={@church.rejection_reason} title="Rejection reason">
                {@church.rejection_reason}
              </:item>
            </.list>
          </.card>

          <.card id="admin-church-schedule">
            <:title>Weekly activities</:title>
            <p :if={@schedule == []} class="text-sm text-muted">No activities listed.</p>
            <div :for={{day, activities} <- @schedule} class="mb-3 last:mb-0">
              <h3 class="text-sm font-semibold">{day}</h3>
              <p :for={activity <- activities} class="text-sm text-muted">
                {format_time_range(activity)} · {activity.name}
              </p>
            </div>
          </.card>
        </div>

        <div class="self-start overflow-hidden rounded-2xl border border-line">
          <div
            id="admin-church-map"
            phx-hook="ChurchMap"
            phx-update="ignore"
            data-markers={Jason.encode!([map_marker(@church, nil)])}
            class="z-0 h-72"
          >
          </div>
          <p class="border-t border-line bg-surface px-4 py-3 text-xs text-muted tabular-nums">
            {@church.latitude}, {@church.longitude}
          </p>
        </div>
      </div>

      <.modal :if={@rejecting?} id="reject-modal" show on_cancel={JS.push("close_reject")}>
        <:title>Reject {@church.name}</:title>
        <.form for={@reject_form} id="reject-form" phx-submit="reject">
          <.input
            field={@reject_form[:reason]}
            type="textarea"
            label="Reason (emailed to the submitter)"
            rows="4"
            required
          />
          <div class="flex justify-end gap-2">
            <.button type="button" phx-click="close_reject" variant="ghost">Cancel</.button>
            <.button variant="danger" id="confirm-reject">Reject church</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("approve", _params, socket) do
    case Directory.approve_church(socket.assigns.church, &url(~p"/churches/#{&1.slug}")) do
      {:ok, _church} ->
        {:noreply,
         socket |> put_flash(:info, "Church approved and the submitter emailed.") |> reload()}

      {:error, :denomination_pending} ->
        {:noreply, put_flash(socket, :error, "Resolve the denomination request first.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't approve this church.")}
    end
  end

  def handle_event("open_reject", _params, socket) do
    {:noreply,
     socket
     |> assign(:rejecting?, true)
     |> assign(:reject_form, to_form(%{"reason" => ""}, as: :rejection))}
  end

  def handle_event("close_reject", _params, socket) do
    {:noreply, assign(socket, :rejecting?, false)}
  end

  def handle_event("reject", %{"rejection" => %{"reason" => reason}}, socket) do
    case Directory.reject_church(socket.assigns.church, String.trim(reason)) do
      {:ok, _church} ->
        {:noreply,
         socket
         |> assign(:rejecting?, false)
         |> put_flash(:info, "Church rejected and the submitter emailed.")
         |> reload()}

      {:error, _changeset} ->
        form =
          to_form(%{"reason" => reason},
            as: :rejection,
            errors: [reason: {"please give a reason", []}]
          )

        {:noreply, assign(socket, :reject_form, form)}
    end
  end

  def handle_event("suspend", _params, socket) do
    {:ok, _church} = Directory.suspend_church(socket.assigns.church)

    {:noreply,
     socket |> put_flash(:info, "Church suspended (hidden from the public).") |> reload()}
  end

  def handle_event("unsuspend", _params, socket) do
    {:ok, _church} = Directory.unsuspend_church(socket.assigns.church)
    {:noreply, socket |> put_flash(:info, "Church is public again.") |> reload()}
  end

  def handle_event("revoke_links", _params, socket) do
    count = Directory.revoke_manage_links(socket.assigns.church)
    {:noreply, put_flash(socket, :info, "Revoked #{count} edit link(s).")}
  end

  def handle_event("delete", _params, socket) do
    {:ok, church} = Directory.delete_church(socket.assigns.church)

    {:noreply,
     socket
     |> put_flash(:info, "#{church.name} was deleted.")
     |> push_navigate(to: ~p"/admin/churches")}
  end

  defp reload(socket) do
    assign_church(socket, Directory.get_church!(socket.assigns.church.id))
  end
end

defmodule WayfinderWeb.Admin.EditRequestLive.Index do
  @moduledoc """
  Pending "please let me edit my church" requests. Granting one emails a
  7-day manage link to the church's verified contact email.
  """
  use WayfinderWeb, :live_view

  import WayfinderWeb.AdminComponents

  alias Wayfinder.EditRequests

  @impl true
  def mount(_params, _session, socket) do
    requests = EditRequests.list_pending_edit_requests()

    {:ok,
     socket
     |> assign(:page_title, "Edit requests")
     |> assign(:pending_count, length(requests))
     |> stream(:edit_requests, requests)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active={:edit_requests}>
      <.header>
        Edit requests
        <:subtitle>
          Only requests from a church's verified contact email appear here. Granting sends
          a private edit link (valid for 7 days) to that email.
        </:subtitle>
      </.header>

      <p
        :if={@pending_count == 0}
        id="edit-requests-empty"
        class="rounded-2xl border border-dashed border-line p-10 text-center text-sm text-muted"
      >
        No pending edit requests.
      </p>

      <div id="edit-requests" phx-update="stream" class="space-y-3">
        <div
          :for={{dom_id, request} <- @streams.edit_requests}
          id={dom_id}
          class="flex flex-wrap items-start justify-between gap-4 rounded-2xl border border-line bg-surface p-5"
        >
          <div class="min-w-0">
            <.link
              navigate={~p"/admin/churches/#{request.church}"}
              class="font-semibold hover:text-brand"
            >
              {request.church.name}
            </.link>
            <p class="text-sm text-muted">{request.email} · {format_date(request.inserted_at)}</p>
            <p :if={request.message} class="mt-2 max-w-xl text-sm">"{request.message}"</p>
          </div>
          <div class="flex gap-2">
            <.button
              id={"grant-#{request.id}"}
              phx-click="grant"
              phx-value-id={request.id}
              variant="primary"
              size="sm"
              phx-disable-with="Sending..."
            >
              Grant & email link
            </.button>
            <.button
              id={"reject-#{request.id}"}
              phx-click="reject"
              phx-value-id={request.id}
              size="sm"
            >
              Reject
            </.button>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("grant", %{"id" => id}, socket) do
    request = EditRequests.get_edit_request!(id)
    manage_url = &url(~p"/churches/#{&1.slug}/manage/#{&2}")

    {:ok, _request} =
      EditRequests.grant_edit_request(socket.assigns.current_scope, request, manage_url)

    {:noreply, resolved(socket, request, "Edit link sent to #{request.church.contact_email}.")}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    request = EditRequests.get_edit_request!(id)
    {:ok, _request} = EditRequests.reject_edit_request(socket.assigns.current_scope, request)
    {:noreply, resolved(socket, request, "Request rejected.")}
  end

  defp resolved(socket, request, message) do
    socket
    |> update(:pending_count, &(&1 - 1))
    |> stream_delete(:edit_requests, request)
    |> put_flash(:info, message)
  end
end

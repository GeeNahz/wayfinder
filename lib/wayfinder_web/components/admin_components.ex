defmodule WayfinderWeb.AdminComponents do
  @moduledoc """
  Small UI pieces used across the super admin portal.
  """
  use WayfinderWeb, :html

  @doc "A coloured badge for a church status."
  attr :status, :atom, required: true
  attr :rest, :global

  def status_badge(assigns) do
    colors = %{
      unverified: "neutral",
      pending: "warning",
      approved: "success",
      rejected: "danger",
      suspended: "neutral"
    }

    assigns = assign(assigns, :color, Map.fetch!(colors, assigns.status))

    ~H"""
    <.badge color={@color} {@rest}>{Phoenix.Naming.humanize(@status)}</.badge>
    """
  end

  @doc "A dashboard number with a label and a link."
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :navigate, :string, required: true
  attr :highlight, :boolean, default: false, doc: "draws attention when there's work to do"

  def stat_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@navigate}
      class={[
        "group rounded-2xl border bg-surface p-5 shadow-xs transition hover:-translate-y-0.5 hover:shadow-md",
        if(@highlight, do: "border-warning/50", else: "border-line")
      ]}
    >
      <div class="flex items-center justify-between">
        <p class="text-sm font-medium text-muted">{@label}</p>
        <span class={[
          "grid size-9 place-items-center rounded-lg",
          if(@highlight, do: "bg-warning-soft text-warning", else: "bg-brand-soft text-brand")
        ]}>
          <.icon name={@icon} class="size-5" />
        </span>
      </div>
      <p class="mt-3 text-3xl font-semibold tabular-nums tracking-tight">{@value}</p>
    </.link>
    """
  end

  @doc ~S"""
  Short date for admin tables, e.g. "29 Oct 2026".
  """
  def format_date(nil), do: "—"
  def format_date(datetime), do: Calendar.strftime(datetime, "%-d %b %Y")
end

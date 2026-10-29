defmodule WayfinderWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WayfinderWeb, :html

  alias Wayfinder.Accounts.Scope

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the public app layout: a top bar with navigation and the page body.

  Use `width` to pick how wide the content area is:
  `"narrow"` for forms, `"wide"` for pages with sidebars, `"full"` for the map.

  ## Examples

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :width, :string, default: "narrow", values: ~w(narrow wide full)

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <header class="sticky top-0 z-40 border-b border-line bg-canvas/80 backdrop-blur-md">
        <nav class="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
          <.link navigate={~p"/"} class="flex items-center gap-2" id="site-logo">
            <.logo />
            <span class="text-base font-semibold tracking-tight">Wayfinder</span>
          </.link>

          <div class="flex items-center gap-1 sm:gap-2">
            <.nav_link navigate={~p"/"} class="hidden sm:block">Find a church</.nav_link>
            <.link
              navigate={~p"/churches/new"}
              id="register-church-link"
              class="rounded-lg bg-brand px-3 py-2 text-sm font-medium text-on-brand shadow-sm transition hover:bg-brand-strong"
            >
              Register a church
            </.link>
            <.nav_link :if={Scope.super_admin?(@current_scope)} navigate={~p"/admin"}>
              Admin
            </.nav_link>
            <%!-- Signed-in menu (only the platform admin can sign in for now) --%>
            <div :if={@current_scope} id="user-menu" class="hidden items-center gap-1 md:flex">
              <span class="max-w-40 truncate px-2 text-xs text-muted">
                {@current_scope.user.email}
              </span>
              <.link
                href={~p"/users/settings"}
                class="rounded-lg px-2 py-2 text-sm text-muted transition hover:text-ink"
              >
                Settings
              </.link>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="rounded-lg px-2 py-2 text-sm text-muted transition hover:text-ink"
              >
                Log out
              </.link>
            </div>
            <.theme_toggle />
          </div>
        </nav>
      </header>

      <main class={[
        "flex-1",
        @width == "narrow" && "mx-auto w-full max-w-2xl px-4 py-10 sm:px-6 sm:py-14",
        @width == "wide" && "mx-auto w-full max-w-6xl px-4 py-10 sm:px-6 lg:px-8",
        @width == "full" && "flex w-full flex-col"
      ]}>
        {render_slot(@inner_block)}
      </main>

      <footer :if={@width != "full"} class="border-t border-line py-6 text-center text-xs text-muted">
        Wayfinder &middot; Helping people find a church near them
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the super admin layout: a sidebar with the admin sections.

  Pass `active` so the current section is highlighted.

  ## Examples

      <Layouts.admin flash={@flash} current_scope={@current_scope} active={:dashboard}>
        <h1>Dashboard</h1>
      </Layouts.admin>
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, required: true
  attr :active, :atom, required: true, doc: "the key of the highlighted nav item"
  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <div class="min-h-screen lg:flex">
      <aside class="border-b border-line bg-surface lg:fixed lg:inset-y-0 lg:w-64 lg:border-r lg:border-b-0">
        <div class="flex h-16 items-center justify-between gap-2 px-4 lg:px-6">
          <.link navigate={~p"/admin"} class="flex items-center gap-2">
            <.logo />
            <span class="font-semibold tracking-tight">Wayfinder</span>
            <.badge color="brand">Admin</.badge>
          </.link>
          <div class="lg:hidden"><.theme_toggle /></div>
        </div>

        <nav class="flex gap-1 overflow-x-auto px-3 pb-3 lg:flex-col lg:px-4 lg:pb-0">
          <.admin_nav_link
            :for={{key, label, icon, path} <- admin_nav_items()}
            navigate={path}
            icon={icon}
            active={@active == key}
          >
            {label}
          </.admin_nav_link>
        </nav>

        <div class="hidden border-t border-line p-4 text-xs text-muted lg:absolute lg:inset-x-0 lg:bottom-0 lg:block">
          <div class="flex items-center justify-between gap-2">
            <p class="truncate">{@current_scope.user.email}</p>
            <.theme_toggle />
          </div>
          <div class="mt-3 flex gap-4 whitespace-nowrap">
            <.link navigate={~p"/"} class="hover:text-ink">View site</.link>
            <.link href={~p"/users/settings"} class="hover:text-ink">Settings</.link>
            <.link href={~p"/users/log-out"} method="delete" class="hover:text-ink">
              Log out
            </.link>
          </div>
        </div>
      </aside>

      <main class="flex-1 px-4 py-8 sm:px-6 lg:ml-64 lg:px-10 lg:py-10">
        <div class="mx-auto max-w-6xl">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  # The sections shown in the admin sidebar: {key, label, icon, path}.
  defp admin_nav_items do
    [
      {:dashboard, "Dashboard", "hero-squares-2x2", ~p"/admin"},
      {:churches, "Churches", "hero-building-library", ~p"/admin/churches"},
      {:denominations, "Denominations", "hero-tag", ~p"/admin/denominations"},
      {:denomination_requests, "Denomination requests", "hero-inbox-arrow-down",
       ~p"/admin/denomination-requests"},
      {:edit_requests, "Edit requests", "hero-pencil-square", ~p"/admin/edit-requests"}
    ]
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp admin_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-3 whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium transition",
        if(@active,
          do: "bg-brand-soft text-brand",
          else: "text-muted hover:bg-surface-2 hover:text-ink"
        )
      ]}
    >
      <.icon name={@icon} class="size-5" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :navigate, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "rounded-lg px-3 py-2 text-sm font-medium text-muted transition hover:bg-surface-2 hover:text-ink",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  The Wayfinder mark: a map pin with a small cross.
  """
  def logo(assigns) do
    ~H"""
    <span class="grid size-8 place-items-center rounded-lg bg-brand text-on-brand shadow-sm">
      <svg viewBox="0 0 24 24" fill="none" class="size-5" aria-hidden="true">
        <path
          d="M12 22s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z"
          stroke="currentColor"
          stroke-width="1.8"
          stroke-linejoin="round"
        />
        <path d="M12 6.5v7M9 9h6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" />
      </svg>
    </span>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex items-center rounded-full border border-line bg-surface-2 p-0.5">
      <div class="absolute left-0.5 h-7 w-7 rounded-full bg-surface shadow-sm transition-[left] [[data-theme=light]_&]:left-[1.875rem] [[data-theme=dark]_&]:left-[3.625rem] [[data-theme-source=system]_&]:!left-0.5" />

      <button
        :for={
          {theme, icon} <- [
            system: "hero-computer-desktop-micro",
            light: "hero-sun-micro",
            dark: "hero-moon-micro"
          ]
        }
        class="relative flex size-7 cursor-pointer items-center justify-center text-muted transition hover:text-ink"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme={theme}
        aria-label={"Use #{theme} theme"}
      >
        <.icon name={icon} class="size-4" />
      </button>
    </div>
    """
  end
end

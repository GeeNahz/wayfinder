defmodule WayfinderWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  Styling is plain Tailwind CSS. Colours come from the design tokens in
  `assets/css/app.css` (e.g. `bg-surface`, `text-muted`, `border-line`,
  `bg-brand`), so every component works in both light and dark mode.
  Here are useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: WayfinderWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Welcome Back!
      </.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50"
      {@rest}
    >
      <div class={[
        "flex w-80 sm:w-96 items-start gap-3 rounded-xl border p-4 text-sm shadow-lg",
        "bg-surface text-ink",
        @kind == :info && "border-info/30",
        @kind == :error && "border-danger/30"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0 text-info" />
        <.icon
          :if={@kind == :error}
          name="hero-exclamation-circle"
          class="size-5 shrink-0 text-danger"
        />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p class="text-muted">{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"} variant="ghost" size="sm">Home</.button>

  Variants: `primary`, `secondary` (default), `ghost` and `danger`.
  Extra classes passed with `class` are added on top of the defaults.
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type)
  attr :class, :any, default: nil
  attr :variant, :string, default: "secondary", values: ~w(primary secondary ghost danger)
  attr :size, :string, default: "md", values: ~w(sm md)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "bg-brand text-on-brand shadow-sm hover:bg-brand-strong",
      "secondary" => "border border-line bg-surface text-ink shadow-xs hover:bg-surface-2",
      "ghost" => "text-ink hover:bg-surface-2",
      "danger" => "bg-danger text-white shadow-sm hover:opacity-90"
    }

    sizes = %{"sm" => "h-8 px-3 text-xs", "md" => "h-10 px-4 text-sm"}

    assigns =
      assign(assigns, :class, [
        "inline-flex cursor-pointer items-center justify-center gap-2 rounded-lg font-medium",
        "transition duration-150 ease-out active:scale-[0.98]",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand",
        "disabled:pointer-events-none disabled:opacity-50 phx-submit-loading:opacity-70",
        Map.fetch!(variants, assigns.variant),
        Map.fetch!(sizes, assigns.size),
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://phoenix-html.hexdocs.pm/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-4">
      <label for={@id} class="inline-flex cursor-pointer items-center gap-2 text-sm text-ink">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "size-4 rounded border-line accent-(--wf-brand)"}
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-4">
      <label for={@id}>
        <span :if={@label} class={label_class()}>{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || field_class(), @errors != [] && (@error_class || field_error_class())]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-4">
      <label for={@id}>
        <span :if={@label} class={label_class()}>{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || [field_class(), "min-h-24"],
            @errors != [] && (@error_class || field_error_class())
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-4">
      <label for={@id}>
        <span :if={@label} class={label_class()}>{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || field_class(),
            @errors != [] && (@error_class || field_error_class())
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Shared classes for form fields, so every input looks the same.
  defp label_class, do: "mb-1.5 block text-sm font-medium text-ink"

  defp field_class do
    "block w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm text-ink shadow-xs " <>
      "placeholder:text-muted/70 transition focus:border-brand focus:outline-none " <>
      "focus:ring-3 focus:ring-brand/20"
  end

  defp field_error_class, do: "border-danger focus:border-danger focus:ring-danger/20"

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-1.5 text-sm text-danger">
      <.icon name="hero-exclamation-circle-mini" class="size-4" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex flex-wrap items-center justify-between gap-4", "pb-6"]}>
      <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm text-muted">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex flex-none items-center gap-2">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto rounded-xl border border-line bg-surface">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-line bg-surface-2 text-xs font-medium uppercase tracking-wide text-muted">
          <tr>
            <th :for={col <- @col} class="px-4 py-3">{col[:label]}</th>
            <th :if={@action != []} class="px-4 py-3">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-line"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="transition hover:bg-surface-2/60"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-4 py-3 align-middle", @row_click && "hover:cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 px-4 py-3 font-medium">
              <div class="flex justify-end gap-3 whitespace-nowrap">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-line">
      <div :for={item <- @item} class="grid gap-1 py-3 sm:grid-cols-3 sm:gap-4">
        <dt class="text-sm font-medium text-muted">{item.title}</dt>
        <dd class="text-sm text-ink sm:col-span-2">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a small coloured pill, e.g. for a status.

  ## Examples

      <.badge color="success">Approved</.badge>
  """
  attr :color, :string,
    default: "neutral",
    values: ~w(neutral brand success warning danger info)

  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    colors = %{
      "neutral" => "bg-surface-2 text-muted",
      "brand" => "bg-brand-soft text-brand",
      "success" => "bg-success-soft text-success",
      "warning" => "bg-warning-soft text-warning",
      "danger" => "bg-danger-soft text-danger",
      "info" => "bg-info-soft text-info"
    }

    assigns = assign(assigns, :color_class, Map.fetch!(colors, assigns.color))

    ~H"""
    <span
      class={[
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium",
        @color_class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders a bordered surface for grouping content.

  ## Examples

      <.card>
        <:title>Location</:title>
        Some content
      </.card>
  """
  attr :class, :any, default: nil
  attr :rest, :global
  slot :title
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <section
      class={["rounded-2xl border border-line bg-surface p-5 shadow-xs sm:p-6", @class]}
      {@rest}
    >
      <h2 :if={@title != []} class="mb-4 text-base font-semibold text-ink">
        {render_slot(@title)}
      </h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  Renders a modal dialog.

  The modal is shown when it is first rendered with `show`, or by calling
  `show_modal("my-modal")` from a `phx-click`. Use `on_cancel` to decide what
  happens when the visitor closes it (by default it just hides).

  ## Examples

      <.modal id="confirm-modal" show on_cancel={JS.patch(~p"/admin")}>
        This is a modal.
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :title
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="fixed inset-0 bg-black/40 backdrop-blur-xs transition-opacity" />
      <div
        class="fixed inset-0 overflow-y-auto"
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class="relative w-full max-w-lg rounded-2xl border border-line bg-surface p-6 shadow-xl"
          >
            <button
              type="button"
              phx-click={JS.exec("data-cancel", to: "##{@id}")}
              class="absolute top-4 right-4 cursor-pointer rounded-md p-1 text-muted transition hover:bg-surface-2 hover:text-ink"
              aria-label={gettext("close")}
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
            <h2 :if={@title != []} id={"#{@id}-title"} class="mb-4 pr-8 text-lg font-semibold">
              {render_slot(@title)}
            </h2>
            <div id={"#{@id}-content"}>{render_slot(@inner_block)}</div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(WayfinderWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(WayfinderWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end

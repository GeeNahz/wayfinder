defmodule WayfinderWeb.ChurchFormComponents do
  @moduledoc """
  The church form sections, shared by public registration, the manage link
  page and the admin edit page.

  The LiveView using `church_fields/1` must handle these events:

    * `"geocode"` - the "Find on map" button was pressed
    * `"pick_place"` - a search result was picked (`%{"index" => "0"}`)
    * `"pin_moved"` - the map pin was placed/dragged (`%{"lat" => .., "lng" => ..}`)

  plus the usual `phx-change` event of the surrounding `<.form>`, which also
  handles adding/removing activity rows.
  """
  use WayfinderWeb, :html

  alias Wayfinder.Directory.Activity

  attr :form, Phoenix.HTML.Form, required: true
  attr :denomination_options, :list, required: true, doc: "`[{name, id}]` pairs"
  attr :places, :list, default: [], doc: "geocoding results to choose from"
  attr :geocode_error, :string, default: nil

  def church_fields(assigns) do
    ~H"""
    <div class="space-y-6">
      <.details_section form={@form} denomination_options={@denomination_options} />
      <.location_section form={@form} places={@places} geocode_error={@geocode_error} />
      <.activities_section form={@form} />
    </div>
    """
  end

  ## About the church

  attr :form, Phoenix.HTML.Form, required: true
  attr :denomination_options, :list, required: true

  defp details_section(assigns) do
    ~H"""
    <.card id="church-details-section">
      <:title>About the church</:title>
      <.input field={@form[:name]} label="Church name" placeholder="e.g. Grace Chapel" required />

      <div class="grid gap-x-4 sm:grid-cols-2">
        <.input
          field={@form[:denomination_id]}
          type="select"
          label="Denomination"
          prompt="Choose a denomination"
          options={@denomination_options}
        />
        <.input
          field={@form[:requested_denomination]}
          label="Not listed? Type its name"
          placeholder="We'll ask an admin to add it"
        />
      </div>

      <.input
        field={@form[:description]}
        type="textarea"
        label="Short description (optional)"
        placeholder="A sentence or two about your church"
        rows="3"
      />

      <div class="grid gap-x-4 sm:grid-cols-2">
        <.input field={@form[:phone]} type="tel" label="Phone (optional)" />
        <.input
          field={@form[:website]}
          label="Website (optional)"
          placeholder="gracechapel.org"
        />
      </div>
    </.card>
    """
  end

  ## Location

  attr :form, Phoenix.HTML.Form, required: true
  attr :places, :list, required: true
  attr :geocode_error, :string, default: nil

  defp location_section(assigns) do
    ~H"""
    <.card id="church-location-section">
      <:title>Location</:title>
      <.input field={@form[:address_line1]} label="Street address" required />
      <.input field={@form[:address_line2]} label="Address line 2 (optional)" />

      <div class="grid gap-x-4 sm:grid-cols-2">
        <.input field={@form[:city]} label="City / town" required />
        <.input field={@form[:region]} label="State / region (optional)" />
        <.input field={@form[:postal_code]} label="Postal code (optional)" />
        <.input field={@form[:country]} label="Country" required />
      </div>

      <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
        <p class="text-sm text-muted">
          Find the address, then drag the pin to the exact spot (or click the map).
        </p>
        <.button
          type="button"
          id="geocode-button"
          phx-click="geocode"
          phx-disable-with="Searching..."
          size="sm"
        >
          <.icon name="hero-magnifying-glass-mini" class="size-4" /> Find on map
        </.button>
      </div>

      <p :if={@geocode_error} id="geocode-error" class="mb-3 text-sm text-danger">
        {@geocode_error}
      </p>

      <ul
        :if={@places != []}
        id="geocode-results"
        class="mb-3 divide-y divide-line overflow-hidden rounded-xl border border-line"
      >
        <li :for={{place, index} <- Enum.with_index(@places)}>
          <button
            type="button"
            id={"place-#{index}"}
            phx-click="pick_place"
            phx-value-index={index}
            class="flex w-full cursor-pointer items-start gap-2 px-4 py-3 text-left text-sm transition hover:bg-surface-2"
          >
            <.icon name="hero-map-pin" class="mt-0.5 size-4 shrink-0 text-brand" />
            {place.label}
          </button>
        </li>
      </ul>

      <div
        id="church-map-picker"
        phx-hook="MapPicker"
        phx-update="ignore"
        data-lat={@form[:latitude].value}
        data-lng={@form[:longitude].value}
        class="z-0 h-72 overflow-hidden rounded-xl border border-line"
      >
      </div>

      <.input field={@form[:latitude]} type="hidden" />
      <.input field={@form[:longitude]} type="hidden" />

      <p
        :if={@form[:latitude].errors != [] or @form[:longitude].errors != []}
        id="location-error"
        class="mt-2 flex items-center gap-1.5 text-sm text-danger"
      >
        <.icon name="hero-exclamation-circle-mini" class="size-4" />
        Place the church on the map: use "Find on map" or click the map.
      </p>
    </.card>
    """
  end

  ## Weekly activities

  attr :form, Phoenix.HTML.Form, required: true

  defp activities_section(assigns) do
    ~H"""
    <.card id="church-activities-section">
      <:title>Weekly activities</:title>
      <p class="-mt-2 mb-4 text-sm text-muted">
        Services, Bible studies, prayer meetings... Pick every day an activity happens.
        Activities can overlap.
      </p>

      <div id="activity-rows" class="space-y-4">
        <%!-- inputs_for renders one block per activity. The hidden "sort"
             input and the "drop" button let Ecto add/remove rows
             (see cast_assoc's :sort_param and :drop_param in Church). --%>
        <.inputs_for :let={activity} field={@form[:activities]}>
          <div
            id={"activity-#{activity.index}"}
            class="rounded-xl border border-line bg-surface-2/50 p-4"
          >
            <input
              type="hidden"
              name={@form[:activities_sort].name <> "[]"}
              value={activity.index}
            />

            <div class="flex items-start gap-3">
              <div class="flex-1">
                <.input field={activity[:name]} label="Activity" placeholder="e.g. Sunday Service" />
              </div>
              <button
                type="button"
                id={"remove-activity-#{activity.index}"}
                name={@form[:activities_drop].name <> "[]"}
                value={activity.index}
                phx-click={JS.dispatch("change")}
                class="mt-7 cursor-pointer rounded-lg p-2 text-muted transition hover:bg-danger-soft hover:text-danger"
                aria-label="Remove activity"
              >
                <.icon name="hero-trash" class="size-5" />
              </button>
            </div>

            <.day_picker field={activity[:days]} />

            <div class="grid grid-cols-2 gap-x-4">
              <.input field={activity[:starts_at]} type="time" label="Starts" />
              <.input field={activity[:ends_at]} type="time" label="Ends (optional)" />
            </div>

            <.input
              field={activity[:description]}
              label="Note (optional)"
              placeholder="e.g. English service, youth only"
            />
          </div>
        </.inputs_for>
      </div>

      <%!-- An empty "drop" value is always sent, so removing the last row works --%>
      <input type="hidden" name={@form[:activities_drop].name <> "[]"} />

      <.button
        type="button"
        id="add-activity"
        name={@form[:activities_sort].name <> "[]"}
        value="new"
        phx-click={JS.dispatch("change")}
        class="mt-4"
      >
        <.icon name="hero-plus-mini" class="size-4" /> Add activity
      </.button>
    </.card>
    """
  end

  # Seven toggleable day "pills" backed by checkboxes named `...[days][]`.
  attr :field, Phoenix.HTML.FormField, required: true

  defp day_picker(assigns) do
    selected = assigns.field.value |> List.wrap() |> Enum.map(&to_string/1)
    errors = if used_input?(assigns.field), do: assigns.field.errors, else: []

    assigns =
      assigns
      |> assign(:selected, selected)
      |> assign(:errors, Enum.map(errors, &translate_error/1))

    ~H"""
    <fieldset class="mb-4">
      <legend class="mb-1.5 text-sm font-medium text-ink">Days</legend>
      <%!-- Sent even when no box is ticked, so un-ticking everything works --%>
      <input type="hidden" name={@field.name <> "[]"} value="" />
      <div class="flex flex-wrap gap-2">
        <label
          :for={{day, name} <- Activity.weekdays()}
          class={[
            "cursor-pointer select-none rounded-full border px-3 py-1.5 text-xs font-medium transition",
            "border-line bg-surface text-muted hover:border-brand/50",
            "has-[:checked]:border-brand has-[:checked]:bg-brand has-[:checked]:text-on-brand",
            "has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-brand"
          ]}
        >
          <input
            type="checkbox"
            name={@field.name <> "[]"}
            value={day}
            checked={to_string(day) in @selected}
            class="sr-only"
          />
          {String.slice(name, 0, 3)}
        </label>
      </div>
      <p :for={msg <- @errors} class="mt-1.5 text-sm text-danger">{msg}</p>
    </fieldset>
    """
  end
end

# Neubrutalist Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign Greenlight's entire UI from generic Phoenix/daisyUI to a dark neubrutalist aesthetic with neon green accents, thick borders, offset shadows, and monospace typography.

**Architecture:** Strip daisyUI, replace with custom CSS variables and raw Tailwind classes. Dark mode only (no theme toggle). All 12 files touched — CSS foundation first, then layout shell, core components, LiveViews, and finally Svelte DAG components.

**Tech Stack:** Phoenix 1.8, LiveView 1.1, Tailwind CSS v4, Svelte 5 (via LiveSvelte), @xyflow/svelte

---

### Task 1: Strip daisyUI and set up neubrutalist CSS foundation

**Files:**
- Modify: `assets/css/app.css`

**Step 1: Replace app.css with neubrutalist foundation**

Replace the entire `assets/css/app.css` with:

```css
/* See the Tailwind configuration guide for advanced usage
   https://tailwindcss.com/docs/configuration */

@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/greenlight_web";
@source "../svelte";

/* A Tailwind plugin that makes "hero-#{ICON}" classes available.
   The heroicons installation itself is managed by your mix.exs */
@plugin "../vendor/heroicons";

/* Add variants based on LiveView classes */
@custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
@custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
@custom-variant phx-change-loading (.phx-change-loading&, .phx-change-loading &);

/* Make LiveView wrapper divs transparent for layout */
[data-phx-session], [data-phx-teleported-src] { display: contents }

/* ═══════════════════════════════════════════════════
   GREENLIGHT NEUBRUTALIST DESIGN SYSTEM
   Dark mode only. Neon green accents. Thick borders.
   ═══════════════════════════════════════════════════ */

:root {
  --gl-bg-primary: #0a0a0a;
  --gl-bg-surface: #141414;
  --gl-bg-raised: #1a1a1a;
  --gl-border: #333333;
  --gl-border-strong: #555555;
  --gl-accent: #00ff6a;
  --gl-accent-dim: #00cc55;
  --gl-accent-secondary: #4dff91;
  --gl-text-primary: #ffffff;
  --gl-text-body: #e5e5e5;
  --gl-text-muted: #888888;
  --gl-status-success: #00ff6a;
  --gl-status-error: #ff3333;
  --gl-status-warning: #ffb800;
  --gl-status-pending: #888888;
  --gl-font-mono: ui-monospace, 'Cascadia Code', 'JetBrains Mono', 'Fira Code', monospace;
  --gl-shadow: 4px 4px 0px var(--gl-accent);
  --gl-shadow-hover: 6px 6px 0px var(--gl-accent);
  --gl-shadow-muted: 4px 4px 0px var(--gl-border);
}

html {
  background-color: var(--gl-bg-primary);
  color: var(--gl-text-body);
  font-family: var(--gl-font-mono);
}

body {
  background-color: var(--gl-bg-primary);
  min-height: 100vh;
}

/* Neubrutalist card base */
.nb-card {
  background: var(--gl-bg-raised);
  border: 2px solid var(--gl-border);
  box-shadow: var(--gl-shadow);
  transition: transform 150ms ease, box-shadow 150ms ease;
}

.nb-card:hover {
  transform: translate(-2px, -2px);
  box-shadow: var(--gl-shadow-hover);
}

/* Neubrutalist card with muted (non-accent) shadow */
.nb-card-muted {
  background: var(--gl-bg-raised);
  border: 2px solid var(--gl-border);
  box-shadow: var(--gl-shadow-muted);
  transition: transform 150ms ease, box-shadow 150ms ease;
}

.nb-card-muted:hover {
  transform: translate(-2px, -2px);
  box-shadow: 6px 6px 0px var(--gl-border-strong);
}

/* Neubrutalist button press effect */
.nb-btn {
  border: 2px solid var(--gl-accent);
  box-shadow: 3px 3px 0px var(--gl-accent);
  transition: transform 100ms ease, box-shadow 100ms ease;
}

.nb-btn:active {
  transform: translate(3px, 3px);
  box-shadow: 0 0 0 var(--gl-accent);
}

/* Status left-border accents for cards */
.nb-status-success { border-left: 4px solid var(--gl-status-success); }
.nb-status-error { border-left: 4px solid var(--gl-status-error); }
.nb-status-warning { border-left: 4px solid var(--gl-status-warning); }
.nb-status-pending { border-left: 4px solid var(--gl-status-pending); }

/* Scrollbar styling for dark theme */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: var(--gl-bg-primary); }
::-webkit-scrollbar-thumb { background: var(--gl-border); }
::-webkit-scrollbar-thumb:hover { background: var(--gl-border-strong); }

/* Selection color */
::selection {
  background: var(--gl-accent);
  color: var(--gl-bg-primary);
}
```

**Step 2: Verify CSS compiles**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix assets.build`
Expected: Build succeeds (warnings about unused daisyUI classes are ok — we'll fix those in subsequent tasks)

**Step 3: Commit**

```bash
git add assets/css/app.css
git commit -m "feat: strip daisyUI and add neubrutalist design system CSS"
```

---

### Task 2: Simplify root layout (remove theme toggle)

**Files:**
- Modify: `lib/greenlight_web/components/layouts/root.html.heex`

**Step 1: Replace root layout**

Replace the entire file with:

```heex
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title default="Greenlight">
      {assigns[:page_title]}
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
    </script>
  </head>
  <body>
    {@inner_content}
  </body>
</html>
```

Key changes:
- Removed theme toggle JavaScript entirely
- Removed ` · Phoenix Framework` suffix from title
- Removed `data-theme` attribute handling

**Step 2: Commit**

```bash
git add lib/greenlight_web/components/layouts/root.html.heex
git commit -m "feat: simplify root layout, remove theme toggle"
```

---

### Task 3: Redesign app layout shell and remove theme toggle component

**Files:**
- Modify: `lib/greenlight_web/components/layouts.ex`

**Step 1: Replace layouts.ex**

Replace the entire `app` function and remove `theme_toggle`:

```elixir
defmodule GreenlightWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GreenlightWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders your app layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current scope"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="w-full border-b-[3px] border-[var(--gl-accent)]" style="background: var(--gl-bg-surface);">
      <nav class="max-w-7xl mx-auto px-6 sm:px-8 py-4 flex items-center justify-between">
        <a href="/" class="flex items-center gap-3 group">
          <span class="w-3 h-3 bg-[var(--gl-accent)] rounded-full shadow-[0_0_8px_var(--gl-accent)]" />
          <span class="text-xl font-bold tracking-wider text-white" style="font-family: var(--gl-font-mono);">
            GREENLIGHT
          </span>
        </a>
        <div class="flex items-center gap-4">
          <span class="text-xs text-[var(--gl-text-muted)]" style="font-family: var(--gl-font-mono);">
            v{Application.spec(:greenlight, :vsn)}
          </span>
        </div>
      </nav>
    </header>

    <main class="px-6 sm:px-8 py-8">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
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
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
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
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
```

Key changes:
- Removed `theme_toggle` component entirely
- Navbar: dark surface bg, 3px green bottom border, "GREENLIGHT" monospace logotype with glowing green dot
- Shows app version (not Phoenix version)
- Removed Phoenix demo links
- Content area: generous padding, no max-width constraint (each page sets its own)

**Step 2: Verify compilation**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix compile --warnings-as-errors`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/greenlight_web/components/layouts.ex
git commit -m "feat: redesign app shell with neubrutalist navbar"
```

---

### Task 4: Restyle core components (flash, button, input, table)

**Files:**
- Modify: `lib/greenlight_web/components/core_components.ex`

**Step 1: Replace core_components.ex**

Replace the entire file. Key changes: remove all daisyUI classes (`btn`, `alert`, `toast`, `select`, `input`, `textarea`, `checkbox`, `table`, `table-zebra`, `list`, `list-row`, `list-col-grow`, `fieldset`, `btn-primary`, `btn-soft`, `alert-info`, `alert-error`, `select-error`, `textarea-error`, `input-error`), replace with raw Tailwind + CSS variable classes. Here is the full replacement:

```elixir
defmodule GreenlightWeb.CoreComponents do
  @moduledoc """
  Provides core UI components styled with Greenlight's neubrutalist design system.
  """
  use Phoenix.Component
  use Gettext, backend: GreenlightWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.
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
        "w-80 sm:w-96 p-4 border-2 text-sm",
        "font-[var(--gl-font-mono)]",
        @kind == :info && "bg-[var(--gl-bg-raised)] border-[var(--gl-accent)] text-[var(--gl-accent)] border-l-4",
        @kind == :error && "bg-[var(--gl-bg-raised)] border-[var(--gl-status-error)] text-[var(--gl-status-error)] border-l-4"
      ]}>
        <div class="flex items-start gap-3">
          <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
          <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
          <div class="flex-1">
            <p :if={@title} class="font-bold uppercase text-xs tracking-wider mb-1">{@title}</p>
            <p>{msg}</p>
          </div>
          <button type="button" class="group cursor-pointer" aria-label={gettext("close")}>
            <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-100" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary), default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign_new(assigns, :class, fn ->
        base = "inline-flex items-center gap-2 px-4 py-2 text-sm font-bold uppercase tracking-wider cursor-pointer transition-all duration-100"
        variant =
          case assigns[:variant] do
            "primary" ->
              "bg-[var(--gl-accent)] text-[var(--gl-bg-primary)] border-2 border-[var(--gl-accent)] nb-btn hover:bg-[var(--gl-accent-secondary)]"
            _ ->
              "bg-[var(--gl-bg-raised)] text-[var(--gl-text-body)] border-2 border-[var(--gl-border)] nb-btn hover:border-[var(--gl-accent)] hover:text-[var(--gl-accent)]"
          end
        [base, variant]
      end)

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
    <div class="mb-3">
      <label class="flex items-center gap-2 cursor-pointer">
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
          class={@class || "w-5 h-5 accent-[var(--gl-accent)] bg-[var(--gl-bg-raised)] border-2 border-[var(--gl-border)]"}
          {@rest}
        />
        <span class="text-sm text-[var(--gl-text-body)] uppercase tracking-wider">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-3">
      <label>
        <span :if={@label} class="block text-xs text-[var(--gl-text-muted)] uppercase tracking-wider mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[
            @class || "w-full px-3 py-2 bg-[var(--gl-bg-raised)] text-[var(--gl-text-body)] border-2 border-[var(--gl-border)] focus:border-[var(--gl-accent)] focus:outline-none font-[var(--gl-font-mono)] text-sm",
            @errors != [] && (@error_class || "border-[var(--gl-status-error)]")
          ]}
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
    <div class="mb-3">
      <label>
        <span :if={@label} class="block text-xs text-[var(--gl-text-muted)] uppercase tracking-wider mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full px-3 py-2 bg-[var(--gl-bg-raised)] text-[var(--gl-text-body)] border-2 border-[var(--gl-border)] focus:border-[var(--gl-accent)] focus:outline-none font-[var(--gl-font-mono)] text-sm",
            @errors != [] && (@error_class || "border-[var(--gl-status-error)]")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="mb-3">
      <label>
        <span :if={@label} class="block text-xs text-[var(--gl-text-muted)] uppercase tracking-wider mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full px-3 py-2 bg-[var(--gl-bg-raised)] text-[var(--gl-text-body)] border-2 border-[var(--gl-border)] focus:border-[var(--gl-accent)] focus:outline-none font-[var(--gl-font-mono)] text-sm",
            @errors != [] && (@error_class || "border-[var(--gl-status-error)]")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-[var(--gl-status-error)]">
      <.icon name="hero-exclamation-circle" class="size-5" />
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
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-2xl font-bold uppercase tracking-wider text-white">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-[var(--gl-text-muted)] mt-1">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.
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
    <table class="w-full text-sm">
      <thead>
        <tr class="border-b-2 border-[var(--gl-border)]">
          <th :for={col <- @col} class="text-left py-3 px-4 text-xs uppercase tracking-wider text-[var(--gl-text-muted)] font-bold">
            {col[:label]}
          </th>
          <th :if={@action != []} class="py-3 px-4">
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr
          :for={row <- @rows}
          id={@row_id && @row_id.(row)}
          class="border-b border-[var(--gl-border)] hover:bg-[var(--gl-bg-raised)] transition-colors"
        >
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={["py-3 px-4 text-[var(--gl-text-body)]", @row_click && "hover:cursor-pointer"]}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 py-3 px-4 font-bold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="divide-y divide-[var(--gl-border)]">
      <li :for={item <- @item} class="py-3">
        <div>
          <div class="font-bold text-xs uppercase tracking-wider text-[var(--gl-text-muted)]">{item.title}</div>
          <div class="text-[var(--gl-text-body)] mt-1">{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).
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

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(GreenlightWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(GreenlightWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
```

**Step 2: Verify compilation**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix compile --warnings-as-errors`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/greenlight_web/components/core_components.ex
git commit -m "feat: restyle core components with neubrutalist design"
```

---

### Task 5: Redesign Dashboard LiveView

**Files:**
- Modify: `lib/greenlight_web/live/dashboard_live.ex`

**Step 1: Replace the render function**

Replace only the `render/1` function in `dashboard_live.ex`. Keep `mount`, `handle_info`, and `handle_event` unchanged.

```elixir
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-6xl mx-auto">
        <h1 class="text-4xl font-bold uppercase tracking-wider text-white mb-10">
          Dashboard
        </h1>

        <section :if={@bookmarked_repos != []} class="mb-12">
          <h2 class="text-lg font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-6 flex items-center gap-2">
            <span class="w-2 h-2 bg-[var(--gl-accent)]" />
            Bookmarked Repos
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            <.link
              :for={repo <- @bookmarked_repos}
              navigate={"/repos/#{repo}"}
              class="nb-card block p-5"
            >
              <span class="text-base font-bold text-white" style="font-family: var(--gl-font-mono);">
                {repo}
              </span>
              <span class="block text-xs text-[var(--gl-text-muted)] mt-2 uppercase tracking-wider">
                View pipelines &rarr;
              </span>
            </.link>
          </div>
        </section>

        <section :if={@followed_orgs != []} class="mb-12">
          <h2 class="text-lg font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-6 flex items-center gap-2">
            <span class="w-2 h-2 bg-[var(--gl-accent)]" />
            Organizations
          </h2>
          <div :for={org <- @followed_orgs} class="mb-4">
            <button
              phx-click="toggle_org"
              phx-value-org={org}
              class="flex items-center gap-3 w-full text-left p-4 border-2 border-[var(--gl-border)] border-l-4 border-l-[var(--gl-accent)] bg-[var(--gl-bg-raised)] hover:bg-[var(--gl-bg-surface)] transition-colors cursor-pointer"
            >
              <span class="text-sm text-[var(--gl-accent)]" style="font-family: var(--gl-font-mono);">
                {if MapSet.member?(@expanded_orgs, org), do: "[-]", else: "[+]"}
              </span>
              <span class="font-bold text-white" style="font-family: var(--gl-font-mono);">{org}</span>
              <span class="text-sm text-[var(--gl-text-muted)] ml-auto" style="font-family: var(--gl-font-mono);">
                {length(Map.get(@org_repos, org, []))} repos
              </span>
            </button>

            <div :if={MapSet.member?(@expanded_orgs, org)} class="mt-2 ml-6 space-y-2">
              <.link
                :for={repo <- Map.get(@org_repos, org, [])}
                navigate={"/repos/#{repo}"}
                class="nb-card-muted block p-3"
              >
                <span class="text-sm text-[var(--gl-text-body)]" style="font-family: var(--gl-font-mono);">
                  {repo}
                </span>
              </.link>
            </div>
          </div>
        </section>

        <div
          :if={@bookmarked_repos == [] and @followed_orgs == []}
          class="text-center py-20"
        >
          <div class="nb-card inline-block p-8 text-left max-w-md">
            <p class="text-xl font-bold text-white uppercase tracking-wider mb-4">No repos configured</p>
            <p class="text-sm text-[var(--gl-text-muted)] mb-3">Set these environment variables:</p>
            <code class="block p-3 bg-[var(--gl-bg-primary)] border border-[var(--gl-border)] text-[var(--gl-accent)] text-xs mb-2" style="font-family: var(--gl-font-mono);">
              GREENLIGHT_BOOKMARKED_REPOS
            </code>
            <code class="block p-3 bg-[var(--gl-bg-primary)] border border-[var(--gl-border)] text-[var(--gl-accent)] text-xs" style="font-family: var(--gl-font-mono);">
              GREENLIGHT_FOLLOWED_ORGS
            </code>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
```

**Step 2: Verify compilation**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix compile --warnings-as-errors`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/greenlight_web/live/dashboard_live.ex
git commit -m "feat: redesign dashboard with neubrutalist cards and layout"
```

---

### Task 6: Redesign Repo LiveView

**Files:**
- Modify: `lib/greenlight_web/live/repo_live.ex`

**Step 1: Replace the render function and status_badge_class helper**

Keep `mount`, `handle_info`, and `handle_event` unchanged. Replace `render/1` and `status_badge_class/2`:

```elixir
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-5xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/dashboard"}
            class="text-sm text-[var(--gl-text-muted)] hover:text-[var(--gl-accent)] transition-colors uppercase tracking-wider"
            style="font-family: var(--gl-font-mono);"
          >
            &larr; Dashboard
          </.link>
          <h1 class="text-3xl font-bold mt-3 text-white" style="font-family: var(--gl-font-mono);">
            {@owner}<span class="text-[var(--gl-text-muted)]">/</span>{@repo}
          </h1>
        </div>

        <div class="flex border-b-[3px] border-[var(--gl-border)] mb-8">
          <button
            :for={tab <- ["pulls", "branches", "releases", "commits"]}
            phx-click="switch_tab"
            phx-value-tab={tab}
            class={[
              "px-5 py-3 text-sm font-bold uppercase tracking-wider border-b-[3px] -mb-[3px] transition-colors cursor-pointer",
              if(@active_tab == tab,
                do: "border-[var(--gl-accent)] text-[var(--gl-accent)]",
                else: "border-transparent text-[var(--gl-text-muted)] hover:text-white"
              )
            ]}
            style="font-family: var(--gl-font-mono);"
          >
            {tab}
          </button>
        </div>

        <div :if={@loading} class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider">
          <.icon name="hero-arrow-path" class="size-5 motion-safe:animate-spin inline mr-2" />
          Loading...
        </div>

        <div :if={!@loading}>
          <div :if={@active_tab == "commits"} class="space-y-3">
            <.link
              :for={run <- @commits}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{run.head_sha}"}
              class={["nb-card block p-4", status_border_class(run.status, run.conclusion)]}
            >
              <div class="flex items-center justify-between">
                <span class="font-bold text-white text-sm" style="font-family: var(--gl-font-mono);">
                  {String.slice(run.head_sha, 0, 7)}
                </span>
                <span class={[
                  "text-xs px-3 py-1 font-bold uppercase tracking-wider border",
                  status_badge_class(run.status, run.conclusion)
                ]}
                style="font-family: var(--gl-font-mono);"
                >
                  {run.conclusion || run.status}
                </span>
              </div>
              <div class="text-sm text-[var(--gl-text-muted)] mt-2" style="font-family: var(--gl-font-mono);">
                {run.name}
              </div>
            </.link>
            <div :if={@commits == []} class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider">
              No recent workflow runs
            </div>
          </div>

          <div :if={@active_tab == "pulls"} class="space-y-3">
            <.link
              :for={pr <- @pulls}
              navigate={~p"/repos/#{@owner}/#{@repo}/pull/#{pr.number}"}
              class="nb-card block p-4"
            >
              <div class="flex items-center gap-3">
                <span class="text-[var(--gl-text-muted)] text-sm" style="font-family: var(--gl-font-mono);">
                  #{pr.number}
                </span>
                <span class="font-bold text-white text-sm">{pr.title}</span>
              </div>
            </.link>
            <div :if={@pulls == []} class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider">
              No open pull requests
            </div>
          </div>

          <div :if={@active_tab == "branches"} class="space-y-3">
            <.link
              :for={branch <- @branches}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{branch.sha}"}
              class="nb-card block p-4"
            >
              <span class="font-bold text-white text-sm" style="font-family: var(--gl-font-mono);">
                {branch.name}
              </span>
            </.link>
            <div :if={@branches == []} class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider">
              No branches
            </div>
          </div>

          <div :if={@active_tab == "releases"} class="space-y-3">
            <.link
              :for={release <- @releases}
              navigate={~p"/repos/#{@owner}/#{@repo}/release/#{release.tag_name}"}
              class="nb-card block p-4"
            >
              <div class="flex items-center gap-3">
                <span class="font-bold text-white text-sm" style="font-family: var(--gl-font-mono);">
                  {release.tag_name}
                </span>
                <span :if={release.name} class="text-sm text-[var(--gl-text-muted)]">{release.name}</span>
              </div>
            </.link>
            <div :if={@releases == []} class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider">
              No releases
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge_class(status, conclusion) do
    case conclusion || status do
      s when s in [:success, "success"] ->
        "bg-[var(--gl-status-success)]/10 text-[var(--gl-status-success)] border-[var(--gl-status-success)]"

      s when s in [:failure, "failure"] ->
        "bg-[var(--gl-status-error)]/10 text-[var(--gl-status-error)] border-[var(--gl-status-error)]"

      s when s in [:in_progress, "in_progress"] ->
        "bg-[var(--gl-status-warning)]/10 text-[var(--gl-status-warning)] border-[var(--gl-status-warning)]"

      _ ->
        "bg-[var(--gl-border)]/20 text-[var(--gl-text-muted)] border-[var(--gl-border)]"
    end
  end

  defp status_border_class(status, conclusion) do
    case conclusion || status do
      s when s in [:success, "success"] -> "nb-status-success"
      s when s in [:failure, "failure"] -> "nb-status-error"
      s when s in [:in_progress, "in_progress"] -> "nb-status-warning"
      _ -> "nb-status-pending"
    end
  end
```

**Step 2: Verify compilation**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix compile --warnings-as-errors`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/greenlight_web/live/repo_live.ex
git commit -m "feat: redesign repo browser with neubrutalist tabs and cards"
```

---

### Task 7: Redesign Pipeline LiveView

**Files:**
- Modify: `lib/greenlight_web/live/pipeline_live.ex`

**Step 1: Replace the render function**

Keep all mount, handle_info, handle_event, and helper functions unchanged. Replace only `render/1`:

```elixir
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-7xl mx-auto">
        <div class="mb-8">
          <div class="flex items-center gap-2 text-sm text-[var(--gl-text-muted)] mb-2" style="font-family: var(--gl-font-mono);">
            <.link
              navigate={~p"/repos/#{@owner}/#{@repo}"}
              class="hover:text-[var(--gl-accent)] transition-colors uppercase tracking-wider"
            >
              {@owner}/{@repo}
            </.link>
            <span class="text-[var(--gl-border)]">/</span>
            <span class="text-[var(--gl-accent)]">{String.slice(@sha, 0, 7)}</span>
          </div>
          <h1 class="text-3xl font-bold text-white uppercase tracking-wider">
            Pipeline
            <span class="text-base font-bold text-[var(--gl-text-muted)] ml-2" style="font-family: var(--gl-font-mono);">
              [{@view_level}]
            </span>
          </h1>
        </div>

        <div class="nb-card-muted p-1">
          <.svelte
            name="DagViewer"
            props={
              %{
                nodes: @nodes,
                edges: @edges,
                view_level: @view_level
              }
            }
            socket={@socket}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
```

**Step 2: Verify compilation**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix compile --warnings-as-errors`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add lib/greenlight_web/live/pipeline_live.ex
git commit -m "feat: redesign pipeline view with neubrutalist framing"
```

---

### Task 8: Restyle Svelte StatusBadge and ProgressBar components

**Files:**
- Modify: `assets/svelte/components/StatusBadge.svelte`
- Modify: `assets/svelte/components/ProgressBar.svelte`

**Step 1: Replace StatusBadge.svelte**

```svelte
<script>
  let { status = "queued", conclusion = null } = $props()

  const displayStatus = $derived(conclusion || status)
  const colorStyles = $derived({
    queued: { bg: "var(--gl-status-pending)", text: "var(--gl-text-body)" },
    in_progress: { bg: "var(--gl-status-warning)", text: "var(--gl-bg-primary)" },
    success: { bg: "var(--gl-status-success)", text: "var(--gl-bg-primary)" },
    failure: { bg: "var(--gl-status-error)", text: "var(--gl-bg-primary)" },
    cancelled: { bg: "var(--gl-status-pending)", text: "var(--gl-text-body)" },
    skipped: { bg: "var(--gl-border)", text: "var(--gl-text-muted)" }
  }[displayStatus] || { bg: "var(--gl-status-pending)", text: "var(--gl-text-body)" })
</script>

<span
  class="inline-flex items-center gap-1.5 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider border"
  style="background: {colorStyles.bg}; color: {colorStyles.text}; border-color: {colorStyles.bg}; font-family: var(--gl-font-mono);"
  class:animate-pulse={displayStatus === 'in_progress'}
>
  {#if displayStatus === 'cancelled'}
    <span class="line-through">{displayStatus}</span>
  {:else}
    {displayStatus}
  {/if}
</span>
```

**Step 2: Replace ProgressBar.svelte**

```svelte
<script>
  let { completed = 0, total = 0 } = $props()

  const percent = $derived(total > 0 ? Math.round((completed / total) * 100) : 0)
</script>

<div class="w-full h-2 border border-[var(--gl-border)]" style="background: var(--gl-bg-primary);">
  <div
    class="h-full transition-all duration-500"
    style="width: {percent}%; background: {percent === 100 ? 'var(--gl-status-success)' : 'var(--gl-status-warning)'};"
  ></div>
</div>
```

**Step 3: Commit**

```bash
git add assets/svelte/components/StatusBadge.svelte assets/svelte/components/ProgressBar.svelte
git commit -m "feat: restyle StatusBadge and ProgressBar with neubrutalist design"
```

---

### Task 9: Restyle Svelte DAG node components

**Files:**
- Modify: `assets/svelte/nodes/WorkflowNode.svelte`
- Modify: `assets/svelte/nodes/JobNode.svelte`

**Step 1: Replace WorkflowNode.svelte**

```svelte
<script>
  import { Handle, Position } from '@xyflow/svelte';
  import StatusBadge from '../components/StatusBadge.svelte';

  let { data } = $props();

  function formatElapsed(seconds) {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  }

  function openGitHub(e) {
    e.stopPropagation();
    window.open(data.html_url, '_blank');
  }

  const borderColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );

  const shadowColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );
</script>

<Handle type="target" position={Position.Top} />

<div
  class="px-4 py-3 min-w-[220px] cursor-pointer transition-all duration-150 hover:-translate-x-0.5 hover:-translate-y-0.5"
  style="background: var(--gl-bg-raised); border: 2px solid {borderColor}; border-left: 4px solid {borderColor}; box-shadow: 3px 3px 0px {shadowColor}; font-family: var(--gl-font-mono);"
>
  <div class="flex items-center justify-between gap-2 mb-2">
    <span class="font-bold text-sm truncate text-white">{data.name}</span>
    <button onclick={openGitHub} class="opacity-40 hover:opacity-100 transition-opacity text-[var(--gl-accent)]" title="View on GitHub">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
      </svg>
    </button>
  </div>
  <div class="flex items-center justify-between gap-3">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-[var(--gl-text-muted)]">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.jobs_total > 0}
    <div class="text-xs text-[var(--gl-text-muted)] mt-2">
      {data.jobs_passed}/{data.jobs_total} jobs
    </div>
  {/if}
</div>

<Handle type="source" position={Position.Bottom} />
```

**Step 2: Replace JobNode.svelte**

```svelte
<script>
  import { Handle, Position } from '@xyflow/svelte';
  import StatusBadge from '../components/StatusBadge.svelte';
  import ProgressBar from '../components/ProgressBar.svelte';

  let { data } = $props();

  function formatElapsed(seconds) {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  }

  function openGitHub(e) {
    e.stopPropagation();
    window.open(data.html_url, '_blank');
  }

  const borderColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );

  const shadowColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );
</script>

<Handle type="target" position={Position.Top} />

<div
  class="px-3 py-2 min-w-[200px] transition-all duration-150"
  style="background: var(--gl-bg-raised); border: 2px solid {borderColor}; border-left: 4px solid {borderColor}; box-shadow: 3px 3px 0px {shadowColor}; font-family: var(--gl-font-mono);"
>
  <div class="flex items-center justify-between gap-2 mb-1">
    <span class="font-bold text-xs truncate text-white">{data.name}</span>
    <button onclick={openGitHub} class="opacity-40 hover:opacity-100 transition-opacity text-[var(--gl-accent)]" title="View on GitHub">
      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
      </svg>
    </button>
  </div>
  <div class="flex items-center justify-between gap-2">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-[var(--gl-text-muted)]">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.current_step}
    <div class="text-xs text-[var(--gl-status-warning)] mt-1 truncate" title={data.current_step}>
      &triangleright; {data.current_step}
    </div>
  {/if}
  {#if data.steps_total > 0}
    <div class="mt-1.5">
      <ProgressBar completed={data.steps_completed} total={data.steps_total} />
    </div>
  {/if}
</div>

<Handle type="source" position={Position.Bottom} />
```

**Step 3: Commit**

```bash
git add assets/svelte/nodes/WorkflowNode.svelte assets/svelte/nodes/JobNode.svelte
git commit -m "feat: restyle DAG nodes with neubrutalist card design"
```

---

### Task 10: Restyle DagViewer with dark theme

**Files:**
- Modify: `assets/svelte/DagViewer.svelte`

**Step 1: Replace DagViewer.svelte**

```svelte
<script>
  import { SvelteFlow, Background, Controls, MiniMap } from '@xyflow/svelte';
  import dagre from 'dagre';
  import WorkflowNode from './nodes/WorkflowNode.svelte';
  import JobNode from './nodes/JobNode.svelte';
  import '@xyflow/svelte/dist/style.css';

  let { nodes = [], edges = [], view_level = "workflows", live } = $props();

  const nodeTypes = {
    workflow: WorkflowNode,
    job: JobNode
  };

  function getLayoutedElements(inputNodes, inputEdges, direction = 'TB') {
    const g = new dagre.graphlib.Graph();
    g.setDefaultEdgeLabel(() => ({}));
    g.setGraph({ rankdir: direction, nodesep: 60, ranksep: 90 });

    const nodeWidth = view_level === 'workflows' ? 240 : 220;
    const nodeHeight = view_level === 'workflows' ? 110 : 100;

    inputNodes.forEach(node => {
      g.setNode(node.id, { width: nodeWidth, height: nodeHeight });
    });

    inputEdges.forEach(edge => {
      g.setEdge(edge.source, edge.target);
    });

    dagre.layout(g);

    return inputNodes.map(node => {
      const pos = g.node(node.id);
      return {
        ...node,
        position: {
          x: pos.x - nodeWidth / 2,
          y: pos.y - nodeHeight / 2
        }
      };
    });
  }

  const layoutedNodes = $derived(getLayoutedElements(nodes, edges));

  const styledEdges = $derived(edges.map(edge => ({
    ...edge,
    style: `stroke: var(--gl-border-strong); stroke-width: 2px;`,
    animated: edge.animated || false
  })));

  function handleNodeClick(event) {
    const node = event.detail.node;
    if (view_level === 'workflows' && node.type === 'workflow') {
      live.pushEvent("node_clicked", { workflow_run_id: parseInt(node.id.replace("wf-", "")) });
    }
  }

  function handleBackClick() {
    live.pushEvent("back_clicked", {});
  }
</script>

<div class="w-full h-[650px] relative" style="background: var(--gl-bg-primary);">
  {#if view_level === 'jobs'}
    <button
      onclick={handleBackClick}
      class="absolute top-3 left-3 z-10 px-4 py-2 text-sm font-bold uppercase tracking-wider nb-btn cursor-pointer"
      style="background: var(--gl-bg-raised); color: var(--gl-accent); border: 2px solid var(--gl-accent); font-family: var(--gl-font-mono);"
    >
      &larr; Workflows
    </button>
  {/if}

  <SvelteFlow
    nodes={layoutedNodes}
    edges={styledEdges}
    {nodeTypes}
    fitView
    onnodeclick={handleNodeClick}
    nodesDraggable={false}
    nodesConnectable={false}
    elementsSelectable={true}
    defaultEdgeOptions={{ type: 'smoothstep' }}
    colorMode="dark"
  >
    <Background bgColor="var(--gl-bg-primary)" gap={20} color="var(--gl-border)" />
    <Controls />
    <MiniMap
      maskColor="rgba(0, 0, 0, 0.7)"
      bgColor="var(--gl-bg-surface)"
      nodeColor="var(--gl-border-strong)"
    />
  </SvelteFlow>
</div>

<style>
  :global(.svelte-flow) {
    --xy-background-color: var(--gl-bg-primary) !important;
    --xy-node-background-color: transparent !important;
    --xy-node-border-radius: 0 !important;
    --xy-edge-stroke: var(--gl-border-strong) !important;
    --xy-edge-stroke-width: 2px !important;
    --xy-minimap-background-color: var(--gl-bg-surface) !important;
    --xy-controls-button-background-color: var(--gl-bg-raised) !important;
    --xy-controls-button-color: var(--gl-text-body) !important;
    --xy-controls-button-border-color: var(--gl-border) !important;
  }
  :global(.svelte-flow .svelte-flow__controls button) {
    border: 2px solid var(--gl-border) !important;
    border-radius: 0 !important;
  }
  :global(.svelte-flow .svelte-flow__controls button:hover) {
    background: var(--gl-bg-surface) !important;
    border-color: var(--gl-accent) !important;
  }
  :global(.svelte-flow .svelte-flow__minimap) {
    border: 2px solid var(--gl-border) !important;
    border-radius: 0 !important;
  }
  :global(.svelte-flow .svelte-flow__edge-path) {
    stroke: var(--gl-border-strong) !important;
    stroke-width: 2px !important;
  }
</style>
```

**Step 2: Build and verify**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix assets.build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add assets/svelte/DagViewer.svelte
git commit -m "feat: restyle DagViewer with dark neubrutalist theme"
```

---

### Task 11: Final build verification and cleanup

**Step 1: Full build**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix precommit`
Expected: Format, compile, and tests pass. Fix any issues.

**Step 2: Manual check (if dev server is available)**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix phx.server`
Verify in browser:
- Dark background everywhere
- Green accents on navbar, cards, tabs
- Thick borders and offset shadows on cards
- Monospace typography on repo names, SHAs, status badges
- DAG viewer has dark background with styled nodes
- No remnants of daisyUI styling (no rounded cards, no light backgrounds)

**Step 3: Final commit (if any format/fix changes)**

```bash
git add -A
git commit -m "chore: format and cleanup after neubrutalist redesign"
```

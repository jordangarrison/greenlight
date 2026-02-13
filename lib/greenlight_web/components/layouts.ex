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
    <header
      class="w-full border-b-[3px] border-[var(--gl-accent)]"
      style="background: var(--gl-bg-surface);"
    >
      <nav class="max-w-7xl mx-auto px-6 sm:px-8 py-4 flex items-center justify-between">
        <a href="/" class="flex items-center gap-3 group">
          <span class="w-3 h-3 bg-[var(--gl-accent)] rounded-full shadow-[0_0_8px_var(--gl-accent)]" />
          <span
            class="text-xl font-bold tracking-wider text-white"
            style="font-family: var(--gl-font-mono);"
          >
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

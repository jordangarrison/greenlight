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
        @kind == :info &&
          "bg-[var(--gl-bg-raised)] border-[var(--gl-accent)] text-[var(--gl-accent)] border-l-4",
        @kind == :error &&
          "bg-[var(--gl-bg-raised)] border-[var(--gl-status-error)] text-[var(--gl-status-error)] border-l-4"
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
  attr :variant, :string, values: ~w(primary default), default: "default"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign_new(assigns, :class, fn ->
        base =
          "inline-flex items-center gap-2 px-4 py-2 text-sm font-bold uppercase tracking-wider cursor-pointer transition-all duration-100"

        variant =
          case assigns[:variant] do
            "primary" ->
              "bg-[var(--gl-accent)] text-[var(--gl-bg-primary)] border-2 border-[var(--gl-accent)] nb-btn hover:bg-[var(--gl-accent-secondary)]"

            _default ->
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
    |> assign_new(:name, fn ->
      if assigns.multiple, do: field.name <> "[]", else: field.name
    end)
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
          class={
            @class ||
              "w-5 h-5 accent-[var(--gl-accent)] bg-[var(--gl-bg-raised)] border-2 border-[var(--gl-border)]"
          }
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
        <span
          :if={@label}
          class="block text-xs text-[var(--gl-text-muted)] uppercase tracking-wider mb-1"
        >
          {@label}
        </span>
        <select
          id={@id}
          name={@name}
          class={[
            @class ||
              "w-full px-3 py-2 bg-[var(--gl-bg-raised)] text-[var(--gl-text-body)] border-2 border-[var(--gl-border)] focus:border-[var(--gl-accent)] focus:outline-none font-[var(--gl-font-mono)] text-sm",
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
        <span
          :if={@label}
          class="block text-xs text-[var(--gl-text-muted)] uppercase tracking-wider mb-1"
        >
          {@label}
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class ||
              "w-full px-3 py-2 bg-[var(--gl-bg-raised)] text-[var(--gl-text-body)] border-2 border-[var(--gl-border)] focus:border-[var(--gl-accent)] focus:outline-none font-[var(--gl-font-mono)] text-sm",
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
        <span
          :if={@label}
          class="block text-xs text-[var(--gl-text-muted)] uppercase tracking-wider mb-1"
        >
          {@label}
        </span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class ||
              "w-full px-3 py-2 bg-[var(--gl-bg-raised)] text-[var(--gl-text-body)] border-2 border-[var(--gl-border)] focus:border-[var(--gl-accent)] focus:outline-none font-[var(--gl-font-mono)] text-sm",
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
          <th
            :for={col <- @col}
            class="text-left py-3 px-4 text-xs uppercase tracking-wider text-[var(--gl-text-muted)] font-bold"
          >
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
          <div class="font-bold text-xs uppercase tracking-wider text-[var(--gl-text-muted)]">
            {item.title}
          </div>
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

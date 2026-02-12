defmodule GreenlightWeb.TestLive do
  use GreenlightWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, name: "Greenlight")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.svelte name="Hello" props={%{name: @name}} socket={@socket} />
    </Layouts.app>
    """
  end
end

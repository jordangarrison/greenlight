defmodule GreenlightWeb.PageController do
  use GreenlightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

defmodule Greenlight.GitHub.Actions.GetAuthenticatedUser do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(_query, _data_layer_query, _opts, _context) do
    case Client.get_authenticated_user() do
      {:ok, user} ->
        {:ok,
         [
           %Greenlight.GitHub.User{
             login: user.login,
             name: user.name,
             avatar_url: user.avatar_url
           }
         ]}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

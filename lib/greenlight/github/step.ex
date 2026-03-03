defmodule Greenlight.GitHub.Step do
  @moduledoc """
  A single step within a GitHub Actions job.
  Embedded resource — always comes as part of a Job API response.
  """

  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string, public?: true
    attribute :status, :atom, public?: true
    attribute :conclusion, :atom, public?: true
    attribute :number, :integer, public?: true
    attribute :started_at, :utc_datetime, public?: true
    attribute :completed_at, :utc_datetime, public?: true
  end
end

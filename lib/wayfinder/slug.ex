defmodule Wayfinder.Slug do
  @moduledoc """
  Turns names into URL-friendly slugs, e.g. "St. Mary's Church" => "st-marys-church".
  """

  def slugify(nil), do: ""

  def slugify(text) do
    text
    |> String.normalize(:nfd)
    # drop accents left over after normalising (é => e)
    |> String.replace(~r/[\x{0300}-\x{036f}]/u, "")
    |> String.downcase()
    |> String.replace("'", "")
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end

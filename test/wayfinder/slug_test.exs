defmodule Wayfinder.SlugTest do
  use ExUnit.Case, async: true

  alias Wayfinder.Slug

  test "slugify/1 builds URL-friendly slugs" do
    assert Slug.slugify("St. Mary's Church") == "st-marys-church"
    assert Slug.slugify("  Église   Évangélique ") == "eglise-evangelique"
    assert Slug.slugify(nil) == ""
  end
end

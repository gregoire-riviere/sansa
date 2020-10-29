defmodule SansaTest do
  use ExUnit.Case
  doctest Sansa

  test "greets the world" do
    assert Sansa.hello() == :world
  end
end

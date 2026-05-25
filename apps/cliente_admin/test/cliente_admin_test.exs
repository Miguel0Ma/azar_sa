defmodule ClienteAdminTest do
  use ExUnit.Case
  doctest ClienteAdmin

  test "greets the world" do
    assert ClienteAdmin.hello() == :world
  end
end

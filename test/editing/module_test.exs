defmodule MyApp.AccountsTest do
  use ExUnit.Case, async: true

  describe "get!/1" do
    test "returns the user" do
      assert MyApp.Accounts.get!(1).id == 1
    end

    test "raises for a missing user" do
      assert_raise ArgumentError, fn ->
        MyApp.Accounts.get!(0)
      end
    end
  end

  test "options include a timeout" do
    assert MyApp.Accounts.options()[:timeout] == 5_000
  end
end

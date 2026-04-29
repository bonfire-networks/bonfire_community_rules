defmodule Bonfire.CommunityRules.QualifierTest do
  use ExUnit.Case, async: true

  alias Bonfire.CommunityRules.Qualifier

  @valid ~w(yes no with_label with_approval)

  test "values/0 returns all four qualifier atoms" do
    assert Qualifier.values() == @valid
  end

  test "valid?/1 accepts all four values" do
    for v <- @valid, do: assert(Qualifier.valid?(v))
  end

  test "valid?/1 rejects unknown values" do
    for bad <- ["maybe", "", "YES", :no, nil] do
      refute Qualifier.valid?(bad)
    end
  end

  test "label/1 returns a non-empty string for each value" do
    for v <- @valid do
      label = Qualifier.label(v)
      assert is_binary(label) and label != ""
    end
  end

  test "options/0 returns [{value, label}] pairs for all values" do
    opts = Qualifier.options()
    assert length(opts) == 4

    for {v, label} <- opts do
      assert v in @valid
      assert is_binary(label)
    end
  end
end

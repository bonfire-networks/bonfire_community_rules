defmodule Bonfire.CommunityRules.ChangesetsTest do
  use Bonfire.CommunityRules.DataCase, async: true

  alias Bonfire.CommunityRules.Changesets
  alias Bonfire.Data.Identity.ExtraInfo

  defp base_struct(info \\ %{}) do
    %{extra_info: %ExtraInfo{info: info}}
  end

  describe "cast_rules/2" do
    test "merges rules into empty extra_info.info" do
      rules = %{"civility" => %{"be_respectful" => %{}}}
      result = Changesets.merge_rules(base_struct(), rules)
      assert get_in(result, [:extra_info, :info, "rules", "civility", "be_respectful"]) == %{}
    end

    test "preserves existing info keys like icon" do
      struct = base_struct(%{"icon" => "star"})
      rules = %{"civility" => %{"be_respectful" => %{}}}
      result = Changesets.merge_rules(struct, rules)
      assert get_in(result, [:extra_info, :info, "icon"]) == "star"
    end

    test "deep-merges rules: adds new group without removing existing" do
      struct = base_struct(%{"rules" => %{"civility" => %{"be_respectful" => %{}}}})
      rules = %{"harassment" => %{"no_bullying" => %{}}}
      result = Changesets.merge_rules(struct, rules)
      info = get_in(result, [:extra_info, :info, "rules"])
      assert Map.has_key?(info, "civility")
      assert Map.has_key?(info, "harassment")
    end

    test "sets qualifier on a rule" do
      rules = %{"civility" => %{"no_spam" => %{"qualifier" => "no"}}}
      result = Changesets.merge_rules(base_struct(), rules)

      assert get_in(result, [:extra_info, :info, "rules", "civility", "no_spam", "qualifier"]) ==
               "no"
    end

    test "rejects invalid qualifier values" do
      rules = %{"civility" => %{"no_spam" => %{"qualifier" => "maybe"}}}
      assert {:error, :invalid_qualifier} = Changesets.validate_rules(rules)
    end

    test "accepts all valid qualifier values" do
      for q <- ~w(yes no with_label with_approval) do
        rules = %{"civility" => %{"r" => %{"qualifier" => q}}}
        assert :ok = Changesets.validate_rules(rules)
      end
    end

    test "auto-increments custom rule ids within a group" do
      struct =
        base_struct(%{
          "rules" => %{
            "civility" => %{"custom" => [%{"id" => 1, "name" => "existing"}]}
          }
        })

      result = Changesets.add_custom_rule(struct, "civility", %{"name" => "new rule"})
      customs = get_in(result, [:extra_info, :info, "rules", "civility", "custom"])
      assert length(customs) == 2
      assert List.last(customs)["id"] == 2
    end

    test "auto-increments from 1 when no existing custom rules" do
      result = Changesets.add_custom_rule(base_struct(), "civility", %{"name" => "first"})
      customs = get_in(result, [:extra_info, :info, "rules", "civility", "custom"])
      assert [%{"id" => 1, "name" => "first"}] = customs
    end
  end
end

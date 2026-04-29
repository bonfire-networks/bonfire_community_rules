defmodule Bonfire.CommunityRules.RulesBuilderLiveTest do
  use Bonfire.CommunityRules.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.CommunityRules.Web.RulesBuilderLive
  alias Surface.Components.Dynamic.LiveComponent, as: StatefulComponent

  @template [
    behavior: [
      name: "Behavior",
      sections: [
        civility: [
          name: "Civility",
          rules: [
            be_respectful: %{name: "Be respectful"},
            no_spam: %{name: "No spam", has_qualifier: true}
          ]
        ]
      ]
    ]
  ]

  describe "selected_summary/4" do
    test "returns empty list when nothing is checked" do
      assert [] == RulesBuilderLive.selected_summary(%{}, %{}, %{}, @template)
    end

    test "returns checked template rules" do
      checked = %{"civility:be_respectful" => true}
      summary = RulesBuilderLive.selected_summary(checked, %{}, %{}, @template)
      assert [{"Civility", rules}] = summary
      assert Enum.any?(rules, &(&1.name == "Be respectful"))
    end

    test "includes qualifier in summary when set" do
      checked = %{"civility:no_spam" => true}
      qualifiers = %{"civility:no_spam" => "no"}
      summary = RulesBuilderLive.selected_summary(checked, qualifiers, %{}, @template)
      assert [{"Civility", [rule]}] = summary
      assert rule.qualifier == "no"
    end

    test "includes custom rules in summary" do
      custom_rules = %{"civility" => [%{"id" => 1, "name" => "House rule"}]}
      summary = RulesBuilderLive.selected_summary(%{}, %{}, custom_rules, @template)
      assert [{"Civility", [rule]}] = summary
      assert rule.name == "House rule"
    end
  end

  describe "count_selected/2" do
    test "returns 0 when nothing checked for section" do
      assert 0 == RulesBuilderLive.count_selected(%{}, "civility")
    end

    test "counts only rules in the given section" do
      checked = %{
        "civility:be_respectful" => true,
        "civility:no_spam" => true,
        "harassment:no_attacks" => true
      }

      assert 2 == RulesBuilderLive.count_selected(checked, "civility")
      assert 1 == RulesBuilderLive.count_selected(checked, "harassment")
    end
  end
end

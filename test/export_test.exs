defmodule Bonfire.CommunityRules.ExportTest do
  use Bonfire.CommunityRules.DataCase, async: true

  alias Bonfire.CommunityRules.Export
  use Bonfire.Common.Settings

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

  @saved_rules %{
    "civility" => %{
      "be_respectful" => %{},
      "no_spam" => %{"qualifier" => "no"},
      "custom" => [%{"id" => 1, "name" => "My custom rule", "qualifier" => "with_label"}]
    }
  }

  describe "export_json/3" do
    test "includes resolved name for template rules" do
      json = Export.export_json(@saved_rules, @template, "en")
      {:ok, parsed} = Jason.decode(json)
      assert parsed["lang"] == "en"
      civility = parsed["rules"]["civility"]
      assert civility["be_respectful"]["name"] == "Be respectful"
      assert civility["no_spam"]["name"] == "No spam"
      assert civility["no_spam"]["qualifier"] == "no"
    end

    test "preserves custom rule text and translations" do
      json = Export.export_json(@saved_rules, @template, "en")
      {:ok, parsed} = Jason.decode(json)
      customs = parsed["rules"]["civility"]["custom"]
      assert [%{"name" => "My custom rule", "qualifier" => "with_label"}] = customs
    end

    test "output is valid JSON" do
      json = Export.export_json(@saved_rules, @template, "en")
      assert {:ok, _} = Jason.decode(json)
    end
  end

  describe "export_elixir/2" do
    test "emits only custom rules, not template rules" do
      elixir_str = Export.export_elixir(@saved_rules, @template)
      assert elixir_str =~ "my_custom_rule" or elixir_str =~ "My custom rule"
      refute elixir_str =~ "be_respectful:"
    end

    test "output is parseable Elixir" do
      elixir_str = Export.export_elixir(@saved_rules, @template)
      assert {:ok, _quoted} = Code.string_to_quoted(elixir_str)
    end

    test "round-trip: eval'd output produces a valid keyword list with custom rule as template entry" do
      elixir_str = Export.export_elixir(@saved_rules, @template)
      {result, _} = Code.eval_string(elixir_str)
      assert is_list(result)
      civility_rules = get_in(result, [:behavior, :sections, :civility, :rules])
      assert is_list(civility_rules)

      custom_entry =
        Keyword.get(civility_rules, :my_custom_rule) ||
          Enum.find(civility_rules, fn {_k, v} -> v[:name] == "My custom rule" end)

      assert custom_entry != nil
    end

    test "round-trip: applying via Settings.put and reading back returns updated template" do
      elixir_str = Export.export_elixir(@saved_rules, @template)
      {promoted, _} = Code.eval_string(elixir_str)

      Bonfire.Common.Settings.put(
        [:bonfire_community_rules, :template_rules],
        promoted,
        scope: :instance,
        skip_boundary_check: true
      )

      stored =
        Bonfire.Common.Settings.get(
          [:bonfire_community_rules, :template_rules],
          nil,
          scope: :instance,
          skip_boundary_check: true
        )

      assert is_list(stored)
      civility_rules = get_in(stored, [:behavior, :sections, :civility, :rules])
      assert Enum.any?(civility_rules, fn {_k, v} -> v[:name] == "My custom rule" end)
    end
  end
end

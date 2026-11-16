defmodule Bonfire.CommunityRules.RulesBuilderLiveTest do
  use Bonfire.CommunityRules.ConnCase, async: false
  @moduletag :ui
  use Bonfire.Common.Settings

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

  describe "ordering on the instance rules page" do
    @url "/settings/instance/bonfire_community_rules"
    @b "#instance-rules-builder"

    @page_template [
      behavior: [
        name: "Behavior",
        sections: [
          civility: [
            name: "Civility",
            rules: [be_respectful: %{name: "Be respectful"}, no_spam: %{name: "No spam"}]
          ],
          harassment: [name: "Harassment", rules: [no_attacks: %{name: "No attacks"}]]
        ]
      ],
      content: [
        name: "Content",
        sections: [nsfw: [name: "NSFW", rules: [label_nsfw: %{name: "Label NSFW"}]]]
      ]
    ]

    setup do
      # the cache isn't rolled back with the DB sandbox
      Bonfire.Common.Cache.reset({Bonfire.CommunityRules, :get_extra_info_for_instance}, [])

      Settings.put([:bonfire_community_rules, :template_rules], @page_template,
        scope: :instance,
        skip_boundary_check: true
      )

      {:ok, _} =
        Bonfire.CommunityRules.save_rules(Bonfire.Common.Settings.instance_scope(), %{
          "civility" => %{
            "custom" => [%{"id" => 1, "name" => "House rule"}, %{"id" => 2, "name" => "Be kind"}]
          }
        })

      account = fake_account!()
      admin = fake_admin!(account)
      {:ok, conn: conn(user: admin, account: account)}
    end

    defp stored_order,
      do: Bonfire.CommunityRules.get_extra_info_for_instance().info["rules_order"]

    defp stored_customs,
      do:
        Bonfire.CommunityRules.get_extra_info_for_instance().info["rules"]["civility"]["custom"]
        |> Enum.map(& &1["name"])

    # `Settings.put` merges the test template into the configured one, so the starting order comes from the resolved template
    defp category_ids, do: Bonfire.CommunityRules.template(:instance) |> Keyword.keys() |> strs()

    defp section_ids(category),
      do:
        Bonfire.CommunityRules.template(:instance)
        |> Keyword.get(category)
        |> Keyword.get(:sections)
        |> Keyword.keys()
        |> strs()

    defp civility_rule_ids,
      do:
        Bonfire.CommunityRules.template(:instance)
        |> Keyword.get(:behavior)
        |> Keyword.get(:sections)
        |> Keyword.get(:civility)
        |> Keyword.get(:rules)
        |> Keyword.keys()
        |> strs()

    defp strs(ids), do: Enum.map(ids, &to_string/1)

    # down, unless the item is last, then up
    defp direction(list, item),
      do: if(List.last(list) == item, do: "up", else: "down")

    defp swap(list, item) do
      i = Enum.find_index(list, &(&1 == item))
      j = if direction(list, item) == "down", do: i + 1, else: i - 1
      list |> List.replace_at(i, Enum.at(list, j)) |> List.replace_at(j, item)
    end

    test "custom rules come before template rules, and the up/down buttons move and save each kind",
         %{conn: conn} do
      category_dir = direction(category_ids(), "behavior")
      section_dir = direction(section_ids(:behavior), "civility")
      rule_dir = direction(civility_rule_ids(), "be_respectful")
      categories = swap(category_ids(), "behavior")
      sections = swap(section_ids(:behavior), "civility")
      rules = swap(civility_rule_ids(), "be_respectful")

      conn
      |> visit(@url)
      |> click_button("#{@b}-section-header-civility", "")
      |> assert_has("#{@b}-section-body-civility > :first-child#{@b}-custom-rules-list-civility")
      |> click_button("#{@b}-move-category-behavior-#{category_dir}", "")
      |> click_button("#{@b}-move-section-civility-#{section_dir}", "")
      |> click_button("#{@b}-move-rule-civility-be_respectful-#{rule_dir}", "")
      |> click_button("#{@b}-move-custom-civility-1-down", "")
      |> refute_has("[data-id=flash_error]")

      assert stored_order()["categories"] == categories
      assert stored_order()["sections"]["behavior"] == sections
      assert stored_order()["rules"]["civility"] == rules
      assert stored_customs() == ["Be kind", "House rule"]

      # a new visit shows the saved order
      conn
      |> visit(@url)
      |> assert_has(
        "#{@b}-categories > :first-child##{String.trim_leading(@b, "#")}-category-#{hd(categories)}"
      )
      |> click_button("#{@b}-section-header-civility", "")
      |> assert_has(
        "#{@b}-rules-civility > :first-child##{String.trim_leading(@b, "#")}-rule-civility-#{hd(rules)}"
      )
    end

    test "dragging saves the order the Draggable hook sends", %{conn: conn} do
      categories = Enum.reverse(category_ids())
      sections = Enum.reverse(section_ids(:behavior))
      rules = Enum.reverse(civility_rule_ids())

      conn
      |> visit(@url)
      |> click_button("#{@b}-section-header-civility", "")
      |> unwrap(fn view ->
        import Phoenix.LiveViewTest

        view
        |> element("#{@b}-categories")
        |> render_hook("reorder_categories", %{"target_order" => categories})

        view
        |> element("#{@b}-sections-behavior")
        |> render_hook("reorder_sections", %{
          "parent_item" => "behavior",
          "target_order" => sections
        })

        view
        |> element("#{@b}-rules-civility")
        |> render_hook("reorder_template_rules", %{
          "parent_item" => "civility",
          "target_order" => rules
        })

        view
        |> element("#{@b}-custom-rules-list-civility")
        |> render_hook("reorder_custom_rules", %{
          "parent_item" => "civility",
          "target_order" => ["2", "1"]
        })
      end)

      assert stored_order()["categories"] == categories
      assert stored_order()["sections"]["behavior"] == sections
      assert stored_order()["rules"]["civility"] == rules
      assert stored_customs() == ["Be kind", "House rule"]
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

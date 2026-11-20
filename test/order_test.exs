defmodule Bonfire.CommunityRules.OrderTest do
  # the instance's rules and template are global, so not async
  use Bonfire.CommunityRules.DataCase, async: false
  use Bonfire.Common.Settings

  alias Bonfire.CommunityRules

  @template [
    behavior: [
      name: "Behavior",
      sections: [
        civility: [
          name: "Civility",
          rules: [
            be_respectful: %{name: "Be respectful"},
            no_spam: %{name: "No spam"}
          ]
        ],
        harassment: [
          name: "Harassment",
          rules: [no_attacks: %{name: "No attacks"}]
        ]
      ]
    ],
    content: [
      name: "Content",
      sections: [
        nsfw: [name: "NSFW", rules: [label_nsfw: %{name: "Label NSFW"}]]
      ]
    ]
  ]

  defp ids(list), do: Keyword.keys(list)

  defp section_ids(template, cat),
    do: template |> Keyword.get(cat) |> Keyword.get(:sections) |> ids()

  defp rule_ids(template, cat, section),
    do:
      template
      |> Keyword.get(cat)
      |> Keyword.get(:sections)
      |> Keyword.get(section)
      |> Keyword.get(:rules)
      |> ids()

  defp rule_names(sections) do
    for %{sections: secs} <- sections, %{rules: rules} <- secs, rule <- rules, do: rule.name
  end

  defp put_template do
    Settings.put([:bonfire_community_rules, :template_rules], @template,
      scope: :instance,
      skip_boundary_check: true
    )
  end

  defp other_entity, do: Bonfire.Me.Fake.fake_user!()

  setup do
    # the cache isn't rolled back with the DB sandbox
    Bonfire.Common.Cache.reset({CommunityRules, :get_extra_info_for_instance}, [])
    Bonfire.Common.Cache.reset({CommunityRules, :load_instance_rules_sections}, [])
    :ok
  end

  describe "order_template/2" do
    test "reorders categories, the sections in a category, and the rules in a section" do
      ordered =
        CommunityRules.order_template(@template, %{
          "categories" => ["content", "behavior"],
          "sections" => %{"behavior" => ["harassment", "civility"]},
          "rules" => %{"civility" => ["no_spam", "be_respectful"]}
        })

      assert ids(ordered) == [:content, :behavior]
      assert section_ids(ordered, :behavior) == [:harassment, :civility]
      assert rule_ids(ordered, :behavior, :civility) == [:no_spam, :be_respectful]
    end

    test "skips unknown ids and appends ids the order doesn't list, in template order" do
      ordered =
        CommunityRules.order_template(@template, %{
          "categories" => ["gone", "content"],
          "rules" => %{"civility" => ["no_spam"]}
        })

      assert ids(ordered) == [:content, :behavior]
      assert rule_ids(ordered, :behavior, :civility) == [:no_spam, :be_respectful]
      # lists the order doesn't mention keep the template order
      assert section_ids(ordered, :behavior) == [:civility, :harassment]
    end

    test "returns the template as it is with no order" do
      assert CommunityRules.order_template(@template, %{}) == @template
      assert CommunityRules.order_template(@template, nil) == @template
    end
  end

  describe "selected_rules/4" do
    test "puts custom rules before the ticked template rules of the same section" do
      [%{sections: [%{rules: rules}]}] =
        CommunityRules.selected_rules(
          %{"civility:be_respectful" => true},
          %{},
          %{"civility" => [%{"id" => 1, "name" => "House rule"}]},
          @template
        )

      assert Enum.map(rules, & &1.name) == ["House rule", "Be respectful"]
    end
  end

  describe "save_rules/3" do
    test "stores the order beside the rules, and keeps the other info keys" do
      entity = other_entity()

      {:ok, _} =
        CommunityRules.save_rules(
          Bonfire.Data.Identity.ExtraInfo.changeset(
            %Bonfire.Data.Identity.ExtraInfo{id: entity.id},
            %{info: %{"icon" => "star"}}
          )
          |> Bonfire.Common.Repo.insert!(),
          %{"civility" => %{"be_respectful" => %{}}},
          %{"categories" => ["content", "behavior"]}
        )

      info = CommunityRules.get_extra_info_by_id(entity.id).info
      assert info["rules_order"] == %{"categories" => ["content", "behavior"]}
      assert info["rules"] == %{"civility" => %{"be_respectful" => %{}}}
      assert info["icon"] == "star"
    end

    test "keeps the stored order when saving rules without one" do
      entity = other_entity()
      {:ok, _} = CommunityRules.save_rules(entity.id, %{}, %{"categories" => ["content"]})
      {:ok, _} = CommunityRules.save_rules(entity.id, %{"civility" => %{"no_spam" => %{}}})

      assert CommunityRules.get_extra_info_by_id(entity.id).info["rules_order"] ==
               %{"categories" => ["content"]}
    end
  end

  describe "rules_order/1" do
    test "an entity with no order of its own and no instance order has none" do
      assert CommunityRules.rules_order(CommunityRules.get_extra_info_by_id(other_entity().id)) ==
               %{}
    end

    test "an entity with no order of its own gets the instance's, list by list" do
      {:ok, _} =
        CommunityRules.save_rules(Settings.instance_scope(), %{}, %{
          "categories" => ["content", "behavior"],
          "rules" => %{"civility" => ["no_spam", "be_respectful"]}
        })

      entity = other_entity()

      {:ok, _} =
        CommunityRules.save_rules(entity.id, %{}, %{
          "rules" => %{"civility" => ["be_respectful", "no_spam"]}
        })

      assert CommunityRules.rules_order(CommunityRules.get_extra_info_by_id(entity.id)) == %{
               "categories" => ["content", "behavior"],
               "rules" => %{"civility" => ["be_respectful", "no_spam"]}
             }
    end

    test "the instance uses its own order only" do
      {:ok, _} =
        CommunityRules.save_rules(Settings.instance_scope(), %{}, %{"categories" => ["content"]})

      assert CommunityRules.rules_order(CommunityRules.get_extra_info_for_instance()) ==
               %{"categories" => ["content"]}
    end
  end

  describe "get_entity_rules_sections/2" do
    setup do
      put_template()

      {:ok, _} =
        CommunityRules.save_rules(Settings.instance_scope(), %{
          "civility" => %{
            "be_respectful" => %{},
            "custom" => [%{"id" => 1, "name" => "House rule"}]
          }
        })

      entity = other_entity()

      {:ok, _} =
        CommunityRules.save_rules(entity.id, %{
          "civility" => %{
            "be_respectful" => %{},
            "no_spam" => %{},
            "custom" => [%{"id" => 1, "name" => "House rule"}]
          }
        })

      {:ok, entity: CommunityRules.get_extra_info_by_id(entity.id)}
    end

    # `Settings.put` merges the test template into the configured one, which can change the order of the rules both have, so expectations follow the resolved template rather than `@template`
    defp civility_template_order do
      CommunityRules.template(:instance)
      |> rule_ids(:behavior, :civility)
      |> Enum.filter(&(&1 in [:be_respectful, :no_spam]))
      |> Enum.map(&%{be_respectful: "Be respectful", no_spam: "No spam"}[&1])
    end

    test "without except, lists every rule the entity has, in template order", %{entity: entity} do
      assert rule_names(CommunityRules.get_entity_rules_sections(entity)) ==
               ["House rule" | civility_template_order()]
    end

    test "with except, leaves out the template rules the other entity also has, but never custom rules",
         %{entity: entity} do
      assert rule_names(
               CommunityRules.get_entity_rules_sections(entity,
                 except: CommunityRules.get_extra_info_for_instance()
               )
             ) == ["House rule", "No spam"]
    end

    test "uses the order it inherits from the instance", %{entity: entity} do
      # the opposite of the template order, so the test can't pass on the template order alone
      reversed = Enum.reverse(civility_template_order())
      ids = %{"Be respectful" => "be_respectful", "No spam" => "no_spam"}

      {:ok, _} =
        CommunityRules.save_rules(Settings.instance_scope(), %{}, %{
          "rules" => %{"civility" => Enum.map(reversed, &ids[&1])}
        })

      assert rule_names(CommunityRules.get_entity_rules_sections(entity)) ==
               ["House rule" | reversed]
    end
  end

  describe "rules_sections_for/1" do
    test "gives an entity's own rules apart from the instance rules it shares, and the instance's" do
      put_template()

      {:ok, _} =
        CommunityRules.save_rules(Settings.instance_scope(), %{
          "civility" => %{"be_respectful" => %{}}
        })

      entity = other_entity()

      {:ok, _} =
        CommunityRules.save_rules(entity.id, %{
          "civility" => %{
            "be_respectful" => %{},
            "no_spam" => %{},
            "custom" => [%{"id" => 1, "name" => "House rule"}]
          }
        })

      {own, instance} = CommunityRules.rules_sections_for(entity)

      assert rule_names(own) == ["House rule", "No spam"]
      assert rule_names(instance) == ["Be respectful"]
    end
  end
end

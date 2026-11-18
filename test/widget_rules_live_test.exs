defmodule Bonfire.CommunityRules.WidgetRulesLiveTest do
  use Bonfire.CommunityRules.ConnCase, async: false
  use Bonfire.Common.Settings
  @moduletag :ui

  @test_template [
    behavior: [
      name: "Behavior",
      sections: [
        civility: [
          name: "Civility",
          rules: [
            be_respectful: %{name: "Be respectful"},
            no_attacks: %{name: "No personal attacks"}
          ]
        ],
        spam: [
          name: "Spam",
          rules: [
            no_spam: %{name: "No spam", has_qualifier: true}
          ]
        ]
      ]
    ]
  ]

  setup do
    Settings.put([:bonfire_community_rules, :template_rules], @test_template,
      scope: :instance,
      skip_boundary_check: true
    )

    # the cache isn't rolled back with the DB sandbox
    Bonfire.Common.Cache.reset({Bonfire.CommunityRules, :load_instance_rules_sections}, [])

    :ok
  end

  defp dashboard do
    user = fake_user!()
    conn(user: user, account: user.account) |> visit("/dashboard")
  end

  test "renders nothing where no rules are written" do
    dashboard() |> refute_has("[data-id=widget_rules]")
  end

  test "before Show all, hides a category heading only when all of its rules are hidden" do
    # the widget shows the first 10: tick 10 in the first category and 1 in the next, from the template as `Settings.put` merged it into the configured one
    [{_, first}, {_, second} | _] =
      Bonfire.CommunityRules.template(:instance)
      |> Enum.filter(fn {_, category} -> length(rule_keys(category)) >= 1 end)

    picked = Enum.take(rule_keys(first), 10) ++ Enum.take(rule_keys(second), 1)
    assert length(picked) == 11

    {:ok, _} =
      Bonfire.CommunityRules.save_rules(
        Settings.instance_scope(),
        Enum.reduce(picked, %{}, fn {section, rule}, acc ->
          Map.update(acc, section, %{rule => %{}}, &Map.put(&1, rule, %{}))
        end)
      )

    dashboard()
    |> assert_has("[data-id=widget_rules] [data-role=rules-category][data-extra]",
      text: Keyword.get(second, :name)
    )
    |> refute_has("[data-id=widget_rules] [data-role=rules-category][data-extra]",
      text: Keyword.get(first, :name)
    )
  end

  defp rule_keys(category) do
    for {section, data} <- Keyword.get(category, :sections, []),
        {rule, _} <- Keyword.get(data, :rules, []),
        do: {to_string(section), to_string(rule)}
  end

  describe "with rules written" do
    setup do
      {:ok, _} =
        Bonfire.CommunityRules.save_rules(Settings.instance_scope(), %{
          "civility" => %{"be_respectful" => %{}, "no_attacks" => %{}},
          "spam" => %{"no_spam" => %{"qualifier" => "no"}}
        })

      :ok
    end

    test "shows all the rules on the dashboard, with their qualifiers" do
      dashboard()
      |> assert_has("[data-id=widget_rules]", text: "Be respectful")
      |> assert_has("[data-id=widget_rules]", text: "No personal attacks")
      |> assert_has("[data-id=widget_rules]", text: "No spam")
      |> assert_has("[data-id=widget_rules]", text: "Not allowed")
      |> assert_has("a[data-role=widget_rules_link][href='/conduct']")
    end

    # the rules sit beside the code of conduct, and the widget there doesn't link to the page it's on
    test "the code of conduct page shows them in its sidebar to members, and above the text to guests, without a link back to it" do
      user = fake_user!()

      conn(user: user, account: user.account)
      |> visit("/conduct")
      |> assert_has("[data-id=widget_rules]", text: "Be respectful")
      |> refute_has("[data-role=widget_rules_link]")

      # a guest has no LiveView socket, so the page they get is the static render
      build_conn()
      |> get_conn_render("/conduct")
      |> refute_has("[data-id=right_nav_and_widgets]")
      |> assert_has("#guest-board-sheet #conduct-rules ~ #conduct-body")
      |> assert_has("#conduct-rules li", text: "Be respectful")
      |> refute_has("#conduct-rules a[href='/conduct']")
    end
  end
end

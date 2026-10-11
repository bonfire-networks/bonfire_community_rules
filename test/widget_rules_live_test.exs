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
    end
  end
end

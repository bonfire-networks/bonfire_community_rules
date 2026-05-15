defmodule Bonfire.CommunityRules.RulesDisplayLiveTest do
  use Bonfire.CommunityRules.ConnCase, async: false
  use Bonfire.Common.Settings
  @moduletag :ui

  @url "/rules"

  @test_template [
    behavior: [
      name: "Behavior",
      sections: [
        civility: [
          name: "Civility",
          rules: [
            be_respectful: %{name: "Be respectful"}
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

  describe "instance rules page - no rules set" do
    test "renders without crashing when logged out" do
      build_conn()
      |> visit(@url)
      |> refute_has("[data-id=flash_error]")
    end

    test "shows nothing when no rules are set" do
      build_conn()
      |> visit(@url)
      |> refute_has("#instance-rules-view [id^=rules-display-section-]")
    end
  end

  describe "instance rules page - with rules set" do
    setup do
      account = fake_account!()
      admin = fake_admin!(account)

      Settings.put([:bonfire_community_rules, :template_rules], @test_template,
        scope: :instance,
        skip_boundary_check: true
      )

      conn = conn(user: admin, account: account)
      {:ok, conn: conn, admin: admin}
    end

    test "shows selected rule text after rules are saved", %{admin: admin} do
      entity_id = Bonfire.Common.Settings.instance_scope()

      {:ok, _} =
        Bonfire.CommunityRules.save_rules(entity_id, %{
          "civility" => %{"be_respectful" => %{}}
        })

      build_conn()
      |> visit(@url)
      |> assert_has("#instance-rules-view", text: "Be respectful")
    end

    test "shows qualifier label when rule has qualifier set", %{admin: admin} do
      entity_id = Bonfire.Common.Settings.instance_scope()

      {:ok, _} =
        Bonfire.CommunityRules.save_rules(entity_id, %{
          "spam" => %{"no_spam" => %{"qualifier" => "no"}}
        })

      build_conn()
      |> visit(@url)
      |> assert_has("#instance-rules-view", text: "Not allowed")
    end

    test "does not show unchecked rules" do
      build_conn()
      |> visit(@url)
      |> refute_has("#instance-rules-view", text: "No personal attacks")
    end
  end
end

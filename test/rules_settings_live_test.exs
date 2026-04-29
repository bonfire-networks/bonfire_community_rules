defmodule Bonfire.CommunityRules.RulesSettingsLiveTest do
  use Bonfire.CommunityRules.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Settings

  @url "/settings/instance/bonfire_community_rules"

  @tmpl "#rules-builder-settings"
  @inst "#instance-rules-builder"

  setup do
    account = fake_account!()
    admin = fake_admin!(account)
    conn = conn(user: admin, account: account)
    {:ok, conn: conn, admin: admin, account: account}
  end

  describe "RulesTemplatesLive - template editing" do
    test "renders rules template settings page", %{conn: conn} do
      conn
      |> visit(@url)
      |> assert_has("#{@tmpl} h2", text: "Rules Template")
    end

    test "renders template sections from config", %{conn: conn} do
      conn
      |> visit(@url)
      |> assert_has("#{@tmpl} [id^=section-header-]")
    end

    test "admin can add a custom rule to a section", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@tmpl} #section-header-civility")
      |> click_button("#{@tmpl} #add-custom-btn-civility", "+ Add rule")
      |> fill_in("Rule name...", with: "No hate speech")
      |> click_button("Add")
      |> assert_has("#{@tmpl} [id^=custom-rule-civility-]", text: "No hate speech")
    end

    test "save stores template via Settings.put", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@tmpl} #save-rules-btn", "Save template")
      |> assert_has("[data-id=flash_info]", text: "Template saved")
    end

    test "Export JSON button opens modal", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@tmpl} #export-json-btn", "Export JSON")
      |> assert_has("#export-modal")
      |> assert_has("#export-output")
    end

    test "Export config button opens modal with Elixir output", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@tmpl} #export-elixir-btn", "Export config")
      |> assert_has("#export-modal")
      |> assert_has("#export-output")
    end
  end

  describe "InstanceRulesLive - instance entity rules" do
    test "renders instance rules settings page", %{conn: conn} do
      conn
      |> visit(@url)
      |> assert_has("#{@inst} h2", text: "Instance Rules")
    end

    test "checking a rule with qualifier shows enforcement options", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@inst} #section-header-civility")
      |> check("#{@inst} #rule-check-civility-no_spam")
      |> assert_has("#{@inst} #qualifier-block-civility-no_spam")
    end

    test "checking a rule auto-saves to instance extra_info", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@inst} #section-header-civility")
      |> check("#{@inst} #rule-check-civility-be_respectful")
      |> refute_has("[data-id=flash_error]")
    end
  end
end

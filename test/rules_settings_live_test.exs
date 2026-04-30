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
      # |> open_browser()
      |> assert_has("#{@tmpl} h2", text: "Rules Template")
    end

    test "renders template sections from config", %{conn: conn} do
      conn
      |> visit(@url)
      |> assert_has("#{@tmpl} [id^=rules-builder-settings-section-header-]")
    end

    test "admin can add a custom rule to a section", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#rules-builder-settings-section-header-civility", "Civility")
      |> click_button("#rules-builder-settings-add-custom-btn-civility", "+ Add rule")
      |> fill_in("Rule name...", with: "No hate speech")
      |> click_button(
        "#rules-builder-settings-add-custom-form-civility button[type=submit]",
        "Add"
      )
      |> assert_has("#{@tmpl} [id^=rules-builder-settings-tmpl-rule-civility-]",
        text: "No hate speech"
      )
    end

    test "save stores template via Settings.put", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@tmpl} #rules-builder-settings-save-rules-btn", "Save template")
      |> assert_has("[data-id=flash_info]", text: "Template saved")
    end

    test "Export JSON button opens modal", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@tmpl} #rules-builder-settings-export-json-btn", "Export JSON")
      |> assert_has("#rules-builder-settings-export-modal")
      |> assert_has("#rules-builder-settings-export-output")
    end

    test "Export config button opens modal with Elixir output", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#{@tmpl} #rules-builder-settings-export-elixir-btn", "Export config")
      |> assert_has("#rules-builder-settings-export-modal")
      |> assert_has("#rules-builder-settings-export-output")
    end
  end

  describe "InstanceRulesLive - instance entity rules" do
    test "renders instance rules settings page", %{conn: conn} do
      conn
      |> visit(@url)
      |> assert_has("#instance-rules-builder [id^=instance-rules-builder-section-header-]")
    end

    test "checking a rule with qualifier shows enforcement options", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#instance-rules-builder-section-header-spam", "Spam")
      |> check("#instance-rules-builder-rule-check-spam-no_spam", "No spam")
      |> assert_has("#{@inst} #instance-rules-builder-qualifier-block-spam-no_spam")
    end

    test "checking a rule auto-saves to instance extra_info", %{conn: conn} do
      conn
      |> visit(@url)
      |> click_button("#instance-rules-builder-section-header-civility", "Civility")
      |> check("#instance-rules-builder-rule-check-civility-be_respectful", "Be respectful",
        exact: false
      )
      |> refute_has("[data-id=flash_error]")
    end
  end
end

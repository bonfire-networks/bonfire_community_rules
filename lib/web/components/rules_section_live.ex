defmodule Bonfire.CommunityRules.Web.RulesSectionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop section_id, :string, required: true
  prop section_data, :list, required: true
  prop mode, :atom, default: :entity
  prop checked, :map, default: %{}
  prop qualifiers, :map, default: %{}
  prop custom_rules, :map, default: %{}
  prop open_sections, :map, default: %{}
  prop add_custom_mode, :map, default: %{}
  prop read_only, :boolean, default: false
  prop target, :any, required: true
end

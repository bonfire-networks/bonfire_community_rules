defmodule Bonfire.CommunityRules.Web.RulesEntityRuleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop section_id, :string, required: true
  prop rule_id, :string, required: true
  prop rule_meta, :map, required: true
  prop checked, :map, default: %{}
  prop qualifiers, :map, default: %{}
  prop read_only, :boolean, default: false
  prop target, :any, required: true
end

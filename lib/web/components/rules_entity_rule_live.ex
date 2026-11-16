defmodule Bonfire.CommunityRules.Web.RulesEntityRuleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop parent_id, :string, required: true
  prop section_id, :string, required: true
  prop rule_id, :string, required: true
  prop rule_meta, :map, required: true
  prop checked, :map, default: %{}
  prop qualifiers, :map, default: %{}

  @doc "The instance's ticked rules, `key => qualifier`: these show ticked and locked."
  prop inherited, :map, default: %{}

  prop read_only, :boolean, default: false
  prop reorderable, :boolean, default: false
  prop first, :boolean, default: false
  prop last, :boolean, default: false
  prop target, :any, required: true
end

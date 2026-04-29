defmodule Bonfire.CommunityRules.Web.RulesCustomRuleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop section_id, :string, required: true
  prop rule, :map, required: true
  prop mode, :atom, default: :entity
  prop read_only, :boolean, default: false
  prop target, :any, required: true
end

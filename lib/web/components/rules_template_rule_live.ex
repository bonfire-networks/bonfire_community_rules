defmodule Bonfire.CommunityRules.Web.RulesTemplateRuleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop section_id, :string, required: true
  prop rule_id, :string, required: true
  prop rule_meta, :map, required: true
  prop read_only, :boolean, default: false
  prop target, :any, required: true
end

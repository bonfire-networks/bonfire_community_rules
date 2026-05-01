defmodule Bonfire.CommunityRules.Web.RulesDisplayBodyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop sections, :list, required: true

  def all_rules(sections) do
    Enum.flat_map(sections || [], fn category ->
      Enum.flat_map(e(category, :sections, []), fn section ->
        e(section, :rules, [])
      end)
    end)
  end
end

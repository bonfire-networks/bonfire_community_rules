defmodule Bonfire.CommunityRules.Web.InstanceRulesDisplayLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop show_header, :boolean, default: true
  prop entity, :any, default: nil
  prop sections, :list, default: nil

  @doc "Optional class overrides for the rules list, as a map with any of `:list`, `:item`, `:index`, `:name` (see `RulesDisplayBodyLive`)."
  prop classes, :map, default: %{}
end

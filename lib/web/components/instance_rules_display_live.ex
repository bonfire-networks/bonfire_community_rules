defmodule Bonfire.CommunityRules.Web.InstanceRulesDisplayLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop show_header, :boolean, default: true
  prop entity, :any, default: nil
  prop sections, :list, default: nil
end

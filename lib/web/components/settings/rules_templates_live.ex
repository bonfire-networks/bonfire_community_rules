defmodule Bonfire.CommunityRules.Web.RulesTemplatesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  declare_settings_component(l("Rules Template"),
    icon: "ph:list-bullets",
    description: l("Edit the template of rules that communities can choose from")
  )

  prop scope, :any, default: :instance
end

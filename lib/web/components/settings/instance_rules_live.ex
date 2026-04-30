defmodule Bonfire.CommunityRules.Web.InstanceRulesLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Settings

  declare_settings_component(l("Instance Rules"),
    icon: "ph:scales",
    description: l("Set the active rules for this instance"),
    scope: :instance
  )

  prop scope, :any, default: :instance
end

defmodule Bonfire.CommunityRules.Web.WidgetRulesLive do
  @moduledoc "Sidebar widget listing the instance's community rules. Renders nothing when there are none."
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget(l("Community rules"), id: :community_rules, skeleton: :list)

  prop widget_title, :string, default: nil

  @doc "Whether to link to the code of conduct page, which the code of conduct page itself turns off."
  prop show_link, :boolean, default: true
end

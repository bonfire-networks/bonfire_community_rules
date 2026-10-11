defmodule Bonfire.CommunityRules.Web.WidgetRulesLive do
  @moduledoc "Sidebar widget listing the instance's community rules. Renders nothing when there are none."
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil
end

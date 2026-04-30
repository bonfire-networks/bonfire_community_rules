defmodule Bonfire.CommunityRules.Web.Routes do
  @behaviour Bonfire.UI.Common.RoutesModule

  defmacro __using__(_) do
    quote do
      scope "/", Bonfire.CommunityRules.Web do
        # pipe_through(:cacheable_page)
        pipe_through(:browser)

        live("/rules", InstanceRulesViewLive)
      end
    end
  end
end

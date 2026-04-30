defmodule Bonfire.CommunityRules.Web.InstanceRulesViewLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Instance Rules"),
       without_sidebar: true
     )}
  end
end

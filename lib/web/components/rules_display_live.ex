defmodule Bonfire.CommunityRules.Web.RulesDisplayLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.CommunityRules
  alias Bonfire.CommunityRules.Qualifier

  prop entity_id, :any, default: nil
  prop entity, :any, default: nil
  prop sections, :list, default: nil
  prop title, :string, default: nil
  prop show_header, :boolean, default: true

  def update(assigns, socket) do
    # reuse pre-computed sections if given, otherwise load & hydrate the entity (once, via CommunityRules)
    sections =
      assigns[:sections] ||
        (assigns[:entity] ||
           case assigns[:entity_id] do
             nil -> nil
             id -> CommunityRules.get_extra_info_by_id(id)
           end)
        |> CommunityRules.get_entity_rules_sections()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(sections: sections)}
  end
end

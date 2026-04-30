defmodule Bonfire.CommunityRules.Web.RulesDisplayLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.CommunityRules
  alias Bonfire.CommunityRules.Qualifier

  prop entity_id, :any, default: nil
  prop entity, :any, default: nil
  prop title, :string, default: nil
  prop show_header, :boolean, default: true

  def update(assigns, socket) do
    entity =
      assigns[:entity] ||
        case assigns[:entity_id] do
          nil -> nil
          id -> CommunityRules.get_extra_info_by_id(id)
        end

    {checked, qualifiers, custom_rules} = CommunityRules.hydrate_entity(entity)
    template = CommunityRules.template(:instance)

    sections = CommunityRules.selected_rules(checked, qualifiers, custom_rules, template)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(sections: sections)}
  end
end

defmodule Bonfire.CommunityRules.Web.RulesDisplayBodyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop sections, :list, required: true

  @doc "Class overrides, a map with any of `:list`, `:item`, `:index`, `:name`, `:footer`, `:show_all`."
  prop classes, :map, default: %{}

  @doc "Show only the first `show_first` rules until \"Show all\" is ticked."
  prop collapsible, :boolean, default: false

  @doc "How many rules a collapsible list shows before \"Show all\"."
  prop show_first, :integer, default: 10

  @doc "Prefix of the \"Show all\" checkbox id, unique per page."
  prop id, :string, default: "rules-list"

  @doc "Shown beside the \"Show all\" toggle."
  slot footer

  @default_classes %{
    list: "list-none flex flex-col gap-3",
    item: "flex items-baseline gap-3",
    index: "font-mono tabular-nums text-xs text-subtle shrink-0 text-right",
    name: "text-sm leading-snug text-base-content",
    footer: "flex justify-center mt-3",
    show_all: "inline-flex expand-pill cursor-pointer"
  }

  @doc """
  The class for one part of the list, from the overrides or the default.

      iex> Bonfire.CommunityRules.Web.RulesDisplayBodyLive.class_for(%{item: "flex"}, :item)
      "flex"

      iex> Bonfire.CommunityRules.Web.RulesDisplayBodyLive.class_for(%{}, :item)
      "flex items-baseline gap-3"
  """
  # `classes` can arrive as nil from stateful parents that don't set it
  def class_for(classes, part), do: Map.get(classes || %{}, part) || @default_classes[part]

  def all_rules(sections) do
    Enum.flat_map(sections || [], fn category ->
      Enum.flat_map(e(category, :sections, []), fn section ->
        e(section, :rules, [])
      end)
    end)
  end
end

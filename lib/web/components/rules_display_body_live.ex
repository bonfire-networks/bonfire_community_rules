defmodule Bonfire.CommunityRules.Web.RulesDisplayBodyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop sections, :list, required: true

  @doc "Class overrides, a map with any of `:body`, `:category`, `:divider`, `:list` (one per section), `:item`, `:index`, `:name`, `:footer`, `:show_all`."
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
    body: "flex flex-col gap-3",
    # not an overline: widgets title the list with one, and the category sits a level below it
    category: "text-xs font-semibold text-muted mt-2 first:mt-0",
    divider: "border-divider",
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

  @doc """
  The categories with each rule's place in the whole list (from 1), and where each category and section starts, so that "Show all" can hide a heading or divider whose rules are all hidden.

      iex> Bonfire.CommunityRules.Web.RulesDisplayBodyLive.positioned([%{name: "A", sections: [%{rules: [:a1, :a2]}, %{rules: [:a3]}]}, %{name: "B", sections: [%{rules: [:b1]}]}])
      [
        %{name: "A", first: 1, sections: [%{first: 1, rules: [{:a1, 1}, {:a2, 2}]}, %{first: 3, rules: [{:a3, 3}]}]},
        %{name: "B", first: 4, sections: [%{first: 4, rules: [{:b1, 4}]}]}
      ]
  """
  def positioned(sections) do
    {categories, _next} =
      Enum.map_reduce(sections || [], 1, fn category, first ->
        {category_sections, next} =
          Enum.map_reduce(e(category, :sections, []), first, fn section, section_first ->
            rules = e(section, :rules, [])

            {%{first: section_first, rules: Enum.with_index(rules, section_first)},
             section_first + length(rules)}
          end)

        {%{name: e(category, :name, nil), first: first, sections: category_sections}, next}
      end)

    categories
  end

  def all_rules(sections) do
    Enum.flat_map(sections || [], fn category ->
      Enum.flat_map(e(category, :sections, []), fn section ->
        e(section, :rules, [])
      end)
    end)
  end
end

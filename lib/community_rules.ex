defmodule Bonfire.CommunityRules do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  use Bonfire.Common.Config
  use Bonfire.Common.Settings
  use Bonfire.Common.Localise
  use Bonfire.Common.E
  import Untangle
  import Bonfire.Common.Modularity.DeclareHelpers
  alias Bonfire.Common.Cache
  alias Bonfire.Common.Utils
  alias Bonfire.Common.E
  alias Bonfire.CommunityRules.Changesets

  declare_extension(
    l("Community Rules"),
    icon: "bi:app",
    description: l("Community governance extension")
    # default_nav: [
    #   Bonfire.CommunityRules.Web.HomeLive
    # ]
  )

  @doc "Returns the active rules map for the local instance, or nil."
  def get_rules(id \\ Settings.instance_scope())

  def get_rules(id) when is_binary(id) do
    get_extra_info_by_id(id) |> get_rules()
  end

  @doc "Returns the rules map from an entity's extra_info, or nil."
  def get_rules(%{extra_info: %{info: info}}) do
    e(info, "rules", nil)
  end

  def get_rules(%{info: info}) do
    e(info, "rules", nil)
  end

  def get_rules(%{id: id}) when is_binary(id), do: get_rules(id)
  def get_rules(_), do: nil

  @doc "Returns the lang stored alongside the rules, or nil."
  def get_lang(%{extra_info: %{info: info}}), do: e(info, "lang", nil)
  def get_lang(%{info: info}), do: e(info, "lang", nil)
  def get_lang(_), do: nil

  @doc "Merges a rules map into the entity struct. Does not persist."
  def merge_rules(entity, rules) when is_map(rules) do
    Changesets.merge_rules(entity, rules)
  end

  @doc "Appends a custom rule to a section. Does not persist."
  def add_custom_rule(entity, section_id, attrs) when is_map(attrs) do
    Changesets.add_custom_rule(entity, section_id, attrs)
  end

  @doc "Returns the resolved template from settings or config."
  def template(scope \\ nil) do
    Settings.get(
      [:bonfire_community_rules, :template_rules],
      nil,
      scope: scope,
      skip_boundary_check: true
    ) ||
      Config.get([:bonfire_community_rules, :template_rules], [])
  end

  @doc """
  Persists a rules map for the given entity ID. Returns `{:ok, extra_info}` or `{:error, reason}`.

  `order` (see `order_template/2` for its shape) replaces the stored order when given. Without it the stored order stays.
  """
  def save_rules(entity_or_id, rules, order \\ nil)

  def save_rules(entity_id, rules, order) when is_binary(entity_id) and is_map(rules) do
    get_extra_info_by_id(entity_id)
    |> save_rules(rules, order)
  end

  def save_rules(%Bonfire.Data.Identity.ExtraInfo{} = extra_info, rules, order)
      when is_map(rules) do
    Changesets.cast_rules_changeset(extra_info, rules, order: order)
    |> repo().insert(
      on_conflict: {:replace, [:info]},
      conflict_target: :id
    )
    |> tap(fn
      # every clause above comes through here, so nothing can write rules and leave what was read about them behind
      {:ok, _saved} ->
        Cache.reset({__MODULE__, :load_instance_rules_sections}, [])
        Cache.reset({__MODULE__, :get_extra_info_for_instance}, [])

      _ ->
        nil
    end)
  end

  # anything else that carries an `extra_info`, so that a caller holding the thing the rules are about does not have to know how they are stored
  def save_rules(entity, rules, order) when is_map(rules) do
    case e(entity, :extra_info, nil) do
      %Bonfire.Data.Identity.ExtraInfo{} = extra_info ->
        save_rules(extra_info, rules, order)

      _ ->
        save_rules(%Bonfire.Data.Identity.ExtraInfo{id: e(entity, :id, nil)}, rules, order)
    end
  end

  @doc "Returns the ExtraInfo struct for the local instance (creates an empty one if not yet saved)."
  def get_extra_info_for_instance do
    get_extra_info_by_id(Settings.instance_scope())
  end

  @doc "`get_extra_info_for_instance/0`, cached, for what every group page and group rules editor reads about the instance. `save_rules/3` forgets it."
  def instance_extra_info do
    Cache.maybe_apply_cached({__MODULE__, :get_extra_info_for_instance}, [])
  end

  @doc """
  Returns the display-ready rules sections for the local instance (loading and hydrating the entity once). Returns `[]` when none are set.

  Cached, because in one render more than one thing asks for the same rules: whether there are any worth showing somebody (`any_rules?/1`) and then the rules themselves. `save_rules/2` forgets it, so an admin sees their own edit rather than waiting for an expiry.
  """
  def get_instance_rules_sections do
    Cache.maybe_apply_cached({__MODULE__, :load_instance_rules_sections}, [])
  end

  @doc false
  def load_instance_rules_sections do
    get_extra_info_for_instance()
    |> get_entity_rules_sections()
  end

  @doc """
  Returns the display-ready rules sections for the given entity or extra_info (see `selected_rules/4` for the shape), in the entity's order (see `rules_order/1`).

  With `except: other_extra_info`, leaves out the template rules `other_extra_info` also has, so a group can show its own rules apart from the instance's. Custom rules are never left out: their ids only mean something inside one entity.
  """
  # TODO: work out how to federate which instance rules a group inherits, so remote servers can tell a group's own rules from its instance's
  def get_entity_rules_sections(entity, opts \\ []) do
    {checked, qualifiers, custom_rules} = hydrate_entity(entity)

    checked =
      case opts[:except] do
        nil ->
          checked

        except ->
          {except_checked, _, _} = hydrate_entity(except)
          Map.drop(checked, Map.keys(except_checked))
      end

    selected_rules(
      checked,
      qualifiers,
      custom_rules,
      order_template(template(:instance), rules_order(entity))
    )
  end

  @doc """
  Returns the order an entity's rules show in: `%{"categories" => [id], "sections" => %{category_id => [id]}, "rules" => %{section_id => [id]}}`, any key optional.

  Each list is the entity's own when it saved one, else the instance's (for anything other than the instance). A list in neither keeps the template order.
  """
  # TODO: work out how to federate the rules order and the category grouping, so remote servers show a group's rules the way its home instance does
  def rules_order(entity), do: entity |> own_rules_order() |> inherit_rules_order(entity)

  @doc "The order an entity saved for itself, without what it inherits (see `rules_order/1`)."
  def own_rules_order(%Bonfire.Data.Identity.ExtraInfo{} = extra_info),
    do: E.e(extra_info, :info, "rules_order", %{}) || %{}

  def own_rules_order(entity), do: E.e(entity, :extra_info, :info, "rules_order", %{}) || %{}

  @doc "Fills in the lists missing from `own` with the instance's, unless `entity` is the instance."
  def inherit_rules_order(own, entity) do
    if instance?(entity) do
      own
    else
      inherited = own_rules_order(instance_extra_info())

      %{
        "categories" => own["categories"] || inherited["categories"],
        "sections" => Map.merge(inherited["sections"] || %{}, own["sections"] || %{}),
        "rules" => Map.merge(inherited["rules"] || %{}, own["rules"] || %{})
      }
      |> Map.reject(fn {_, list} -> list in [nil, [], %{}] end)
    end
  end

  @doc "Whether the entity (or extra_info) is the local instance."
  def instance?(entity), do: E.e(entity, :id, nil) == Settings.instance_scope()

  @doc """
  Reorders a template (categories, the sections in each category, and the rules in each section) by an order map (see `rules_order/1`). Ids the order doesn't know are skipped, and template entries the order doesn't list come after the listed ones, in template order.

      iex> Bonfire.CommunityRules.order_template([a: [sections: []], b: [sections: []]], %{"categories" => ["b"]})
      [b: [sections: []], a: [sections: []]]
  """
  def order_template(template, order) when is_map(order) and order != %{} do
    template
    |> sort_by_ids(order["categories"])
    |> Enum.map(fn {category, category_data} ->
      sections =
        category_data
        |> Keyword.get(:sections, [])
        |> sort_by_ids(get_in(order, ["sections", to_string(category)]))
        |> Enum.map(fn {section, section_data} ->
          {section,
           Keyword.update(
             section_data,
             :rules,
             [],
             &sort_by_ids(&1, get_in(order, ["rules", to_string(section)]))
           )}
        end)

      {category, Keyword.put(category_data, :sections, sections)}
    end)
  end

  def order_template(template, _), do: template

  defp sort_by_ids(entries, ids) when is_list(ids) and ids != [] do
    by_id = Map.new(entries, fn {id, _} = entry -> {to_string(id), entry} end)
    listed = ids |> Enum.uniq() |> Enum.flat_map(&List.wrap(by_id[&1]))
    listed_ids = MapSet.new(ids)
    listed ++ Enum.reject(entries, fn {id, _} -> MapSet.member?(listed_ids, to_string(id)) end)
  end

  defp sort_by_ids(entries, _), do: entries

  @doc """
  Whether there are any rules to show.

  A rules map can exist and say nothing, since the template carries its custom sections whether or not anybody filled them in, so this asks for at least one selected rule rather than for the map. What decides whether a widget or a prompt about the rules is worth putting in front of anybody. Takes already-loaded sections where the caller has them.
  """
  def any_rules?(sections \\ nil) do
    (sections || get_instance_rules_sections())
    |> Enum.any?(fn category ->
      Enum.any?(e(category, :sections, []), &(e(&1, :rules, []) != []))
    end)
  end

  @doc "Returns the ExtraInfo struct for any entity by ID (returns an empty struct if not yet saved)."
  def get_extra_info_by_id(id) do
    repo().get(Bonfire.Data.Identity.ExtraInfo, id) ||
      %Bonfire.Data.Identity.ExtraInfo{id: id}
  end

  def repo, do: Config.repo()

  @doc "Returns selected rules grouped by top-level category then section: `[%{name: cat_name, sections: [%{name: section_name, rules: [%{name, qualifier}]}]}]`"
  def selected_rules(checked, qualifiers, custom_rules, template) do
    Enum.flat_map(template, fn {_top_key, top_val} ->
      top_name = Keyword.get(top_val, :name)

      sections =
        Enum.flat_map(Keyword.get(top_val, :sections, []), fn {section_id, section_data} ->
          sid = to_string(section_id)

          selected =
            Enum.flat_map(Keyword.get(section_data, :rules, []), fn {rule_id, rule_meta} ->
              key = "#{sid}:#{to_string(rule_id)}"

              if Map.get(checked, key) do
                [
                  %{
                    name: rule_meta[:name] || to_string(rule_id),
                    qualifier: Map.get(qualifiers, key)
                  }
                ]
              else
                []
              end
            end)

          custom =
            Enum.map(Map.get(custom_rules, sid, []), fn c ->
              %{name: c["name"], qualifier: c["qualifier"]}
            end)

          all = custom ++ selected
          if all == [], do: [], else: [%{name: Keyword.get(section_data, :name, sid), rules: all}]
        end)

      if sections == [], do: [], else: [%{name: top_name, sections: sections}]
    end)
  end

  @doc "Returns `{checked, qualifiers, custom_rules}` hydrated from an entity or extra_info struct."
  def hydrate_entity(nil), do: {%{}, %{}, %{}}

  def hydrate_entity(%Bonfire.Data.Identity.ExtraInfo{} = extra_info) do
    rules = E.e(extra_info, :info, "rules", %{}) || %{}
    do_hydrate(rules)
  end

  def hydrate_entity(entity) do
    rules = E.e(entity, :extra_info, :info, "rules", %{}) || %{}
    do_hydrate(rules)
  end

  defp do_hydrate(rules) do
    Enum.reduce(rules, {%{}, %{}, %{}}, fn {group_id, group_data}, {checked, quals, customs} ->
      case group_data do
        %{} ->
          {c2, q2} =
            Enum.reduce(group_data, {checked, quals}, fn
              {"custom", _}, acc ->
                acc

              {rule_id, rule_data}, {c, q} ->
                key = "#{group_id}:#{rule_id}"
                c = Map.put(c, key, true)
                q = if qual = rule_data["qualifier"], do: Map.put(q, key, qual), else: q
                {c, q}
            end)

          custom_list = Map.get(group_data, "custom", [])
          c3 = if custom_list == [], do: customs, else: Map.put(customs, group_id, custom_list)
          {c2, q2, c3}

        _ ->
          {checked, quals, customs}
      end
    end)
  end
end

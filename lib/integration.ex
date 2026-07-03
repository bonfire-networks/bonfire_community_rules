defmodule Bonfire.CommunityRules do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  use Bonfire.Common.Config
  use Bonfire.Common.Settings
  use Bonfire.Common.Localise
  use Bonfire.Common.E
  import Untangle
  import Bonfire.Common.Modularity.DeclareHelpers
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

  @doc "Persists a rules map for the given entity ID. Returns `{:ok, extra_info}` or `{:error, reason}`."
  def save_rules(entity_id, rules) when is_binary(entity_id) and is_map(rules) do
    extra_info = get_extra_info_by_id(entity_id)
    changeset = Changesets.cast_rules_changeset(extra_info, rules)

    repo().insert(changeset,
      on_conflict: {:replace, [:info]},
      conflict_target: :id
    )
  end

  @doc "Returns the ExtraInfo struct for the local instance (creates an empty one if not yet saved)."
  def get_extra_info_for_instance do
    get_extra_info_by_id(Settings.instance_scope())
  end

  @doc "Returns the display-ready rules sections for the local instance (loading and hydrating the entity once). Returns `[]` when none are set."
  def get_instance_rules_sections do
    get_extra_info_for_instance()
    |> get_entity_rules_sections()
  end

  @doc "Returns the display-ready rules sections for the given entity or extra_info (see `selected_rules/4` for the shape)."
  def get_entity_rules_sections(entity) do
    {checked, qualifiers, custom_rules} = hydrate_entity(entity)
    selected_rules(checked, qualifiers, custom_rules, template(:instance))
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

          all = selected ++ custom
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

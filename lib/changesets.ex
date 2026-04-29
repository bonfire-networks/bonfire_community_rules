defmodule Bonfire.CommunityRules.Changesets do
  alias Bonfire.CommunityRules.Qualifier
  alias Bonfire.Data.Identity.ExtraInfo

  @doc """
  Validates the rules map — checks all qualifier values are known.
  Returns `:ok` or `{:error, :invalid_qualifier}`.
  """
  def validate_rules(rules) when is_map(rules) do
    rules
    |> Enum.flat_map(fn {_group, entries} ->
      case entries do
        %{} ->
          entries
          |> Enum.flat_map(fn
            {"custom", customs} when is_list(customs) ->
              Enum.map(customs, & &1["qualifier"])

            {_rule_id, %{"qualifier" => q}} ->
              [q]

            _ ->
              []
          end)

        _ ->
          []
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.find(&(not Qualifier.valid?(&1)))
    |> case do
      nil -> :ok
      _bad -> {:error, :invalid_qualifier}
    end
  end

  @doc """
  Merges a rules map into an entity struct's `extra_info.info["rules"]`,
  preserving all other `info` keys (e.g. `"icon"`).
  Returns the updated struct.
  """
  def merge_rules(struct, rules) when is_map(rules) do
    existing_info = get_in(struct, [:extra_info, :info]) || %{}
    existing_rules = Map.get(existing_info, "rules", %{})
    merged_rules = Map.merge(existing_rules, rules)
    new_info = Map.put(existing_info, "rules", merged_rules)
    put_in(struct, [:extra_info, :info], new_info)
  end

  @doc """
  Appends a custom rule to a section's `custom` list in `extra_info.info["rules"]`.
  Auto-assigns the next integer id.
  """
  def add_custom_rule(struct, section_id, attrs) when is_map(attrs) do
    existing_info = get_in(struct, [:extra_info, :info]) || %{}
    existing_rules = Map.get(existing_info, "rules", %{})
    section = Map.get(existing_rules, section_id, %{})
    customs = Map.get(section, "custom", [])
    next_id = (customs |> Enum.map(& &1["id"]) |> Enum.max(fn -> 0 end)) + 1
    new_custom = Map.put(attrs, "id", next_id)
    updated_section = Map.put(section, "custom", customs ++ [new_custom])
    updated_rules = Map.put(existing_rules, section_id, updated_section)
    new_info = Map.put(existing_info, "rules", updated_rules)
    put_in(struct, [:extra_info, :info], new_info)
  end

  @doc """
  Builds an ExtraInfo changeset that merges rules into `info`, preserving existing keys.
  Also sets `info["lang"]` to the current locale.
  """
  def cast_rules_changeset(%ExtraInfo{} = extra_info, rules, locale \\ nil) do
    locale = locale || Bonfire.Common.Localise.get_locale() |> to_string()
    existing_info = extra_info.info || %{}
    existing_rules = Map.get(existing_info, "rules", %{})
    merged_rules = Map.merge(existing_rules, rules)
    new_info = existing_info |> Map.put("rules", merged_rules) |> Map.put("lang", locale)
    ExtraInfo.changeset(extra_info, %{info: new_info})
  end
end

defmodule Bonfire.CommunityRules.Export do
  alias Bonfire.CommunityRules.Localise

  @doc """
  Exports the saved rules as self-contained JSON: template rule keys are expanded
  with resolved `name` text; custom rules are included as-is.
  """
  def export_json(rules, template, locale \\ "en", opts \\ []) do
    extra_locales = Keyword.get(opts, :locales, []) |> Enum.reject(&(&1 == locale))

    expanded =
      Map.new(rules, fn {section_id, section_data} ->
        section_atom = safe_atom(section_id)

        expanded_section =
          Map.new(section_data, fn
            {"custom", customs} ->
              {"custom", customs}

            {rule_id, rule_data} ->
              rule_atom = safe_atom(rule_id)
              name = Localise.template_rule_text(section_atom, rule_atom, template)
              summary = Localise.template_rule_summary(section_atom, rule_atom, template)

              resolved =
                rule_data
                |> Map.put("name", name)
                |> then(fn m -> if summary, do: Map.put(m, "summary", summary), else: m end)
                |> then(fn m ->
                  if extra_locales == [] do
                    m
                  else
                    translations =
                      Map.new(extra_locales, fn loc ->
                        loc_name =
                          resolve_in_locale(loc, fn ->
                            Localise.template_rule_text(section_atom, rule_atom, template)
                          end)

                        loc_summary =
                          resolve_in_locale(loc, fn ->
                            Localise.template_rule_summary(section_atom, rule_atom, template)
                          end)

                        entry = if loc_name, do: %{"name" => loc_name}, else: %{}

                        entry =
                          if loc_summary, do: Map.put(entry, "summary", loc_summary), else: entry

                        {loc, entry}
                      end)
                      |> Enum.reject(fn {_, v} -> v == %{} end)
                      |> Map.new()

                    if map_size(translations) > 0,
                      do: Map.put(m, "translations", translations),
                      else: m
                  end
                end)

              {rule_id, resolved}
          end)

        {section_id, expanded_section}
      end)

    Jason.encode!(%{"lang" => locale, "rules" => expanded}, pretty: true)
  end

  defp resolve_in_locale(locale, fun) do
    try do
      Bonfire.Common.Localise.put_locale(locale)
      fun.()
    rescue
      _ -> nil
    after
      :ok
    end
  end

  @doc """
  Exports only custom rules as an Elixir config keyword list snippet,
  promoting them to first-class template entries. Template rules are omitted.
  The output can be `Code.eval_string/1`'d and applied via `Settings.put`.
  """
  def export_elixir(rules, template) do
    promoted =
      Enum.reduce(rules, [], fn {section_id, section_data}, acc ->
        section_atom = safe_atom(section_id)
        customs = Map.get(section_data, "custom", [])

        if customs == [] do
          acc
        else
          # Find which top-level section this group belongs to
          {top_key, _} = find_top_section(section_atom, template)

          rule_entries =
            Enum.map(customs, fn custom ->
              rule_key = slugify(custom["name"])

              rule_val =
                %{name: custom["name"]}
                |> maybe_put(:qualifier, custom["qualifier"])
                |> maybe_put(:has_qualifier, custom["qualifier"] && true)
                |> maybe_put(:summary, custom["summary"])

              {rule_key, rule_val}
            end)

          deep_put(acc, [top_key, :sections, section_atom, :rules], rule_entries)
        end
      end)

    inspect(promoted, pretty: true, limit: :infinity, charlists: :as_lists)
  end

  # --- helpers ---

  defp safe_atom(str) when is_binary(str) do
    String.to_existing_atom(str)
  rescue
    ArgumentError -> String.to_atom(str)
  end

  defp safe_atom(a) when is_atom(a), do: a

  defp slugify(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
    |> safe_atom()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp find_top_section(section_atom, template) do
    Enum.find(template, {section_atom, []}, fn {_top_key, top_val} ->
      sections = Keyword.get(top_val, :sections, [])
      Keyword.has_key?(sections, section_atom)
    end)
  end

  defp deep_put(kwlist, [key], value) do
    existing = Keyword.get(kwlist, key, [])
    Keyword.put(kwlist, key, existing ++ value)
  end

  defp deep_put(kwlist, [key | rest], value) do
    existing = Keyword.get(kwlist, key, [])
    Keyword.put(kwlist, key, deep_put(existing, rest, value))
  end
end

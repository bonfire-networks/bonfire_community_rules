defmodule Bonfire.CommunityRules.Localise do
  @doc """
  Resolves display text for a template rule by traversing the config keyword list.
  Falls back to stringifying the rule_id atom.
  """
  def template_rule_text(section_id, rule_id, template) do
    get_in(template, [section_id, :rules, rule_id, :name]) ||
      nested_rule_name(section_id, rule_id, template) ||
      to_string(rule_id)
  end

  def template_rule_summary(section_id, rule_id, template) do
    get_in(template, [section_id, :rules, rule_id, :summary]) ||
      nested_rule_summary(section_id, rule_id, template)
  end

  defp nested_rule_name(section_id, rule_id, template) do
    Enum.find_value(template, fn {_top_key, top_val} ->
      sections = Keyword.get(top_val, :sections, [])
      get_in(sections, [section_id, :rules, rule_id, :name])
    end)
  end

  defp nested_rule_summary(section_id, rule_id, template) do
    Enum.find_value(template, fn {_top_key, top_val} ->
      sections = Keyword.get(top_val, :sections, [])
      get_in(sections, [section_id, :rules, rule_id, :summary])
    end)
  end

  @doc "Resolves display text for a custom rule using translations map, falling back to default name."
  def custom_rule_text(%{"name" => name} = rule, locale \\ locale()) do
    get_in(rule, ["translations", locale, "name"]) || name
  end

  def custom_rule_text(_, _), do: ""

  def custom_rule_summary(%{"summary" => summary} = rule, locale \\ locale()) do
    get_in(rule, ["translations", locale, "summary"]) || summary
  end

  def custom_rule_summary(_, _), do: nil

  defp locale do
    try do
      Bonfire.Common.Localise.get_locale()
    rescue
      _ -> "en"
    end
  end
end

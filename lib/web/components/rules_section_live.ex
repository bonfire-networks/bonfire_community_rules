defmodule Bonfire.CommunityRules.Web.RulesSectionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop parent_id, :string, required: true
  prop category_id, :string, default: nil
  prop section_id, :string, required: true
  prop section_data, :list, required: true
  prop mode, :atom, default: :entity
  prop checked, :map, default: %{}
  prop qualifiers, :map, default: %{}

  @doc "The instance's ticked rules, `key => qualifier`, shown ticked and locked on a group's rules."
  prop inherited, :map, default: %{}

  prop custom_rules, :map, default: %{}
  prop open_sections, :map, default: %{}
  prop add_custom_mode, :map, default: %{}
  prop read_only, :boolean, default: false

  @doc "Whether the section and its rules can be dragged and moved (an instance's or group's rules, not the template editor)."
  prop reorderable, :boolean, default: false

  @doc "Whether the section is first or last in its category, which turns off the matching move button."
  prop first, :boolean, default: false
  prop last, :boolean, default: false

  prop target, :any, required: true
end

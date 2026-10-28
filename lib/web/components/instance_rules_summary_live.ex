defmodule Bonfire.CommunityRules.Web.InstanceRulesSummaryLive do
  @moduledoc "The instance's rules as a compact numbered list. Shared by About and sign-up."
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.CommunityRules.Web.RulesDisplayBodyLive

  @doc "The rules sections to list (see `Bonfire.CommunityRules.get_instance_rules_sections/0`)."
  prop sections, :list, default: []

  @doc "DOM id of the section, also the prefix of its child ids."
  prop id, :string, default: "community-rules"

  @doc "Spacing from what comes before."
  prop class, :css_class, default: nil

  def rules_count(sections), do: sections |> RulesDisplayBodyLive.all_rules() |> length()
end

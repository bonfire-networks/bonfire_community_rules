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
    "Bonfire.CommunityRules",
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

  @doc "Returns the ExtraInfo struct for the local instance (creates an empty one if not yet saved)."
  def get_extra_info_for_instance do
    get_extra_info_by_id(Settings.instance_scope())
  end

  @doc "Returns the ExtraInfo struct for any entity by ID (returns an empty struct if not yet saved)."
  def get_extra_info_by_id(id) do
    repo().get(Bonfire.Data.Identity.ExtraInfo, id) ||
      %Bonfire.Data.Identity.ExtraInfo{id: id}
  end

  def repo, do: Config.repo()
end

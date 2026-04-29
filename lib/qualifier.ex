defmodule Bonfire.CommunityRules.Qualifier do
  use Bonfire.Common.Config
  alias Bonfire.Common.Types

  @doc "Returns all qualifier value strings, read from config."
  def values(configured_labels \\ configured_labels()) do
    configured_labels
    |> Keyword.keys()
    |> Enum.map(&to_string/1)
  end

  def valid?(q), do: q in values()

  @doc "Returns the display label for a qualifier value string, read from config."
  def label(value, configured_labels \\ configured_labels()) when is_binary(value) do
    key = Types.maybe_to_atom(value)
    Keyword.get(configured_labels, key, value)
  rescue
    ArgumentError -> value
  end

  def label(_, _), do: ""

  @doc "Returns [{value, label}] pairs for use in select/radio inputs."
  def options(configured_labels \\ configured_labels()),
    do: Enum.map(values(configured_labels), &{&1, label(&1, configured_labels)})

  def configured_labels do
    Config.get([:bonfire_community_rules, :qualifier_labels], nil) || default_labels()
  end

  defp default_labels do
    [
      yes: "Allowed",
      no: "Not allowed",
      with_label: "Allowed with labeling / disclosure",
      with_approval: "Approval required"
    ]
  end
end

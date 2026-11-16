defmodule Bonfire.CommunityRules.Web.RulesBuilderLive do
  use Bonfire.UI.Common.Web, :stateful_component
  use Bonfire.Common.Settings

  alias Bonfire.CommunityRules
  alias Bonfire.CommunityRules.Localise
  alias Bonfire.CommunityRules.Qualifier
  alias Bonfire.CommunityRules.Changesets
  alias Bonfire.CommunityRules.Export

  prop entity, :any, default: nil
  prop entity_id, :any, default: nil
  prop settings_scope, :any, default: nil
  prop template_rules, :any, default: nil
  prop read_only, :boolean, default: false
  prop entity_name, :string, default: nil
  prop title, :string, default: nil
  prop description, :string, default: nil
  prop show_header, :boolean, default: true

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    entity =
      assigns[:entity] ||
        case assigns[:entity_id] do
          nil -> nil
          id -> Bonfire.CommunityRules.get_extra_info_by_id(id)
        end

    mode = if is_nil(entity), do: :settings, else: :entity

    template =
      assigns[:template_rules] ||
        socket.assigns[:template] ||
        Settings.get(
          [:bonfire_community_rules, :template_rules],
          nil,
          scope: if(mode == :settings, do: assigns[:settings_scope], else: entity),
          skip_boundary_check: true
        ) ||
        Bonfire.Common.Config.get([:bonfire_community_rules, :template_rules], [])

    already_hydrated? = Map.has_key?(socket.assigns, :checked)

    {checked, qualifiers, custom_rules, own_order, inherited} =
      if already_hydrated? do
        {socket.assigns.checked, socket.assigns.qualifiers, socket.assigns.custom_rules,
         socket.assigns.own_order, socket.assigns.inherited}
      else
        if mode == :entity do
          hydrate_source =
            case e(entity, :extra_info, nil) do
              %Bonfire.Data.Identity.ExtraInfo{} = ei -> ei
              _ -> Bonfire.CommunityRules.get_extra_info_by_id(e(entity, :id, nil) || entity)
            end

          {checked, qualifiers, custom_rules} =
            Bonfire.CommunityRules.hydrate_entity(hydrate_source)

          {checked, qualifiers, custom_rules,
           Bonfire.CommunityRules.own_rules_order(hydrate_source), inherited_rules(entity)}
        else
          {%{}, %{}, %{}, %{}, %{}}
        end
      end

    {:ok,
     socket
     |> assign(
       entity: entity,
       mode: mode,
       template: template,
       checked: checked,
       qualifiers: qualifiers,
       custom_rules: custom_rules,
       inherited: inherited,
       open_sections: Map.get(socket.assigns, :open_sections, %{}),
       add_custom_mode: Map.get(socket.assigns, :add_custom_mode, %{}),
       export_format: Map.get(socket.assigns, :export_format),
       export_output: Map.get(socket.assigns, :export_output)
     )
     |> assign_order(own_order)}
  end

  # the instance's ticked rules, `key => qualifier`, which a group's rules can't untick. None on the instance's own page
  defp inherited_rules(entity) do
    if CommunityRules.instance?(entity) do
      %{}
    else
      {checked, qualifiers, _} =
        CommunityRules.hydrate_entity(CommunityRules.instance_extra_info())

      Map.new(checked, fn {key, _} -> {key, Map.get(qualifiers, key)} end)
    end
  end

  # the template in the order the entity shows it: its own, else the instance's, else the template's. The template editor keeps the template's
  defp assign_order(%{assigns: %{mode: :entity}} = socket, own_order) do
    assign(socket,
      own_order: own_order,
      ordered_template:
        CommunityRules.order_template(
          socket.assigns.template,
          CommunityRules.inherit_rules_order(own_order, socket.assigns.entity)
        )
    )
  end

  defp assign_order(socket, own_order),
    do: assign(socket, own_order: own_order, ordered_template: socket.assigns.template)

  def handle_event("toggle_section", %{"id" => section_id}, socket) do
    open = Map.get(socket.assigns.open_sections, section_id, false)

    {:noreply,
     assign(socket, open_sections: Map.put(socket.assigns.open_sections, section_id, !open))}
  end

  # the disabled box doesn't stop a crafted event
  def handle_event(event, %{"key" => key}, %{assigns: %{inherited: inherited}} = socket)
      when event in ["toggle_rule", "set_qualifier"] and is_map_key(inherited, key),
      do: {:noreply, socket}

  def handle_event("toggle_rule", %{"key" => key}, socket) do
    checked = socket.assigns.checked

    socket =
      if Map.get(checked, key) do
        assign(socket,
          checked: Map.delete(checked, key),
          qualifiers: Map.delete(socket.assigns.qualifiers, key)
        )
      else
        assign(socket, checked: Map.put(checked, key, true))
      end

    {:noreply, maybe_auto_save(socket)}
  end

  def handle_event("set_qualifier", %{"key" => key, "value" => value}, socket) do
    socket = assign(socket, qualifiers: Map.put(socket.assigns.qualifiers, key, value))
    {:noreply, maybe_auto_save(socket)}
  end

  def handle_event("toggle_add_custom", %{"id" => group_id}, socket) do
    add_custom_mode = Map.update(socket.assigns.add_custom_mode, group_id, true, &(!&1))
    {:noreply, assign(socket, add_custom_mode: add_custom_mode)}
  end

  def handle_event("add_custom_rule", %{"name" => name} = params, socket)
      when name != "" do
    group_id = Map.get(params, "group_id") || Map.get(params, "section_id")
    customs = Map.get(socket.assigns.custom_rules, group_id, [])
    next_id = (customs |> Enum.map(& &1["id"]) |> Enum.max(fn -> 0 end)) + 1
    new_rule = %{"id" => next_id, "name" => name}
    custom_rules = Map.put(socket.assigns.custom_rules, group_id, customs ++ [new_rule])
    add_custom_mode = Map.put(socket.assigns.add_custom_mode, group_id, false)
    socket = assign(socket, custom_rules: custom_rules, add_custom_mode: add_custom_mode)
    {:noreply, maybe_auto_save(socket)}
  end

  def handle_event("add_custom_rule", _params, socket), do: {:noreply, socket}

  def handle_event(
        "update_custom_rule",
        %{"section_id" => group_id, "rule_id" => rule_id_str, "name" => name},
        socket
      )
      when name != "" do
    rule_id = String.to_integer(rule_id_str)

    custom_rules =
      Map.update(socket.assigns.custom_rules, group_id, [], fn customs ->
        Enum.map(customs, fn rule ->
          if rule["id"] == rule_id, do: Map.put(rule, "name", name), else: rule
        end)
      end)

    {:noreply, socket |> assign(custom_rules: custom_rules) |> maybe_auto_save()}
  end

  def handle_event("update_custom_rule", _params, socket), do: {:noreply, socket}

  def handle_event("delete_custom_rule", %{"section" => group_id, "rule" => rule_id_str}, socket) do
    rule_id = String.to_integer(rule_id_str)

    custom_rules =
      Map.update(socket.assigns.custom_rules, group_id, [], fn customs ->
        Enum.reject(customs, &(&1["id"] == rule_id))
      end)

    {:noreply, socket |> assign(custom_rules: custom_rules) |> maybe_auto_save()}
  end

  def handle_event(
        "add_template_custom_rule",
        %{"section_id" => section_id, "name" => name} = params,
        socket
      )
      when name != "" do
    has_qualifier = Map.get(params, "has_qualifier") == "true"

    template =
      add_custom_to_template_section(socket.assigns.template, section_id, name, has_qualifier)

    {:noreply, socket |> assign(template: template) |> assign_order(socket.assigns.own_order)}
  end

  def handle_event("add_template_custom_rule", _params, socket), do: {:noreply, socket}

  def handle_event(
        "update_template_rule",
        %{"section_id" => section_id, "rule_id" => rule_id, "name" => name},
        socket
      )
      when name != "" do
    template = update_template_rule_name(socket.assigns.template, section_id, rule_id, name)
    {:noreply, socket |> assign(template: template) |> assign_order(socket.assigns.own_order)}
  end

  def handle_event("update_template_rule", _params, socket), do: {:noreply, socket}

  def handle_event("delete_template_rule", %{"section" => section_id, "rule" => rule_id}, socket) do
    template = delete_from_template_section(socket.assigns.template, section_id, rule_id)
    {:noreply, socket |> assign(template: template) |> assign_order(socket.assigns.own_order)}
  end

  # replaced by the clauses below: the Draggable hook sends `parent_item`, never `group_id`, and this didn't save
  # def handle_event(
  #       "reorder_custom_rules",
  #       %{"group_id" => group_id, "target_order" => order},
  #       socket
  #     ) do
  #   customs = Map.get(socket.assigns.custom_rules, group_id, [])
  #
  #   reordered =
  #     order
  #     |> Enum.map(fn id_str ->
  #       id = String.to_integer(id_str)
  #       Enum.find(customs, &(&1["id"] == id))
  #     end)
  #     |> Enum.reject(&is_nil/1)
  #
  #   custom_rules = Map.put(socket.assigns.custom_rules, group_id, reordered)
  #   {:noreply, assign(socket, custom_rules: custom_rules)}
  # end

  # replaced by "move" below, which moves every kind and saves
  # def handle_event(
  #       "move_custom_rule",
  #       %{"section_id" => group_id, "rule_id" => rule_id_str, "direction" => direction},
  #       socket
  #     ) do
  #   rule_id = String.to_integer(rule_id_str)
  #   customs = Map.get(socket.assigns.custom_rules, group_id, [])
  #   index = Enum.find_index(customs, &(&1["id"] == rule_id))
  #
  #   target_index =
  #     case {direction, index} do
  #       {_, nil} -> nil
  #       {"up", i} when i > 0 -> i - 1
  #       {"down", i} when i < length(customs) - 1 -> i + 1
  #       _ -> nil
  #     end
  #
  #   if is_nil(target_index) do
  #     {:noreply, socket}
  #   else
  #     a = Enum.at(customs, index)
  #     b = Enum.at(customs, target_index)
  #
  #     reordered =
  #       customs
  #       |> List.replace_at(index, b)
  #       |> List.replace_at(target_index, a)
  #
  #     {:noreply,
  #      assign(socket, custom_rules: Map.put(socket.assigns.custom_rules, group_id, reordered))}
  #   end
  # end

  # what the Draggable hook sends when a drag ends: the list's new order of `data-item`s, and the list's `data-parent`
  def handle_event("reorder_categories", %{"target_order" => ids}, socket),
    do: {:noreply, socket |> put_own_order("category", nil, ids) |> maybe_auto_save()}

  def handle_event(
        "reorder_sections",
        %{"parent_item" => category, "target_order" => ids},
        socket
      ),
      do: {:noreply, socket |> put_own_order("section", category, ids) |> maybe_auto_save()}

  def handle_event(
        "reorder_template_rules",
        %{"parent_item" => section, "target_order" => ids},
        socket
      ),
      do: {:noreply, socket |> put_own_order("rule", section, ids) |> maybe_auto_save()}

  def handle_event(
        "reorder_custom_rules",
        %{"parent_item" => section, "target_order" => ids},
        socket
      ),
      do: {:noreply, socket |> put_custom_order(section, ids) |> maybe_auto_save()}

  # the up and down buttons, for whoever can't drag
  def handle_event(
        "move",
        %{"kind" => "custom", "parent" => section, "item" => item, "direction" => direction},
        socket
      ) do
    ids =
      socket.assigns.custom_rules
      |> Map.get(section, [])
      |> Enum.map(&to_string(&1["id"]))

    {:noreply,
     socket |> put_custom_order(section, move_in(ids, item, direction)) |> maybe_auto_save()}
  end

  def handle_event(
        "move",
        %{"kind" => kind, "item" => item, "direction" => direction} = params,
        socket
      ) do
    ids = current_ids(socket.assigns.ordered_template, kind, params["parent"])

    {:noreply,
     socket
     |> put_own_order(kind, params["parent"], move_in(ids, item, direction))
     |> maybe_auto_save()}
  end

  def handle_event("show_export", %{"format" => format}, socket) do
    rules = build_rules_map(socket.assigns)
    template = socket.assigns.template

    output =
      case format do
        "json" -> Export.export_json(rules, template)
        "elixir" -> Export.export_elixir(rules, template)
        _ -> ""
      end

    {:noreply, assign(socket, export_format: format, export_output: output)}
  end

  def handle_event("close_export", _params, socket) do
    {:noreply, assign(socket, export_format: nil, export_output: nil)}
  end

  def handle_event("save", _params, %{assigns: %{mode: :settings}} = socket) do
    template = build_settings_template(socket.assigns)
    scope = socket.assigns.settings_scope

    Settings.put(
      [:bonfire_community_rules, :template_rules],
      template,
      scope: scope,
      skip_boundary_check: true
    )

    {:noreply, assign_flash(socket, :info, l("Template saved"))}
  end

  defp maybe_auto_save(%{assigns: %{mode: :entity}} = socket), do: persist_entity_rules(socket)
  defp maybe_auto_save(socket), do: socket

  # --- ordering helpers ---

  defp put_own_order(socket, kind, parent, ids) do
    ids = Enum.reject(ids || [], &is_nil/1)
    own = socket.assigns.own_order

    own =
      case kind do
        "category" -> Map.put(own, "categories", ids)
        "section" -> Map.update(own, "sections", %{parent => ids}, &Map.put(&1, parent, ids))
        "rule" -> Map.update(own, "rules", %{parent => ids}, &Map.put(&1, parent, ids))
      end

    assign_order(socket, own)
  end

  defp put_custom_order(socket, section, ids) do
    customs = Map.get(socket.assigns.custom_rules, section, [])
    by_id = Map.new(customs, &{to_string(&1["id"]), &1})
    listed = ids |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.flat_map(&List.wrap(by_id[&1]))
    reordered = listed ++ Enum.reject(customs, &(&1 in listed))

    assign(socket, custom_rules: Map.put(socket.assigns.custom_rules, section, reordered))
  end

  # the ids of one list, in the order it shows
  defp current_ids(template, "category", _),
    do: template |> Keyword.keys() |> Enum.map(&to_string/1)

  defp current_ids(template, "section", category) do
    Enum.find_value(template, [], fn {id, data} ->
      if to_string(id) == category,
        do: data |> Keyword.get(:sections, []) |> Keyword.keys() |> Enum.map(&to_string/1)
    end)
  end

  defp current_ids(template, "rule", section) do
    template
    |> Enum.flat_map(fn {_, data} -> Keyword.get(data, :sections, []) end)
    |> Enum.find_value([], fn {id, data} ->
      if to_string(id) == section,
        do: data |> Keyword.get(:rules, []) |> Keyword.keys() |> Enum.map(&to_string/1)
    end)
  end

  @doc """
  The id prefix of an item's move buttons. Rule ids repeat across sections, so a rule's names its section. Category and section ids are unique on their own.

      iex> Bonfire.CommunityRules.Web.RulesBuilderLive.move_id("b", "rule", "civility", "no_spam")
      "b-move-rule-civility-no_spam"

      iex> Bonfire.CommunityRules.Web.RulesBuilderLive.move_id("b", "section", "behavior", "civility")
      "b-move-section-civility"
  """
  def move_id(parent_id, kind, parent, item) when kind in ["rule", "custom"],
    do: "#{parent_id}-move-#{kind}-#{parent}-#{item}"

  def move_id(parent_id, kind, _parent, item), do: "#{parent_id}-move-#{kind}-#{item}"

  @doc """
  Swaps an id with its neighbour above or below. At either end, or when the id isn't there, the list stays as it is.

      iex> Bonfire.CommunityRules.Web.RulesBuilderLive.move_in(["a", "b", "c"], "b", "up")
      ["b", "a", "c"]

      iex> Bonfire.CommunityRules.Web.RulesBuilderLive.move_in(["a", "b"], "b", "down")
      ["a", "b"]
  """
  def move_in(ids, item, direction) do
    index = Enum.find_index(ids, &(&1 == item))

    target =
      case {direction, index} do
        {_, nil} -> nil
        {"up", i} when i > 0 -> i - 1
        {"down", i} when i < length(ids) - 1 -> i + 1
        _ -> nil
      end

    if target,
      do: ids |> List.replace_at(index, Enum.at(ids, target)) |> List.replace_at(target, item),
      else: ids
  end

  defp persist_entity_rules(socket) do
    case CommunityRules.save_rules(
           socket.assigns.entity,
           build_rules_map(socket.assigns),
           socket.assigns.own_order
         ) do
      {:ok, _saved} -> socket
      _ -> assign_flash(socket, :error, l("Could not save rules"))
    end
  end

  # --- template mutation helpers ---

  defp add_custom_to_template_section(template, section_id, name, has_qualifier) do
    update_section_in_template(template, section_id, fn section_data ->
      rules = Keyword.get(section_data, :rules, [])
      next_id = (rules |> Keyword.keys() |> length()) + 1
      rule_id = String.to_atom("custom_#{next_id}")
      rule_meta = %{name: name, has_qualifier: has_qualifier}
      Keyword.put(section_data, :rules, rules ++ [{rule_id, rule_meta}])
    end)
  end

  defp update_template_rule_name(template, section_id, rule_id, name) do
    rule_atom = String.to_existing_atom(rule_id)

    update_section_in_template(template, section_id, fn section_data ->
      rules =
        Keyword.get(section_data, :rules, [])
        |> Enum.map(fn {k, meta} ->
          if k == rule_atom, do: {k, Map.put(meta, :name, name)}, else: {k, meta}
        end)

      Keyword.put(section_data, :rules, rules)
    end)
  rescue
    ArgumentError -> template
  end

  defp delete_from_template_section(template, section_id, rule_id) do
    rule_atom = String.to_existing_atom(rule_id)

    update_section_in_template(template, section_id, fn section_data ->
      rules = Keyword.get(section_data, :rules, []) |> Keyword.delete(rule_atom)
      Keyword.put(section_data, :rules, rules)
    end)
  rescue
    ArgumentError -> template
  end

  defp update_section_in_template(template, section_id, fun) do
    section_atom =
      try do
        String.to_existing_atom(section_id)
      rescue
        ArgumentError -> nil
      end

    Enum.map(template, fn {top_key, top_val} ->
      sections = Keyword.get(top_val, :sections, [])

      updated_sections =
        Enum.map(sections, fn {sid, sdata} ->
          if to_string(sid) == section_id or sid == section_atom,
            do: {sid, fun.(sdata)},
            else: {sid, sdata}
        end)

      {top_key, Keyword.put(top_val, :sections, updated_sections)}
    end)
  end

  # --- helpers ---

  defp build_rules_map(assigns) do
    Enum.reduce(assigns.checked, %{}, fn {key, _}, acc ->
      [group_id, rule_id] = String.split(key, ":", parts: 2)
      qualifier = Map.get(assigns.qualifiers, key)
      rule_data = if qualifier, do: %{"qualifier" => qualifier}, else: %{}
      group = Map.get(acc, group_id, %{})
      Map.put(acc, group_id, Map.put(group, rule_id, rule_data))
    end)
    |> then(fn rules ->
      Enum.reduce(assigns.custom_rules, rules, fn {group_id, customs}, acc ->
        group = Map.get(acc, group_id, %{})
        Map.put(acc, group_id, Map.put(group, "custom", customs))
      end)
    end)
  end

  defp build_settings_template(assigns) do
    assigns.template
  end

  @doc "Count checked rules in a group."
  def count_selected(checked, group_id) do
    Enum.count(checked, fn {key, _} -> String.starts_with?(key, "#{group_id}:") end)
  end

  @doc "Build list of {group_name, [rule]} for the summary panel."
  def selected_summary(checked, qualifiers, custom_rules, template) do
    Bonfire.CommunityRules.selected_rules(checked, qualifiers, custom_rules, template)
    |> Enum.flat_map(fn %{sections: sections} ->
      Enum.map(sections, fn %{name: name, rules: rules} -> {name, rules} end)
    end)
  end
end

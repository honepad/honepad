defmodule Simulation do
  defstruct backends: [], by_id: %{}, cursor: 0, sticky_map: %{}, use_least: false

  def new, do: %__MODULE__{}

  def add_backend(sim, backend_id) do
    if Map.has_key?(sim.by_id, backend_id) do
      {"false", sim}
    else
      item = %{backend_id: backend_id, health: true, weight: 1, inflight: 0}
      idx = length(sim.backends)

      {"true",
       %{
         sim
         | backends: sim.backends ++ [item],
           by_id: Map.put(sim.by_id, backend_id, idx)
       }}
    end
  end

  def set_health(sim, backend_id, flag) do
    cond do
      not Map.has_key?(sim.by_id, backend_id) or flag not in [0, 1] ->
        {"invalid_request", sim}

      true ->
        idx = Map.fetch!(sim.by_id, backend_id)
        item = Enum.at(sim.backends, idx)
        item = %{item | health: flag == 1}
        sim = %{sim | backends: List.replace_at(sim.backends, idx, item)}
        {"true", reset_cycle(sim)}
    end
  end

  def set_weight(sim, backend_id, weight) do
    cond do
      not Map.has_key?(sim.by_id, backend_id) or weight <= 0 ->
        {"invalid_request", sim}

      true ->
        idx = Map.fetch!(sim.by_id, backend_id)
        item = Enum.at(sim.backends, idx)
        item = %{item | weight: weight}
        sim = %{sim | backends: List.replace_at(sim.backends, idx, item)}
        {"true", reset_cycle(sim)}
    end
  end

  def route(sim) do
    take(sim)
  end

  def sticky(sim, client_id) do
    bound = Map.get(sim.sticky_map, client_id)

    case bound && Map.get(sim.by_id, bound) do
      idx when is_integer(idx) ->
        item = Enum.at(sim.backends, idx)

        if item.health do
          item = %{item | inflight: item.inflight + 1}
          {item.backend_id, %{sim | backends: List.replace_at(sim.backends, idx, item)}}
        else
          rebound(sim, client_id)
        end

      _ ->
        rebound(sim, client_id)
    end
  end

  def done(sim, backend_id) do
    case Map.get(sim.by_id, backend_id) do
      nil ->
        {"invalid_request", sim}

      idx ->
        item = Enum.at(sim.backends, idx)

        if item.inflight <= 0 do
          {"invalid_request", sim}
        else
          item = %{item | inflight: item.inflight - 1}

          {"true",
           %{sim | backends: List.replace_at(sim.backends, idx, item), use_least: true}}
        end
    end
  end

  defp rebound(sim, client_id) do
    {chosen, sim} = take(sim)

    if chosen != "" do
      {chosen, %{sim | sticky_map: Map.put(sim.sticky_map, client_id, chosen)}}
    else
      {chosen, sim}
    end
  end

  defp reset_cycle(sim) do
    backends = Enum.map(sim.backends, fn item -> %{item | inflight: 0} end)
    %{sim | cursor: 0, use_least: false, backends: backends}
  end

  defp tickets(items) do
    Enum.flat_map(items, fn item -> List.duplicate(item, item.weight) end)
  end

  defp pick(sim) do
    healthy = Enum.filter(sim.backends, & &1.health)

    if healthy == [] do
      {nil, sim}
    else
      pool =
        if sim.use_least do
          least = Enum.min_by(healthy, & &1.inflight).inflight
          Enum.filter(healthy, fn item -> item.inflight == least end)
        else
          healthy
        end

      tix = tickets(pool)

      if tix == [] do
        {nil, sim}
      else
        chosen = Enum.at(tix, rem(sim.cursor, length(tix)))
        {chosen, %{sim | cursor: sim.cursor + 1}}
      end
    end
  end

  defp take(sim) do
    {item, sim} = pick(sim)

    if item == nil do
      {"", sim}
    else
      idx = Map.fetch!(sim.by_id, item.backend_id)
      stored = Enum.at(sim.backends, idx)
      stored = %{stored | inflight: stored.inflight + 1}
      {stored.backend_id, %{sim | backends: List.replace_at(sim.backends, idx, stored)}}
    end
  end
end

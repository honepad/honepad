defmodule Simulation do
  defstruct keys: %{}

  def new, do: %__MODULE__{}

  def allow(sim, key, timestamp) do
    allow_weighted(sim, key, 1, timestamp)
  end

  def configure(sim, key, limit, window) do
    if limit <= 0 or window <= 0 do
      {"invalid_request", sim}
    else
      item = %{limit: limit, window: window, window_id: nil, used: 0}
      {"true", put_key(sim, key, item)}
    end
  end

  def remaining(sim, key, timestamp) do
    {item, sim} = state(sim, key)
    used = used_at(item, timestamp, false)
    {Integer.to_string(item.limit - used), sim}
  end

  def allow_weighted(sim, key, cost, timestamp) do
    if cost <= 0 do
      {"invalid_request", sim}
    else
      {item, sim} = state(sim, key)
      item = persist_window(item, timestamp)
      if item.used + cost > item.limit do
        {"false", put_key(sim, key, item)}
      else
        item = %{item | used: item.used + cost}
        {"true", put_key(sim, key, item)}
      end
    end
  end

  defp new_key do
    %{limit: 3, window: 10, window_id: nil, used: 0}
  end

  defp state(sim, key) do
    case Map.get(sim.keys, key) do
      nil ->
        item = new_key()
        {item, put_key(sim, key, item)}

      item ->
        {item, sim}
    end
  end

  defp persist_window(item, timestamp) do
    window_id = div(timestamp, item.window)

    if item.window_id == nil or window_id != item.window_id do
      %{item | window_id: window_id, used: 0}
    else
      item
    end
  end

  defp used_at(item, timestamp, persist) do
    window_id = div(timestamp, item.window)

    if item.window_id == nil or window_id != item.window_id do
      _ = persist
      0
    else
      item.used
    end
  end

  defp put_key(sim, key, item) do
    %{sim | keys: Map.put(sim.keys, key, item)}
  end
end

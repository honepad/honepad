defmodule Simulation do
  defstruct items: %{}

  def new, do: %__MODULE__{}

  def create_item(sim, sku, name) do
    if Map.has_key?(sim.items, sku) do
      {"false", sim}
    else
      item = new_item(sku, name)
      {"true", %{sim | items: Map.put(sim.items, sku, item)}}
    end
  end

  def stock(sim, sku, delta) do
    case Map.get(sim.items, sku) do
      nil ->
        {"", sim}

      item ->
        nxt = item.qty + delta

        if nxt < item.reserved do
          {"invalid_request", sim}
        else
          item = %{item | qty: nxt}
          {Integer.to_string(item.qty), put_item(sim, sku, item)}
        end
    end
  end

  def get_qty(sim, sku) do
    case Map.get(sim.items, sku) do
      nil -> {"", sim}
      item -> {Integer.to_string(item.qty), sim}
    end
  end

  def list_low(sim, threshold) do
    result =
      sim.items
      |> Map.values()
      |> Enum.filter(fn item -> item.qty <= threshold end)
      |> Enum.sort_by(fn item -> {item.qty, item.sku} end)
      |> Enum.map_join(", ", fn item -> "#{item.sku}(#{item.qty})" end)

    {result, sim}
  end

  def reserve(sim, sku, n) do
    case Map.get(sim.items, sku) do
      nil ->
        {"invalid_request", sim}

      _item when n <= 0 ->
        {"invalid_request", sim}

      item ->
        if item.reserved + n > item.qty do
          {"invalid_request", sim}
        else
          item = %{item | reserved: item.reserved + n}
          {"true", put_item(sim, sku, item)}
        end
    end
  end

  def release(sim, sku, n) do
    case Map.get(sim.items, sku) do
      nil ->
        {"invalid_request", sim}

      _item when n <= 0 ->
        {"invalid_request", sim}

      item ->
        if n > item.reserved do
          {"invalid_request", sim}
        else
          item = %{item | reserved: item.reserved - n}
          {"true", put_item(sim, sku, item)}
        end
    end
  end

  def ship(sim, sku, n) do
    case Map.get(sim.items, sku) do
      nil ->
        {"invalid_request", sim}

      _item when n <= 0 ->
        {"invalid_request", sim}

      item ->
        if n > item.reserved do
          {"invalid_request", sim}
        else
          item = %{item | reserved: item.reserved - n, qty: item.qty - n}
          {"true", put_item(sim, sku, item)}
        end
    end
  end

  defp new_item(sku, name) do
    %{sku: sku, name: name, qty: 0, reserved: 0}
  end

  defp put_item(sim, sku, item) do
    %{sim | items: Map.put(sim.items, sku, item)}
  end
end

defmodule Simulation do
  defstruct subs: %{}, inbox_map: %{}, retained: %{}

  def new, do: %__MODULE__{}

  def subscribe(sim, topic, client) do
    clients = Map.get(sim.subs, topic, [])

    if client in clients do
      {"false", sim}
    else
      clients = clients ++ [client]
      sim = %{sim | subs: Map.put(sim.subs, topic, clients)}

      sim =
        case Map.get(sim.retained, topic) do
          nil ->
            sim

          message ->
            items = Map.get(sim.inbox_map, client, [])
            %{sim | inbox_map: Map.put(sim.inbox_map, client, items ++ ["#{topic}:#{message}"])}
        end

      {"true", sim}
    end
  end

  def unsubscribe(sim, topic, client) do
    case Map.get(sim.subs, topic) do
      nil ->
        {"false", sim}

      clients ->
        if client in clients do
          clients = List.delete(clients, client)

          subs =
            if clients == [] do
              Map.delete(sim.subs, topic)
            else
              Map.put(sim.subs, topic, clients)
            end

          {"true", %{sim | subs: subs}}
        else
          {"false", sim}
        end
    end
  end

  def publish(sim, topic, message) do
    clients = Map.get(sim.subs, topic, [])
    payload = "#{topic}:#{message}"

    inbox_map =
      Enum.reduce(clients, sim.inbox_map, fn client, acc ->
        items = Map.get(acc, client, [])
        Map.put(acc, client, items ++ [payload])
      end)

    {Integer.to_string(length(clients)), %{sim | inbox_map: inbox_map}}
  end

  def inbox(sim, client) do
    items = Map.get(sim.inbox_map, client, [])
    {Enum.join(items, ", "), sim}
  end

  def list_topics(sim) do
    result = sim.subs |> Map.keys() |> Enum.sort() |> Enum.join(", ")
    {result, sim}
  end

  def subscribers(sim, topic) do
    result = sim.subs |> Map.get(topic, []) |> Enum.sort() |> Enum.join(", ")
    {result, sim}
  end

  def peek(sim, client) do
    case Map.get(sim.inbox_map, client, []) do
      [] -> {"", sim}
      [first | _] -> {first, sim}
    end
  end

  def ack(sim, client, n) do
    cond do
      n <= 0 or not Map.has_key?(sim.inbox_map, client) ->
        {"invalid_request", sim}

      n > length(Map.get(sim.inbox_map, client)) ->
        {"invalid_request", sim}

      true ->
        items = Enum.drop(Map.get(sim.inbox_map, client), n)
        sim = %{sim | inbox_map: Map.put(sim.inbox_map, client, items)}
        {Integer.to_string(length(items)), sim}
    end
  end

  def retain(sim, topic, message) do
    {"", %{sim | retained: Map.put(sim.retained, topic, message)}}
  end
end

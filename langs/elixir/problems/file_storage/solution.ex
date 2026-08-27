defmodule Simulation do
  defstruct files: %{}, capacity: %{"admin" => nil}, backups: %{}

  def new, do: %__MODULE__{}

  def add_file(sim, name, size) do
    if Map.has_key?(sim.files, name) do
      {"false", sim}
    else
      {"true", put_file(sim, name, size, "admin")}
    end
  end

  def get_file_size(sim, name) do
    case Map.get(sim.files, name) do
      nil -> {"", sim}
      item -> {Integer.to_string(item.size), sim}
    end
  end

  def delete_file(sim, name) do
    case Map.pop(sim.files, name) do
      {nil, _} -> {"", sim}
      {item, files} -> {Integer.to_string(item.size), %{sim | files: files}}
    end
  end

  def copy_file(sim, source, dest) do
    case Map.get(sim.files, source) do
      nil ->
        {"", sim}

      src ->
        if source == dest do
          {Integer.to_string(src.size), sim}
        else
          dest_item = Map.get(sim.files, dest)
          owner = if dest_item == nil, do: src.owner, else: dest_item.owner
          extra = if dest_item == nil, do: src.size, else: src.size - dest_item.size
          rem = remaining(sim, owner)

          cond do
            rem != nil and extra > rem ->
              {"", sim}

            dest_item == nil ->
              {Integer.to_string(src.size), put_file(sim, dest, src.size, owner)}

            true ->
              files = Map.put(sim.files, dest, %{dest_item | size: src.size})
              {Integer.to_string(src.size), %{sim | files: files}}
          end
        end
    end
  end

  def get_n_largest(sim, prefix, n) do
    result =
      sim.files
      |> Map.values()
      |> Enum.filter(fn item -> String.starts_with?(item.name, prefix) end)
      |> Enum.sort_by(fn item -> {-item.size, item.name} end)
      |> Enum.take(n)
      |> Enum.map_join(", ", fn item -> "#{item.name}(#{item.size})" end)

    {result, sim}
  end

  def add_user(sim, user_id, capacity) do
    if Map.has_key?(sim.capacity, user_id) do
      {"false", sim}
    else
      {"true", %{sim | capacity: Map.put(sim.capacity, user_id, capacity)}}
    end
  end

  def add_file_by(sim, user_id, name, size) do
    cond do
      not Map.has_key?(sim.capacity, user_id) or Map.has_key?(sim.files, name) ->
        {"", sim}

      remaining(sim, user_id) != nil and size > remaining(sim, user_id) ->
        {"", sim}

      true ->
        sim = put_file(sim, name, size, user_id)
        left = remaining(sim, user_id)
        {if(left == nil, do: "", else: Integer.to_string(left)), sim}
    end
  end

  def merge_user(sim, user_id1, user_id2) do
    cap1 = Map.get(sim.capacity, user_id1)
    cap2 = Map.get(sim.capacity, user_id2)

    cond do
      user_id1 == user_id2 ->
        {"", sim}

      cap1 == nil or cap2 == nil ->
        {"", sim}

      true ->
        files =
          Map.new(sim.files, fn {name, item} ->
            item =
              if item.owner == user_id2 do
                %{item | owner: user_id1}
              else
                item
              end

            {name, item}
          end)

        sim = %{
          sim
          | files: files,
            capacity:
              sim.capacity
              |> Map.put(user_id1, cap1 + cap2)
              |> Map.delete(user_id2),
            backups: Map.delete(sim.backups, user_id2)
        }

        left = remaining(sim, user_id1)
        {if(left == nil, do: "", else: Integer.to_string(left)), sim}
    end
  end

  def backup_user(sim, user_id) do
    if not Map.has_key?(sim.capacity, user_id) do
      {"", sim}
    else
      snapshot =
        sim.files
        |> Map.values()
        |> Enum.filter(fn item -> item.owner == user_id end)
        |> Map.new(fn item -> {item.name, item.size} end)

      sim = %{sim | backups: Map.put(sim.backups, user_id, snapshot)}
      {Integer.to_string(map_size(snapshot)), sim}
    end
  end

  def restore_user(sim, user_id) do
    if not Map.has_key?(sim.capacity, user_id) do
      {"", sim}
    else
      files =
        sim.files
        |> Enum.reject(fn {_name, item} -> item.owner == user_id end)
        |> Map.new()

      sim = %{sim | files: files}

      case Map.get(sim.backups, user_id) do
        nil ->
          {"0", sim}

        snapshot ->
          {restored, sim} =
            Enum.reduce(snapshot, {0, sim}, fn {name, size}, {count, acc} ->
              cond do
                Map.has_key?(acc.files, name) ->
                  {count, acc}

                remaining(acc, user_id) != nil and size > remaining(acc, user_id) ->
                  {count, acc}

                true ->
                  {count + 1, put_file(acc, name, size, user_id)}
              end
            end)

          {Integer.to_string(restored), sim}
      end
    end
  end

  defp put_file(sim, name, size, owner) do
    %{sim | files: Map.put(sim.files, name, %{name: name, size: size, owner: owner})}
  end

  defp used(sim, user_id) do
    sim.files
    |> Map.values()
    |> Enum.reduce(0, fn item, acc ->
      if item.owner == user_id, do: acc + item.size, else: acc
    end)
  end

  defp remaining(sim, user_id) do
    case Map.get(sim.capacity, user_id) do
      nil -> nil
      cap -> cap - used(sim, user_id)
    end
  end
end

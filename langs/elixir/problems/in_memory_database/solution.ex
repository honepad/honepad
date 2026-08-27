defmodule InMemoryDatabase do
  defstruct database: %{}, backup_timestamps: [], backup_states: []

  def new, do: %__MODULE__{}

  def set(db, key, field, value), do: {"" , set_internal(db, key, field, value, nil)}

  def get(db, key, field) do
    case get_field(db, key, field) do
      nil -> {"", db}
      {value, _expiry} -> {value, db}
    end
  end

  def delete(db, key, field) do
    case get_field(db, key, field) do
      nil ->
        {"false", db}

      _ ->
        fields = Map.delete(db.database[key], field)
        {"true", %{db | database: Map.put(db.database, key, fields)}}
    end
  end

  def scan(db, key) do
    {join_fields(Map.get(db.database, key, %{})), db}
  end

  def scan_by_prefix(db, key, prefix) do
    fields =
      db.database
      |> Map.get(key, %{})
      |> Enum.filter(fn {field, _} -> String.starts_with?(field, prefix) end)
      |> Map.new()

    {join_fields(fields), db}
  end

  def set_at(db, key, field, value, _timestamp) do
    {"" , set_internal(db, key, field, value, nil)}
  end

  def set_at_with_ttl(db, key, field, value, timestamp, ttl) do
    {"" , set_internal(db, key, field, value, timestamp + ttl)}
  end

  def delete_at(db, key, field, timestamp) do
    if alive?(db, key, field, timestamp) do
      fields = Map.delete(db.database[key], field)
      {"true", %{db | database: Map.put(db.database, key, fields)}}
    else
      {"false", db}
    end
  end

  def get_at(db, key, field, timestamp) do
    if alive?(db, key, field, timestamp) do
      {value, _expiry} = db.database[key][field]
      {value, db}
    else
      {"", db}
    end
  end

  def scan_at(db, key, timestamp) do
    fields =
      db.database
      |> Map.get(key, %{})
      |> Enum.filter(fn {field, _} -> alive?(db, key, field, timestamp) end)
      |> Enum.map(fn {field, {value, _}} -> {field, value} end)
      |> Enum.sort()

    {Enum.map_join(fields, ", ", fn {field, value} -> "#{field}(#{value})" end), db}
  end

  def scan_by_prefix_at(db, key, prefix, timestamp) do
    fields =
      db.database
      |> Map.get(key, %{})
      |> Enum.filter(fn {field, _} ->
        String.starts_with?(field, prefix) and alive?(db, key, field, timestamp)
      end)
      |> Enum.map(fn {field, {value, _}} -> {field, value} end)
      |> Enum.sort()

    {Enum.map_join(fields, ", ", fn {field, value} -> "#{field}(#{value})" end), db}
  end

  def backup(db, timestamp) do
    state =
      Enum.reduce(db.database, %{}, fn {key, fields}, acc ->
        kept =
          Enum.reduce(fields, %{}, fn {field, {value, expiry}}, inner ->
            if alive?(db, key, field, timestamp) do
              remaining = if expiry == nil, do: nil, else: expiry - timestamp
              Map.put(inner, field, {value, remaining})
            else
              inner
            end
          end)

        if kept == %{} do
          acc
        else
          Map.put(acc, key, kept)
        end
      end)

    db = %{
      db
      | backup_timestamps: db.backup_timestamps ++ [timestamp],
        backup_states: db.backup_states ++ [state]
    }

    {Integer.to_string(map_size(state)), db}
  end

  def restore(db, timestamp, timestamp_to_restore) do
    idx =
      db.backup_timestamps
      |> Enum.with_index()
      |> Enum.filter(fn {ts, _} -> ts <= timestamp_to_restore end)
      |> List.last()
      |> elem(1)

    backup_state = Enum.at(db.backup_states, idx)

    db =
      Enum.reduce(backup_state, %{db | database: %{}}, fn {key, fields}, acc ->
        Enum.reduce(fields, acc, fn {field, {value, remaining}}, inner ->
          expiry = if remaining == nil, do: nil, else: timestamp + remaining
          set_internal(inner, key, field, value, expiry)
        end)
      end)

    {"", db}
  end

  defp set_internal(db, key, field, value, expiry) do
    fields = Map.get(db.database, key, %{})
    %{db | database: Map.put(db.database, key, Map.put(fields, field, {value, expiry}))}
  end

  defp get_field(db, key, field) do
    case Map.get(db.database, key) do
      nil -> nil
      fields -> Map.get(fields, field)
    end
  end

  defp alive?(db, key, field, timestamp) do
    case get_field(db, key, field) do
      nil -> false
      {_value, nil} -> true
      {_value, expiry} -> timestamp < expiry
    end
  end

  defp join_fields(fields) do
    fields
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join(", ", fn {field, {value, _}} -> "#{field}(#{value})" end)
  end
end

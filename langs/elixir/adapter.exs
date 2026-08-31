#!/usr/bin/env elixir
# argv: elixir adapter.exs <src> <class> <cases.json>
# Code.compile_file the solution, instantiate Simulation or InMemoryDatabase,
# call snake_case methods, compare JSON encodings.

defmodule MiniJson do
  def decode(bin) when is_binary(bin) do
    {val, rest} = value(skip(bin))
    "" = skip(rest)
    val
  end

  def encode(val), do: IO.iodata_to_binary(enc(val))

  defp skip(<<c, rest::binary>>) when c in [?\s, ?\t, ?\n, ?\r], do: skip(rest)
  defp skip(bin), do: bin

  defp value(<<"null", rest::binary>>), do: {nil, rest}
  defp value(<<"true", rest::binary>>), do: {true, rest}
  defp value(<<"false", rest::binary>>), do: {false, rest}
  defp value(<<?[, rest::binary>>), do: parse_array(skip(rest), [])
  defp value(<<?{, rest::binary>>), do: parse_object(skip(rest), %{})
  defp value(<<?", rest::binary>>), do: parse_string(rest, [])

  defp value(<<c, _::binary>> = bin)
       when c in [?-, ?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9] do
    parse_number(bin)
  end

  defp parse_array(<<?], rest::binary>>, acc), do: {Enum.reverse(acc), rest}

  defp parse_array(bin, acc) do
    {val, rest} = value(skip(bin))
    rest = skip(rest)

    case rest do
      <<?,, rest::binary>> -> parse_array(skip(rest), [val | acc])
      <<?], rest::binary>> -> {Enum.reverse([val | acc]), rest}
    end
  end

  defp parse_object(<<?}, rest::binary>>, acc), do: {acc, rest}

  defp parse_object(<<?", rest::binary>>, acc) do
    {key, rest} = parse_string(rest, [])
    <<?:, rest::binary>> = skip(rest)
    {val, rest} = value(skip(rest))
    rest = skip(rest)
    acc = Map.put(acc, key, val)

    case rest do
      <<?,, rest::binary>> -> parse_object(skip(rest), acc)
      <<?}, rest::binary>> -> {acc, rest}
    end
  end

  defp parse_string(<<?", rest::binary>>, acc) do
    {List.to_string(Enum.reverse(acc)), rest}
  end

  defp parse_string(<<?\\, ?u, a, b, c, d, rest::binary>>, acc) do
    code = String.to_integer(<<a, b, c, d>>, 16)
    parse_string(rest, [code | acc])
  end

  defp parse_string(<<?\\, c, rest::binary>>, acc) do
    ch =
      case c do
        ?" -> ?"
        ?\\ -> ?\\
        ?/ -> ?/
        ?b -> ?\b
        ?f -> ?\f
        ?n -> ?\n
        ?r -> ?\r
        ?t -> ?\t
      end

    parse_string(rest, [ch | acc])
  end

  defp parse_string(<<c::utf8, rest::binary>>, acc), do: parse_string(rest, [c | acc])

  defp parse_number(<<?-, rest::binary>>) do
    {n, rest} = parse_number(rest)
    {-n, rest}
  end

  defp parse_number(bin) do
    {int_str, rest} = digits(bin)

    case rest do
      <<?., rest2::binary>> ->
        {frac, rest3} = digits(rest2)
        {exp, rest4} = exp_part(rest3)
        {String.to_float(int_str <> "." <> frac <> exp), rest4}

      _ ->
        {exp, rest2} = exp_part(rest)

        if exp == "" do
          {String.to_integer(int_str), rest2}
        else
          {String.to_float(int_str <> exp), rest2}
        end
    end
  end

  defp digits(<<c, _::binary>> = bin) when c in ?0..?9 do
    take_digits(bin, [])
  end

  defp take_digits(<<c, rest::binary>>, acc) when c in ?0..?9 do
    take_digits(rest, [c | acc])
  end

  defp take_digits(rest, acc), do: {List.to_string(Enum.reverse(acc)), rest}

  defp exp_part(<<c, rest::binary>>) when c in [?e, ?E] do
    case rest do
      <<sign, rest2::binary>> when sign in [?+, ?-] ->
        {num, rest3} = digits(rest2)
        {<<c, sign>> <> num, rest3}

      _ ->
        {num, rest2} = digits(rest)
        {<<c>> <> num, rest2}
    end
  end

  defp exp_part(bin), do: {"", bin}

  defp enc(nil), do: "null"
  defp enc(true), do: "true"
  defp enc(false), do: "false"
  defp enc(n) when is_integer(n), do: Integer.to_string(n)
  defp enc(n) when is_float(n), do: :erlang.float_to_binary(n, [:compact, decimals: 17])
  defp enc(s) when is_binary(s), do: [?", escape(s), ?"]

  defp enc(list) when is_list(list) do
    [?[, Enum.map_join(list, ",", &enc/1), ?]]
  end

  defp enc(map) when is_map(map) do
    pairs =
      map
      |> Map.drop([:__struct__])
      |> Enum.map(fn {k, v} -> [enc(to_string(k)), ?:, enc(v)] end)

    [?{, Enum.intersperse(pairs, ?,), ?}]
  end

  defp escape(s), do: escape(s, [])

  defp escape(<<>>, acc), do: Enum.reverse(acc)

  defp escape(<<c, rest::binary>>, acc) do
    chunk =
      case c do
        ?" -> "\\\""
        ?\\ -> "\\\\"
        ?\b -> "\\b"
        ?\f -> "\\f"
        ?\n -> "\\n"
        ?\r -> "\\r"
        ?\t -> "\\t"
        _ when c < 32 ->
          ["\\u", String.pad_leading(Integer.to_string(c, 16), 4, "0")]
        _ ->
          <<c>>
      end

    escape(rest, [chunk | acc])
  end

  defp escape(<<c::utf8, rest::binary>>, acc), do: escape(rest, [<<c::utf8>> | acc])
end

defmodule HonepadAdapter do
  def main(args) do
    case args do
      [src, class_name, cases_path] ->
        run(src, class_name, cases_path)

      _ ->
        IO.puts(:stderr, "usage: elixir adapter.exs <src> <class> <cases.json>")
        System.halt(2)
    end
  end

  defp run(src, class_name, cases_path) do
    original = Process.group_leader()
    {:ok, sink} = File.open("/dev/null", [:write])
    Process.group_leader(self(), sink)

    try do
      Code.compile_file(src)
      mod = Module.concat([class_name])

      unless Code.ensure_loaded?(mod) do
        IO.puts(:stderr, "missing module #{class_name}")
        System.halt(2)
      end

      cases = decode_json(File.read!(cases_path))
      {passed, failed} = replay(mod, cases)
      Process.group_leader(self(), original)
      IO.puts(original, encode_json(%{"passed" => passed, "failed" => failed}))
      System.halt(if failed == [], do: 0, else: 1)
    after
      Process.group_leader(self(), original)
      File.close(sink)
    end
  end

  defp replay(mod, cases) do
    Enum.reduce(cases, {0, []}, fn row, {passed, failed} ->
      obj = new_target(mod)
      case_id = to_string(row["id"])
      calls = row["calls"] || []

      case replay_calls(mod, obj, case_id, calls, 0) do
        :ok -> {passed + 1, failed}
        {:fail, row} -> {passed, failed ++ [row]}
      end
    end)
  end

  defp replay_calls(_mod, _obj, _case_id, [], _i), do: :ok

  defp replay_calls(mod, obj, case_id, [call | rest], i) do
    method = to_string(call["m"])
    args = Enum.map(call["a"] || [], &coerce/1)
    expected = call["e"]

    case invoke(mod, obj, method, args) do
      {:ok, actual, obj} ->
        if encode_json(actual) == encode_json(expected) do
          replay_calls(mod, obj, case_id, rest, i + 1)
        else
          {:fail, fail_row(case_id, i, method, expected, actual)}
        end

      {:exc, reason} ->
        {:fail, fail_row(case_id, i, method, expected, "exc:#{reason}")}
    end
  end

  defp new_target(mod) do
    cond do
      function_exported?(mod, :new, 0) ->
        apply(mod, :new, [])

      function_exported?(mod, :__struct__, 0) ->
        struct(mod)

      true ->
        %{}
    end
  end

  defp invoke(mod, obj, method, args) do
    fun = String.to_atom(method)

    try do
      result = apply(mod, fun, [obj | args])

      case result do
        {val, new_obj} when is_map(new_obj) or is_pid(new_obj) ->
          {:ok, val, new_obj}

        val ->
          {:ok, val, obj}
      end
    rescue
      UndefinedFunctionError ->
        try do
          {:ok, apply(mod, fun, args), obj}
        rescue
          e -> {:exc, exc_name(e)}
        end

      e ->
        {:exc, exc_name(e)}
    end
  end

  defp exc_name(%{__struct__: struct}), do: struct |> Module.split() |> List.last()

  defp fail_row(case_id, index, method, expected, actual) do
    %{
      "case" => case_id,
      "index" => index,
      "method" => method,
      "expected" => expected,
      "actual" => actual
    }
  end

  defp coerce(n) when is_float(n) do
    i = round(n)
    if n == i * 1.0, do: i, else: n
  end

  defp coerce(list) when is_list(list), do: Enum.map(list, &coerce/1)
  defp coerce(other), do: other

  defp decode_json(text) do
    if json_stdlib?() do
      JSON.decode!(text)
    else
      MiniJson.decode(text)
    end
  end

  defp encode_json(val) do
    if json_stdlib?() do
      JSON.encode!(val)
    else
      MiniJson.encode(val)
    end
  end

  defp json_stdlib? do
    Code.ensure_loaded?(JSON) and function_exported?(JSON, :decode!, 1) and
      function_exported?(JSON, :encode!, 1)
  end
end

HonepadAdapter.main(System.argv())

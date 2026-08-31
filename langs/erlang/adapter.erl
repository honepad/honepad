#!/usr/bin/env escript
%% -*- erlang -*-
%% argv: escript adapter.erl <src> <class> <cases.json>
%% compile:file the solution, instantiate Simulation or InMemoryDatabase,
%% call snake_case methods, compare JSON encodings.
-mode(compile).

main([Src, ClassName, CasesPath]) ->
    run(Src, ClassName, CasesPath);
main(_) ->
    io:format(standard_error, "usage: escript adapter.erl <src> <class> <cases.json>~n", []),
    halt(2).

run(Src, ClassName, CasesPath) ->
    {ok, Sink} = file:open("/dev/null", [write]),
    Old = group_leader(),
    group_leader(Sink, self()),
    Mod = compile_src(Src),
    Class = list_to_atom(ClassName),
    case Mod of
        Class ->
            ok;
        _ ->
            group_leader(Old, self()),
            io:format(standard_error, "missing module ~s~n", [ClassName]),
            halt(2)
    end,
    {ok, Bin} = file:read_file(CasesPath),
    Cases = decode_json(Bin),
    {Passed, Failed} = replay(Mod, Cases),
    group_leader(Old, self()),
    io:format(Old, "~s~n", [encode_json(#{<<"passed">> => Passed, <<"failed">> => Failed})]),
    halt(case Failed of [] -> 0; _ -> 1 end).

compile_src(Src) ->
    case compile:file(filename:absname(Src), [binary, return_errors]) of
        {ok, Mod, Beam} ->
            case code:load_binary(Mod, Src, Beam) of
                {module, Mod} ->
                    Mod;
                {error, Reason} ->
                    io:format(standard_error, "load failed: ~p~n", [Reason]),
                    halt(2)
            end;
        {error, Errors, _Warnings} ->
            io:format(standard_error, "compile failed: ~p~n", [Errors]),
            halt(2);
        error ->
            io:format(standard_error, "compile failed~n", []),
            halt(2)
    end.

replay(Mod, Cases) ->
    lists:foldl(
        fun(Row, {Passed, Failed}) ->
            Obj = new_target(Mod),
            CaseId = to_bin(maps:get(<<"id">>, Row)),
            Calls = maps:get(<<"calls">>, Row, []),
            case replay_calls(Mod, Obj, CaseId, Calls, 0) of
                ok ->
                    {Passed + 1, Failed};
                {fail, FailRow} ->
                    {Passed, Failed ++ [FailRow]}
            end
        end,
        {0, []},
        Cases
    ).

replay_calls(_Mod, _Obj, _CaseId, [], _I) ->
    ok;
replay_calls(Mod, Obj, CaseId, [Call | Rest], I) ->
    Method = to_bin(maps:get(<<"m">>, Call)),
    Args = [coerce(A) || A <- maps:get(<<"a">>, Call, [])],
    Expected = coerce(maps:get(<<"e">>, Call)),
    case invoke(Mod, Obj, Method, Args) of
        {ok, Actual, NewObj} ->
            case encode_json(Actual) =:= encode_json(Expected) of
                true ->
                    replay_calls(Mod, NewObj, CaseId, Rest, I + 1);
                false ->
                    {fail, fail_row(CaseId, I, Method, Expected, Actual)}
            end;
        {exc, Reason} ->
            {fail, fail_row(CaseId, I, Method, Expected, <<"exc:", Reason/binary>>)}
    end.

new_target(Mod) ->
    case erlang:function_exported(Mod, new, 0) of
        true -> Mod:new();
        false -> #{}
    end.

invoke(Mod, Obj, Method, Args) ->
    Fun = binary_to_atom(Method, utf8),
    try apply(Mod, Fun, [Obj | Args]) of
        {Val, NewObj} when is_map(NewObj) ->
            {ok, Val, NewObj};
        Val ->
            {ok, Val, Obj}
    catch
        error:undef ->
            try apply(Mod, Fun, Args) of
                Val -> {ok, Val, Obj}
            catch
                Class:Reason -> {exc, exc_name(Class, Reason)}
            end;
        Class:Reason ->
            {exc, exc_name(Class, Reason)}
    end.

exc_name(error, undef) ->
    <<"undef">>;
exc_name(error, {undef, _}) ->
    <<"undef">>;
exc_name(Class, _) ->
    atom_to_binary(Class, utf8).

fail_row(CaseId, Index, Method, Expected, Actual) ->
    #{
        <<"case">> => CaseId,
        <<"index">> => Index,
        <<"method">> => Method,
        <<"expected">> => Expected,
        <<"actual">> => Actual
    }.

coerce(N) when is_float(N) ->
    I = round(N),
    case N == I * 1.0 of
        true -> I;
        false -> N
    end;
coerce(List) when is_list(List) ->
    [coerce(X) || X <- List];
coerce(Map) when is_map(Map) ->
    maps:map(fun(_K, V) -> coerce(V) end, Map);
coerce(Other) ->
    Other.

to_bin(B) when is_binary(B) -> B;
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_bin(L) when is_list(L) -> list_to_binary(L).

decode_json(Bin) ->
    {Val, Rest} = value(skip(Bin)),
    <<>> = skip(Rest),
    Val.

encode_json(Val) ->
    iolist_to_binary(enc(Val)).

skip(<<C, Rest/binary>>) when C =:= $\s; C =:= $\t; C =:= $\n; C =:= $\r ->
    skip(Rest);
skip(Bin) ->
    Bin.

value(<<"null", Rest/binary>>) ->
    {null, Rest};
value(<<"true", Rest/binary>>) ->
    {true, Rest};
value(<<"false", Rest/binary>>) ->
    {false, Rest};
value(<<$[, Rest/binary>>) ->
    parse_array(skip(Rest), []);
value(<<${, Rest/binary>>) ->
    parse_object(skip(Rest), #{});
value(<<$", Rest/binary>>) ->
    parse_string(Rest, []);
value(<<C, _/binary>> = Bin) when C =:= $-; C >= $0, C =< $9 ->
    parse_number(Bin).

parse_array(<<$], Rest/binary>>, Acc) ->
    {lists:reverse(Acc), Rest};
parse_array(Bin, Acc) ->
    {Val, Rest0} = value(skip(Bin)),
    Rest = skip(Rest0),
    case Rest of
        <<$,, Rest1/binary>> ->
            parse_array(skip(Rest1), [Val | Acc]);
        <<$], Rest1/binary>> ->
            {lists:reverse([Val | Acc]), Rest1}
    end.

parse_object(<<$}, Rest/binary>>, Acc) ->
    {Acc, Rest};
parse_object(<<$", Rest/binary>>, Acc) ->
    {Key, Rest1} = parse_string(Rest, []),
    <<$:, Rest2/binary>> = skip(Rest1),
    {Val, Rest3} = value(skip(Rest2)),
    Rest4 = skip(Rest3),
    Acc1 = maps:put(Key, Val, Acc),
    case Rest4 of
        <<$,, Rest5/binary>> ->
            parse_object(skip(Rest5), Acc1);
        <<$}, Rest5/binary>> ->
            {Acc1, Rest5}
    end.

parse_string(<<$", Rest/binary>>, Acc) ->
    {unicode:characters_to_binary(lists:reverse(Acc)), Rest};
parse_string(<<$\\, $u, A, B, C, D, Rest/binary>>, Acc) ->
    Code = list_to_integer([A, B, C, D], 16),
    parse_string(Rest, [Code | Acc]);
parse_string(<<$\\, C, Rest/binary>>, Acc) ->
    Ch =
        case C of
            $" -> $";
            $\\ -> $\\;
            $/ -> $/;
            $b -> $\b;
            $f -> $\f;
            $n -> $\n;
            $r -> $\r;
            $t -> $\t
        end,
    parse_string(Rest, [Ch | Acc]);
parse_string(<<C/utf8, Rest/binary>>, Acc) ->
    parse_string(Rest, [C | Acc]).

parse_number(<<$-, Rest/binary>>) ->
    {N, Rest1} = parse_number(Rest),
    {-N, Rest1};
parse_number(Bin) ->
    {IntStr, Rest} = digits(Bin),
    case Rest of
        <<$., Rest2/binary>> ->
            {Frac, Rest3} = digits(Rest2),
            {Exp, Rest4} = exp_part(Rest3),
            FloatBin = <<IntStr/binary, $., Frac/binary, Exp/binary>>,
            {list_to_float(binary_to_list(FloatBin)), Rest4};
        _ ->
            {Exp, Rest2} = exp_part(Rest),
            case Exp of
                <<>> ->
                    {list_to_integer(binary_to_list(IntStr)), Rest2};
                _ ->
                    {list_to_float(binary_to_list(<<IntStr/binary, Exp/binary>>)), Rest2}
            end
    end.

digits(<<C, _/binary>> = Bin) when C >= $0, C =< $9 ->
    take_digits(Bin, []);
digits(_) ->
    error(bad_json_number).

take_digits(<<C, Rest/binary>>, Acc) when C >= $0, C =< $9 ->
    take_digits(Rest, [C | Acc]);
take_digits(Rest, Acc) ->
    {list_to_binary(lists:reverse(Acc)), Rest}.

exp_part(<<C, Rest/binary>>) when C =:= $e; C =:= $E ->
    case Rest of
        <<Sign, Rest2/binary>> when Sign =:= $+; Sign =:= $- ->
            {Num, Rest3} = digits(Rest2),
            {<<C, Sign, Num/binary>>, Rest3};
        _ ->
            {Num, Rest2} = digits(Rest),
            {<<C, Num/binary>>, Rest2}
    end;
exp_part(Bin) ->
    {<<>>, Bin}.

enc(null) ->
    <<"null">>;
enc(true) ->
    <<"true">>;
enc(false) ->
    <<"false">>;
enc(N) when is_integer(N) ->
    integer_to_binary(N);
enc(N) when is_float(N) ->
    float_to_binary(N, [compact, {decimals, 17}]);
enc(S) when is_binary(S) ->
    [$", escape(S), $"];
enc(List) when is_list(List) ->
    [$[, lists:join($,, [enc(X) || X <- List]), $]];
enc(Map) when is_map(Map) ->
    Pairs = [
        [enc(to_bin(K)), $:, enc(V)]
     || {K, V} <- maps:to_list(Map)
    ],
    [${, lists:join($,, Pairs), $}].

escape(Bin) ->
    escape(Bin, []).

escape(<<>>, Acc) ->
    lists:reverse(Acc);
escape(<<C, Rest/binary>>, Acc) ->
    Chunk =
        case C of
            $" -> <<"\\\"">>;
            $\\ -> <<"\\\\">>;
            $\b -> <<"\\b">>;
            $\f -> <<"\\f">>;
            $\n -> <<"\\n">>;
            $\r -> <<"\\r">>;
            $\t -> <<"\\t">>;
            _ when C < 32 ->
                Hex = string:uppercase(integer_to_binary(C, 16)),
                Pad = binary:copy(<<"0">>, 4 - byte_size(Hex)),
                <<"\\u", Pad/binary, Hex/binary>>;
            _ ->
                <<C>>
        end,
    escape(Rest, [Chunk | Acc]);
escape(<<C/utf8, Rest/binary>>, Acc) ->
    escape(Rest, [<<C/utf8>> | Acc]).

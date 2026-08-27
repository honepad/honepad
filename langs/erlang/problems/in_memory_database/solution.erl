-module('InMemoryDatabase').

-export([
    new/0,
    set/4,
    get/3,
    delete/3,
    scan/2,
    scan_by_prefix/3,
    set_at/5,
    set_at_with_ttl/6,
    delete_at/4,
    get_at/4,
    scan_at/3,
    scan_by_prefix_at/4,
    backup/2,
    restore/3
]).

new() ->
    #{database => #{}, backup_timestamps => [], backup_states => []}.

set(Db, Key, Field, Value) ->
    {<<>>, set_internal(Db, Key, Field, Value, null)}.

get(Db, Key, Field) ->
    case get_field(Db, Key, Field) of
        undefined -> {<<>>, Db};
        {Value, _Expiry} -> {Value, Db}
    end.

delete(Db, Key, Field) ->
    case get_field(Db, Key, Field) of
        undefined ->
            {<<"false">>, Db};
        _ ->
            Fields = maps:remove(Field, maps:get(Key, maps:get(database, Db))),
            {<<"true">>, Db#{database := maps:put(Key, Fields, maps:get(database, Db))}}
    end.

scan(Db, Key) ->
    {join_fields(maps:get(Key, maps:get(database, Db), #{})), Db}.

scan_by_prefix(Db, Key, Prefix) ->
    Fields = maps:filter(
        fun(Field, _) -> starts_with(Field, Prefix) end,
        maps:get(Key, maps:get(database, Db), #{})
    ),
    {join_fields(Fields), Db}.

set_at(Db, Key, Field, Value, _Timestamp) ->
    {<<>>, set_internal(Db, Key, Field, Value, null)}.

set_at_with_ttl(Db, Key, Field, Value, Timestamp, Ttl) ->
    {<<>>, set_internal(Db, Key, Field, Value, Timestamp + Ttl)}.

delete_at(Db, Key, Field, Timestamp) ->
    case alive(Db, Key, Field, Timestamp) of
        true ->
            Fields = maps:remove(Field, maps:get(Key, maps:get(database, Db))),
            {<<"true">>, Db#{database := maps:put(Key, Fields, maps:get(database, Db))}};
        false ->
            {<<"false">>, Db}
    end.

get_at(Db, Key, Field, Timestamp) ->
    case alive(Db, Key, Field, Timestamp) of
        true ->
            {Value, _Expiry} = maps:get(Field, maps:get(Key, maps:get(database, Db))),
            {Value, Db};
        false ->
            {<<>>, Db}
    end.

scan_at(Db, Key, Timestamp) ->
    Fields = maps:get(Key, maps:get(database, Db), #{}),
    Items = lists:sort([
        {Field, Value}
     || {Field, {Value, _}} <- maps:to_list(Fields), alive(Db, Key, Field, Timestamp)
    ]),
    {join_pairs(Items), Db}.

scan_by_prefix_at(Db, Key, Prefix, Timestamp) ->
    Fields = maps:get(Key, maps:get(database, Db), #{}),
    Items = lists:sort([
        {Field, Value}
     || {Field, {Value, _}} <- maps:to_list(Fields),
        starts_with(Field, Prefix),
        alive(Db, Key, Field, Timestamp)
    ]),
    {join_pairs(Items), Db}.

backup(Db, Timestamp) ->
    State = maps:fold(
        fun(Key, Fields, Acc) ->
            Kept = maps:fold(
                fun(Field, {Value, Expiry}, Inner) ->
                    case alive(Db, Key, Field, Timestamp) of
                        true ->
                            Remaining =
                                case Expiry of
                                    null -> null;
                                    _ -> Expiry - Timestamp
                                end,
                            maps:put(Field, {Value, Remaining}, Inner);
                        false ->
                            Inner
                    end
                end,
                #{},
                Fields
            ),
            case maps:size(Kept) of
                0 -> Acc;
                _ -> maps:put(Key, Kept, Acc)
            end
        end,
        #{},
        maps:get(database, Db)
    ),
    Db1 = Db#{
        backup_timestamps := maps:get(backup_timestamps, Db) ++ [Timestamp],
        backup_states := maps:get(backup_states, Db) ++ [State]
    },
    {integer_to_binary(maps:size(State)), Db1}.

restore(Db, Timestamp, TimestampToRestore) ->
    Pairs = lists:zip(maps:get(backup_timestamps, Db), maps:get(backup_states, Db)),
    {_Ts, BackupState} = lists:last([{T, S} || {T, S} <- Pairs, T =< TimestampToRestore]),
    Db1 = maps:fold(
        fun(Key, Fields, Acc) ->
            maps:fold(
                fun(Field, {Value, Remaining}, Inner) ->
                    Expiry =
                        case Remaining of
                            null -> null;
                            _ -> Timestamp + Remaining
                        end,
                    set_internal(Inner, Key, Field, Value, Expiry)
                end,
                Acc,
                Fields
            )
        end,
        Db#{database := #{}},
        BackupState
    ),
    {<<>>, Db1}.

set_internal(Db, Key, Field, Value, Expiry) ->
    Fields = maps:get(Key, maps:get(database, Db), #{}),
    Db#{database := maps:put(Key, maps:put(Field, {Value, Expiry}, Fields), maps:get(database, Db))}.

get_field(Db, Key, Field) ->
    case maps:find(Key, maps:get(database, Db)) of
        error -> undefined;
        {ok, Fields} -> maps:get(Field, Fields, undefined)
    end.

alive(Db, Key, Field, Timestamp) ->
    case get_field(Db, Key, Field) of
        undefined -> false;
        {_Value, null} -> true;
        {_Value, Expiry} -> Timestamp < Expiry
    end.

join_fields(Fields) ->
    Items = lists:sort([{Field, Value} || {Field, {Value, _}} <- maps:to_list(Fields)]),
    join_pairs(Items).

join_pairs(Items) ->
    iolist_to_binary(
        lists:join(<<", ">>, [iolist_to_binary([Field, $(, Value, $)]) || {Field, Value} <- Items])
    ).

starts_with(Bin, Prefix) ->
    P = byte_size(Prefix),
    case Bin of
        <<Prefix:P/binary, _/binary>> -> true;
        _ -> false
    end.

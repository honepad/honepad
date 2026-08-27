-module('Simulation').

-export([
    new/0,
    add_file/3,
    get_file_size/2,
    delete_file/2,
    copy_file/3,
    get_n_largest/3,
    add_user/3,
    add_file_by/4,
    merge_user/3,
    backup_user/2,
    restore_user/2
]).

new() ->
    #{files => #{}, capacity => #{<<"admin">> => null}, backups => #{}}.

add_file(Sim, Name, Size) ->
    case maps:is_key(Name, maps:get(files, Sim)) of
        true -> {<<"false">>, Sim};
        false -> {<<"true">>, put_file(Sim, Name, Size, <<"admin">>)}
    end.

get_file_size(Sim, Name) ->
    case maps:find(Name, maps:get(files, Sim)) of
        error -> {<<>>, Sim};
        {ok, Item} -> {integer_to_binary(maps:get(size, Item)), Sim}
    end.

delete_file(Sim, Name) ->
    case maps:take(Name, maps:get(files, Sim)) of
        error ->
            {<<>>, Sim};
        {Item, Files} ->
            {integer_to_binary(maps:get(size, Item)), Sim#{files := Files}}
    end.

copy_file(Sim, Source, Dest) ->
    case maps:find(Source, maps:get(files, Sim)) of
        error ->
            {<<>>, Sim};
        {ok, Src} ->
            SrcSize = maps:get(size, Src),
            if
                Source =:= Dest ->
                    {integer_to_binary(SrcSize), Sim};
                true ->
                    DestItem = maps:get(Dest, maps:get(files, Sim), undefined),
                    {Owner, Extra} =
                        case DestItem of
                            undefined ->
                                {maps:get(owner, Src), SrcSize};
                            _ ->
                                {maps:get(owner, DestItem), SrcSize - maps:get(size, DestItem)}
                        end,
                    Left = remaining(Sim, Owner),
                    if
                        Left =/= null, Extra > Left ->
                            {<<>>, Sim};
                        DestItem =:= undefined ->
                            {integer_to_binary(SrcSize), put_file(Sim, Dest, SrcSize, Owner)};
                        true ->
                            Files = maps:put(
                                Dest, DestItem#{size := SrcSize}, maps:get(files, Sim)
                            ),
                            {integer_to_binary(SrcSize), Sim#{files := Files}}
                    end
            end
    end.

get_n_largest(Sim, Prefix, N) ->
    Matched = [
        Item
     || Item <- maps:values(maps:get(files, Sim)), starts_with(maps:get(name, Item), Prefix)
    ],
    Sorted = lists:sort(
        fun(A, B) ->
            SA = maps:get(size, A),
            SB = maps:get(size, B),
            if
                SA =/= SB -> SA > SB;
                true -> maps:get(name, A) =< maps:get(name, B)
            end
        end,
        Matched
    ),
    Result = iolist_to_binary(
        lists:join(<<", ">>, [
            iolist_to_binary([maps:get(name, Item), $(, integer_to_binary(maps:get(size, Item)), $)])
         || Item <- lists:sublist(Sorted, N)
        ])
    ),
    {Result, Sim}.

add_user(Sim, UserId, Capacity) ->
    case maps:is_key(UserId, maps:get(capacity, Sim)) of
        true ->
            {<<"false">>, Sim};
        false ->
            {<<"true">>, Sim#{capacity := maps:put(UserId, Capacity, maps:get(capacity, Sim))}}
    end.

add_file_by(Sim, UserId, Name, Size) ->
    HasUser = maps:is_key(UserId, maps:get(capacity, Sim)),
    HasName = maps:is_key(Name, maps:get(files, Sim)),
    Left0 = remaining(Sim, UserId),
    if
        not HasUser; HasName ->
            {<<>>, Sim};
        Left0 =/= null, Size > Left0 ->
            {<<>>, Sim};
        true ->
            Sim1 = put_file(Sim, Name, Size, UserId),
            Left = remaining(Sim1, UserId),
            {
                case Left of
                    null -> <<>>;
                    _ -> integer_to_binary(Left)
                end,
                Sim1
            }
    end.

merge_user(Sim, UserId1, UserId2) ->
    CapMap = maps:get(capacity, Sim),
    Cap1 = maps:get(UserId1, CapMap, undefined),
    Cap2 = maps:get(UserId2, CapMap, undefined),
    if
        UserId1 =:= UserId2 ->
            {<<>>, Sim};
        Cap1 =:= undefined; Cap2 =:= undefined ->
            {<<>>, Sim};
        Cap1 =:= null; Cap2 =:= null ->
            {<<>>, Sim};
        true ->
            Files = maps:map(
                fun(_Name, Item) ->
                    case maps:get(owner, Item) of
                        UserId2 -> Item#{owner := UserId1};
                        _ -> Item
                    end
                end,
                maps:get(files, Sim)
            ),
            Sim1 = Sim#{
                files := Files,
                capacity := maps:remove(UserId2, maps:put(UserId1, Cap1 + Cap2, CapMap)),
                backups := maps:remove(UserId2, maps:get(backups, Sim))
            },
            Left = remaining(Sim1, UserId1),
            {
                case Left of
                    null -> <<>>;
                    _ -> integer_to_binary(Left)
                end,
                Sim1
            }
    end.

backup_user(Sim, UserId) ->
    case maps:is_key(UserId, maps:get(capacity, Sim)) of
        false ->
            {<<>>, Sim};
        true ->
            Snapshot = maps:from_list([
                {maps:get(name, Item), maps:get(size, Item)}
             || Item <- maps:values(maps:get(files, Sim)), maps:get(owner, Item) =:= UserId
            ]),
            Sim1 = Sim#{backups := maps:put(UserId, Snapshot, maps:get(backups, Sim))},
            {integer_to_binary(maps:size(Snapshot)), Sim1}
    end.

restore_user(Sim, UserId) ->
    case maps:is_key(UserId, maps:get(capacity, Sim)) of
        false ->
            {<<>>, Sim};
        true ->
            Files = maps:filter(
                fun(_Name, Item) -> maps:get(owner, Item) =/= UserId end,
                maps:get(files, Sim)
            ),
            Sim1 = Sim#{files := Files},
            case maps:find(UserId, maps:get(backups, Sim1)) of
                error ->
                    {<<"0">>, Sim1};
                {ok, Snapshot} ->
                    {Count, Sim2} = maps:fold(
                        fun(Name, Size, {N, Acc}) ->
                            Left = remaining(Acc, UserId),
                            Exists = maps:is_key(Name, maps:get(files, Acc)),
                            if
                                Exists ->
                                    {N, Acc};
                                Left =/= null, Size > Left ->
                                    {N, Acc};
                                true ->
                                    {N + 1, put_file(Acc, Name, Size, UserId)}
                            end
                        end,
                        {0, Sim1},
                        Snapshot
                    ),
                    {integer_to_binary(Count), Sim2}
            end
    end.

put_file(Sim, Name, Size, Owner) ->
    Sim#{files := maps:put(Name, #{name => Name, size => Size, owner => Owner}, maps:get(files, Sim))}.

used(Sim, UserId) ->
    lists:sum([
        maps:get(size, Item)
     || Item <- maps:values(maps:get(files, Sim)), maps:get(owner, Item) =:= UserId
    ]).

remaining(Sim, UserId) ->
    case maps:get(UserId, maps:get(capacity, Sim), undefined) of
        undefined -> null;
        null -> null;
        Cap -> Cap - used(Sim, UserId)
    end.

starts_with(Bin, Prefix) ->
    P = byte_size(Prefix),
    case Bin of
        <<Prefix:P/binary, _/binary>> -> true;
        _ -> false
    end.

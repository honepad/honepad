-module('Simulation').

-export([
    new/0,
    allow/3,
    configure/4,
    remaining/3,
    allow_weighted/4
]).

new() ->
    #{keys => #{}}.

allow(Sim, Key, Timestamp) ->
    allow_weighted(Sim, Key, 1, Timestamp).

configure(Sim, Key, Limit, Window) when Limit =< 0; Window =< 0 ->
    {<<"invalid_request">>, Sim};
configure(Sim, Key, Limit, Window) ->
    Item = #{limit => Limit, window => Window, window_id => undefined, used => 0},
    {<<"true">>, put_key(Sim, Key, Item)}.

remaining(Sim, Key, Timestamp) ->
    {Item, Sim1} = state(Sim, Key),
    Used = used_at(Item, Timestamp),
    {integer_to_binary(maps:get(limit, Item) - Used), Sim1}.

allow_weighted(Sim, _Key, Cost, _Timestamp) when Cost =< 0 ->
    {<<"invalid_request">>, Sim};
allow_weighted(Sim, Key, Cost, Timestamp) ->
    {Item0, Sim1} = state(Sim, Key),
    Item1 = persist_window(Item0, Timestamp),
    case maps:get(used, Item1) + Cost > maps:get(limit, Item1) of
        true ->
            {<<"false">>, put_key(Sim1, Key, Item1)};
        false ->
            Item2 = Item1#{used := maps:get(used, Item1) + Cost},
            {<<"true">>, put_key(Sim1, Key, Item2)}
    end.

new_key() ->
    #{limit => 3, window => 10, window_id => undefined, used => 0}.

state(Sim, Key) ->
    case maps:find(Key, maps:get(keys, Sim)) of
        error ->
            Item = new_key(),
            {Item, put_key(Sim, Key, Item)};
        {ok, Item} ->
            {Item, Sim}
    end.

persist_window(Item, Timestamp) ->
    WindowId = Timestamp div maps:get(window, Item),
    case maps:get(window_id, Item) of
        undefined ->
            Item#{window_id := WindowId, used := 0};
        Cur when Cur =/= WindowId ->
            Item#{window_id := WindowId, used := 0};
        _ ->
            Item
    end.

used_at(Item, Timestamp) ->
    WindowId = Timestamp div maps:get(window, Item),
    case maps:get(window_id, Item) of
        undefined -> 0;
        Cur when Cur =/= WindowId -> 0;
        _ -> maps:get(used, Item)
    end.

put_key(Sim, Key, Item) ->
    Sim#{keys := maps:put(Key, Item, maps:get(keys, Sim))}.

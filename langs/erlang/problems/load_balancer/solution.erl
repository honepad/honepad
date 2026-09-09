-module('Simulation').

-export([
    new/0,
    add_backend/2,
    route/1,
    set_health/3,
    set_weight/3,
    sticky/2,
    done/2
]).

new() ->
    #{backends => [], by_id => #{}, cursor => 0, sticky_map => #{}, use_least => false}.

add_backend(Sim, BackendId) ->
    case maps:is_key(BackendId, maps:get(by_id, Sim)) of
        true ->
            {<<"false">>, Sim};
        false ->
            Item = #{backend_id => BackendId, health => true, weight => 1, inflight => 0},
            Backends = maps:get(backends, Sim) ++ [Item],
            Idx = length(maps:get(backends, Sim)),
            {<<"true">>, Sim#{
                backends := Backends,
                by_id := maps:put(BackendId, Idx, maps:get(by_id, Sim))
            }}
    end.

set_health(Sim, BackendId, Flag) ->
    case {maps:find(BackendId, maps:get(by_id, Sim)), Flag =:= 0 orelse Flag =:= 1} of
        {{ok, Idx}, true} ->
            Item = lists:nth(Idx + 1, maps:get(backends, Sim)),
            Item1 = Item#{health := Flag =:= 1},
            {<<"true">>, reset_cycle(put_item(Sim, Idx, Item1))};
        _ ->
            {<<"invalid_request">>, Sim}
    end.

set_weight(Sim, BackendId, Weight) ->
    case maps:find(BackendId, maps:get(by_id, Sim)) of
        {ok, Idx} when Weight > 0 ->
            Item = lists:nth(Idx + 1, maps:get(backends, Sim)),
            Item1 = Item#{weight := Weight},
            {<<"true">>, reset_cycle(put_item(Sim, Idx, Item1))};
        _ ->
            {<<"invalid_request">>, Sim}
    end.

route(Sim) ->
    take(Sim).

sticky(Sim, ClientId) ->
    Bound = maps:get(ClientId, maps:get(sticky_map, Sim), undefined),
    case Bound of
        undefined ->
            rebound(Sim, ClientId);
        _ ->
            case maps:find(Bound, maps:get(by_id, Sim)) of
                {ok, Idx} ->
                    Item = lists:nth(Idx + 1, maps:get(backends, Sim)),
                    case maps:get(health, Item) of
                        true ->
                            Item1 = Item#{inflight := maps:get(inflight, Item) + 1},
                            {maps:get(backend_id, Item), put_item(Sim, Idx, Item1)};
                        false ->
                            rebound(Sim, ClientId)
                    end;
                error ->
                    rebound(Sim, ClientId)
            end
    end.

done(Sim, BackendId) ->
    case maps:find(BackendId, maps:get(by_id, Sim)) of
        {ok, Idx} ->
            Item = lists:nth(Idx + 1, maps:get(backends, Sim)),
            case maps:get(inflight, Item) of
                N when N > 0 ->
                    Item1 = Item#{inflight := N - 1},
                    {<<"true">>, (put_item(Sim, Idx, Item1))#{use_least := true}};
                _ ->
                    {<<"invalid_request">>, Sim}
            end;
        error ->
            {<<"invalid_request">>, Sim}
    end.

rebound(Sim, ClientId) ->
    {Chosen, Sim1} = take(Sim),
    case Chosen of
        <<>> ->
            {Chosen, Sim1};
        "" ->
            {Chosen, Sim1};
        _ ->
            {Chosen, Sim1#{
                sticky_map := maps:put(ClientId, Chosen, maps:get(sticky_map, Sim1))
            }}
    end.

reset_cycle(Sim) ->
    Backends = [Item#{inflight := 0} || Item <- maps:get(backends, Sim)],
    Sim#{cursor := 0, use_least := false, backends := Backends}.

put_item(Sim, Idx, Item) ->
    Backends = replace_nth(Idx, Item, maps:get(backends, Sim)),
    Sim#{backends := Backends}.

replace_nth(0, Item, [_ | Rest]) ->
    [Item | Rest];
replace_nth(N, Item, [H | Rest]) ->
    [H | replace_nth(N - 1, Item, Rest)].

tickets(Items) ->
    lists:append([lists:duplicate(maps:get(weight, Item), Item) || Item <- Items]).

pick(Sim) ->
    Healthy = [Item || Item <- maps:get(backends, Sim), maps:get(health, Item)],
    case Healthy of
        [] ->
            {undefined, Sim};
        _ ->
            Pool =
                case maps:get(use_least, Sim) of
                    true ->
                        Least = lists:min([maps:get(inflight, Item) || Item <- Healthy]),
                        [Item || Item <- Healthy, maps:get(inflight, Item) =:= Least];
                    false ->
                        Healthy
                end,
            Tickets = tickets(Pool),
            case Tickets of
                [] ->
                    {undefined, Sim};
                _ ->
                    Cursor = maps:get(cursor, Sim),
                    Chosen = lists:nth((Cursor rem length(Tickets)) + 1, Tickets),
                    {Chosen, Sim#{cursor := Cursor + 1}}
            end
    end.

take(Sim) ->
    {Item, Sim1} = pick(Sim),
    case Item of
        undefined ->
            {<<>>, Sim1};
        _ ->
            BackendId = maps:get(backend_id, Item),
            Idx = maps:get(BackendId, maps:get(by_id, Sim1)),
            Stored = lists:nth(Idx + 1, maps:get(backends, Sim1)),
            Stored1 = Stored#{inflight := maps:get(inflight, Stored) + 1},
            {BackendId, put_item(Sim1, Idx, Stored1)}
    end.

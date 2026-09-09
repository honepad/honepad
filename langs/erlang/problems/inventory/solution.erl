-module('Simulation').

-export([
    new/0,
    create_item/3,
    stock/3,
    get_qty/2,
    list_low/2,
    reserve/3,
    release/3,
    ship/3
]).

new() ->
    #{items => #{}}.

create_item(Sim, Sku, Name) ->
    case maps:is_key(Sku, maps:get(items, Sim)) of
        true ->
            {<<"false">>, Sim};
        false ->
            Item = new_item(Sku, Name),
            {<<"true">>, Sim#{items := maps:put(Sku, Item, maps:get(items, Sim))}}
    end.

stock(Sim, Sku, Delta) ->
    case maps:find(Sku, maps:get(items, Sim)) of
        error ->
            {<<>>, Sim};
        {ok, Item} ->
            Nxt = maps:get(qty, Item) + Delta,
            case Nxt < maps:get(reserved, Item) of
                true ->
                    {<<"invalid_request">>, Sim};
                false ->
                    Item1 = Item#{qty := Nxt},
                    {integer_to_binary(Nxt), put_item(Sim, Sku, Item1)}
            end
    end.

get_qty(Sim, Sku) ->
    case maps:find(Sku, maps:get(items, Sim)) of
        error -> {<<>>, Sim};
        {ok, Item} -> {integer_to_binary(maps:get(qty, Item)), Sim}
    end.

list_low(Sim, Threshold) ->
    Matched = [
        Item
     || Item <- maps:values(maps:get(items, Sim)), maps:get(qty, Item) =< Threshold
    ],
    Sorted = lists:sort(
        fun(A, B) ->
            QA = maps:get(qty, A),
            QB = maps:get(qty, B),
            if
                QA =/= QB -> QA < QB;
                true -> maps:get(sku, A) =< maps:get(sku, B)
            end
        end,
        Matched
    ),
    Result = iolist_to_binary(
        lists:join(<<", ">>, [
            iolist_to_binary([
                maps:get(sku, Item),
                $(,
                integer_to_binary(maps:get(qty, Item)),
                $)
            ])
         || Item <- Sorted
        ])
    ),
    {Result, Sim}.

reserve(Sim, Sku, N) ->
    case maps:find(Sku, maps:get(items, Sim)) of
        error ->
            {<<"invalid_request">>, Sim};
        {ok, _Item} when N =< 0 ->
            {<<"invalid_request">>, Sim};
        {ok, Item} ->
            case maps:get(reserved, Item) + N > maps:get(qty, Item) of
                true ->
                    {<<"invalid_request">>, Sim};
                false ->
                    Item1 = Item#{reserved := maps:get(reserved, Item) + N},
                    {<<"true">>, put_item(Sim, Sku, Item1)}
            end
    end.

release(Sim, Sku, N) ->
    case maps:find(Sku, maps:get(items, Sim)) of
        error ->
            {<<"invalid_request">>, Sim};
        {ok, _Item} when N =< 0 ->
            {<<"invalid_request">>, Sim};
        {ok, Item} ->
            case N > maps:get(reserved, Item) of
                true ->
                    {<<"invalid_request">>, Sim};
                false ->
                    Item1 = Item#{reserved := maps:get(reserved, Item) - N},
                    {<<"true">>, put_item(Sim, Sku, Item1)}
            end
    end.

ship(Sim, Sku, N) ->
    case maps:find(Sku, maps:get(items, Sim)) of
        error ->
            {<<"invalid_request">>, Sim};
        {ok, _Item} when N =< 0 ->
            {<<"invalid_request">>, Sim};
        {ok, Item} ->
            case N > maps:get(reserved, Item) of
                true ->
                    {<<"invalid_request">>, Sim};
                false ->
                    Item1 = Item#{
                        reserved := maps:get(reserved, Item) - N,
                        qty := maps:get(qty, Item) - N
                    },
                    {<<"true">>, put_item(Sim, Sku, Item1)}
            end
    end.

new_item(Sku, Name) ->
    #{
        sku => Sku,
        name => Name,
        qty => 0,
        reserved => 0
    }.

put_item(Sim, Sku, Item) ->
    Sim#{items := maps:put(Sku, Item, maps:get(items, Sim))}.

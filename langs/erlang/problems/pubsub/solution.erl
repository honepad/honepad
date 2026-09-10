-module('Simulation').

-export([
    new/0,
    subscribe/3,
    unsubscribe/3,
    publish/3,
    inbox/2,
    list_topics/1,
    subscribers/2,
    peek/2,
    ack/3,
    retain/3
]).

new() ->
    #{subs => #{}, inbox_map => #{}, retained => #{}}.

subscribe(Sim, Topic, Client) ->
    Clients = maps:get(Topic, maps:get(subs, Sim), []),
    case lists:member(Client, Clients) of
        true ->
            {<<"false">>, Sim};
        false ->
            Clients1 = Clients ++ [Client],
            Sim1 = Sim#{subs := maps:put(Topic, Clients1, maps:get(subs, Sim))},
            case maps:find(Topic, maps:get(retained, Sim1)) of
                error ->
                    {<<"true">>, Sim1};
                {ok, Message} ->
                    Items = maps:get(Client, maps:get(inbox_map, Sim1), []),
                    Inbox = maps:put(
                        Client,
                        Items ++ [iolist_to_binary([Topic, $:, Message])],
                        maps:get(inbox_map, Sim1)
                    ),
                    {<<"true">>, Sim1#{inbox_map := Inbox}}
            end
    end.

unsubscribe(Sim, Topic, Client) ->
    case maps:find(Topic, maps:get(subs, Sim)) of
        error ->
            {<<"false">>, Sim};
        {ok, Clients} ->
            case lists:member(Client, Clients) of
                false ->
                    {<<"false">>, Sim};
                true ->
                    Clients1 = lists:delete(Client, Clients),
                    Subs =
                        case Clients1 of
                            [] -> maps:remove(Topic, maps:get(subs, Sim));
                            _ -> maps:put(Topic, Clients1, maps:get(subs, Sim))
                        end,
                    {<<"true">>, Sim#{subs := Subs}}
            end
    end.

publish(Sim, Topic, Message) ->
    Clients = maps:get(Topic, maps:get(subs, Sim), []),
    Payload = iolist_to_binary([Topic, $:, Message]),
    Inbox = lists:foldl(
        fun(Client, Acc) ->
            Items = maps:get(Client, Acc, []),
            maps:put(Client, Items ++ [Payload], Acc)
        end,
        maps:get(inbox_map, Sim),
        Clients
    ),
    {integer_to_binary(length(Clients)), Sim#{inbox_map := Inbox}}.

inbox(Sim, Client) ->
    Items = maps:get(Client, maps:get(inbox_map, Sim), []),
    {iolist_to_binary(lists:join(<<", ">>, Items)), Sim}.

list_topics(Sim) ->
    Topics = lists:sort(maps:keys(maps:get(subs, Sim))),
    {iolist_to_binary(lists:join(<<", ">>, Topics)), Sim}.

subscribers(Sim, Topic) ->
    Clients = lists:sort(maps:get(Topic, maps:get(subs, Sim), [])),
    {iolist_to_binary(lists:join(<<", ">>, Clients)), Sim}.

peek(Sim, Client) ->
    case maps:get(Client, maps:get(inbox_map, Sim), []) of
        [] -> {<<>>, Sim};
        [First | _] -> {First, Sim}
    end.

ack(Sim, Client, N) ->
    Inbox = maps:get(inbox_map, Sim),
    case {N =< 0, maps:is_key(Client, Inbox)} of
        {true, _} ->
            {<<"invalid_request">>, Sim};
        {_, false} ->
            {<<"invalid_request">>, Sim};
        {_, true} ->
            Items = maps:get(Client, Inbox),
            case N > length(Items) of
                true ->
                    {<<"invalid_request">>, Sim};
                false ->
                    Items1 = lists:nthtail(N, Items),
                    {integer_to_binary(length(Items1)), Sim#{inbox_map := maps:put(Client, Items1, Inbox)}}
            end
    end.

retain(Sim, Topic, Message) ->
    {<<>>, Sim#{retained := maps:put(Topic, Message, maps:get(retained, Sim))}}.

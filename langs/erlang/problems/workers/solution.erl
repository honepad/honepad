-module('Simulation').

-export([
    new/0,
    add_worker/4,
    register/3,
    get/2,
    top_n_workers/3,
    promote/5,
    calc_salary/4
]).

new() ->
    #{workers => #{}}.

add_worker(Sim, WorkerId, Position, Compensation) ->
    case maps:is_key(WorkerId, maps:get(workers, Sim)) of
        true ->
            {<<"false">>, Sim};
        false ->
            Worker = new_worker(WorkerId, Position, Compensation),
            {<<"true">>, Sim#{workers := maps:put(WorkerId, Worker, maps:get(workers, Sim))}}
    end.

register(Sim, WorkerId, Timestamp) ->
    case maps:find(WorkerId, maps:get(workers, Sim)) of
        error ->
            {<<"invalid_request">>, Sim};
        {ok, #{in_office := true} = Worker} ->
            Session =
                {maps:get(entered_at, Worker), Timestamp, maps:get(compensation, Worker),
                    maps:get(position, Worker)},
            Worker1 = Worker#{
                finished := maps:get(finished, Worker) ++ [Session],
                in_office := false,
                entered_at := null
            },
            {<<"registered">>, put_worker(Sim, WorkerId, Worker1)};
        {ok, Worker} ->
            Worker1 = apply_promo_on_enter(Worker, Timestamp),
            Worker2 = Worker1#{in_office := true, entered_at := Timestamp},
            {<<"registered">>, put_worker(Sim, WorkerId, Worker2)}
    end.

get(Sim, WorkerId) ->
    case maps:find(WorkerId, maps:get(workers, Sim)) of
        error -> {<<>>, Sim};
        {ok, Worker} -> {integer_to_binary(total_time(Worker)), Sim}
    end.

top_n_workers(Sim, N, Position) ->
    Matched = [
        W
     || W <- maps:values(maps:get(workers, Sim)), maps:get(position, W) =:= Position
    ],
    Sorted = lists:sort(
        fun(A, B) ->
            TA = position_time(A, Position),
            TB = position_time(B, Position),
            if
                TA =/= TB -> TA > TB;
                true -> maps:get(worker_id, A) =< maps:get(worker_id, B)
            end
        end,
        Matched
    ),
    Result = iolist_to_binary(
        lists:join(<<", ">>, [
            iolist_to_binary([
                maps:get(worker_id, W),
                $(,
                integer_to_binary(position_time(W, Position)),
                $)
            ])
         || W <- lists:sublist(Sorted, N)
        ])
    ),
    {Result, Sim}.

promote(Sim, WorkerId, NewPosition, NewCompensation, StartTimestamp) ->
    case maps:find(WorkerId, maps:get(workers, Sim)) of
        error ->
            {<<"invalid_request">>, Sim};
        {ok, #{pending_promo := Promo}} when Promo =/= null ->
            {<<"invalid_request">>, Sim};
        {ok, Worker} ->
            Worker1 = Worker#{pending_promo := {NewPosition, NewCompensation, StartTimestamp}},
            {<<"success">>, put_worker(Sim, WorkerId, Worker1)}
    end.

calc_salary(Sim, WorkerId, StartTimestamp, EndTimestamp) ->
    case maps:find(WorkerId, maps:get(workers, Sim)) of
        error ->
            {<<>>, Sim};
        {ok, Worker} ->
            Total = lists:foldl(
                fun({SessionStart, SessionEnd, Rate, _Pos}, Acc) ->
                    Lo = max(SessionStart, StartTimestamp),
                    Hi = min(SessionEnd, EndTimestamp),
                    case Hi > Lo of
                        true -> Acc + (Hi - Lo) * Rate;
                        false -> Acc
                    end
                end,
                0,
                maps:get(finished, Worker)
            ),
            {integer_to_binary(Total), Sim}
    end.

new_worker(WorkerId, Position, Compensation) ->
    #{
        worker_id => WorkerId,
        position => Position,
        compensation => Compensation,
        in_office => false,
        entered_at => null,
        finished => [],
        pending_promo => null
    }.

put_worker(Sim, WorkerId, Worker) ->
    Sim#{workers := maps:put(WorkerId, Worker, maps:get(workers, Sim))}.

total_time(Worker) ->
    lists:foldl(
        fun({StartTs, EndTs, _Rate, _Pos}, Acc) -> Acc + (EndTs - StartTs) end,
        0,
        maps:get(finished, Worker)
    ).

position_time(Worker, Position) ->
    lists:foldl(
        fun
            ({StartTs, EndTs, _Rate, Pos}, Acc) when Pos =:= Position ->
                Acc + (EndTs - StartTs);
            (_, Acc) ->
                Acc
        end,
        0,
        maps:get(finished, Worker)
    ).

apply_promo_on_enter(#{pending_promo := null} = Worker, _Timestamp) ->
    Worker;
apply_promo_on_enter(#{pending_promo := {NewPos, NewComp, StartTs}} = Worker, Timestamp) when
    Timestamp >= StartTs
->
    Worker#{position := NewPos, compensation := NewComp, pending_promo := null};
apply_promo_on_enter(Worker, _Timestamp) ->
    Worker.

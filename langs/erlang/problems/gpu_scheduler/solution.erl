-module('Simulation').

-export([
    new/0,
    add_gpu/3,
    submit_job/3,
    status/2,
    assign/1,
    complete/2,
    cancel/2,
    set_priority/3
]).

new() ->
    #{gpus => #{}, gpu_order => [], jobs => #{}, next_seq => 0}.

add_gpu(Sim, _GpuId, Mem) when Mem =< 0 ->
    {<<"invalid_request">>, Sim};
add_gpu(Sim, GpuId, Mem) ->
    case maps:is_key(GpuId, maps:get(gpus, Sim)) of
        true ->
            {<<"false">>, Sim};
        false ->
            Gpu = #{gpu_id => GpuId, mem => Mem, job_id => undefined},
            {<<"true">>, Sim#{
                gpus := maps:put(GpuId, Gpu, maps:get(gpus, Sim)),
                gpu_order := maps:get(gpu_order, Sim) ++ [GpuId]
            }}
    end.

submit_job(Sim, _JobId, Mem) when Mem =< 0 ->
    {<<"invalid_request">>, Sim};
submit_job(Sim, JobId, Mem) ->
    case maps:is_key(JobId, maps:get(jobs, Sim)) of
        true ->
            {<<"false">>, Sim};
        false ->
            Job = #{
                job_id => JobId,
                mem => Mem,
                seq => maps:get(next_seq, Sim),
                priority => 0,
                state => queued,
                gpu_id => undefined
            },
            {<<"true">>, Sim#{
                jobs := maps:put(JobId, Job, maps:get(jobs, Sim)),
                next_seq := maps:get(next_seq, Sim) + 1
            }}
    end.

status(Sim, JobId) ->
    case maps:find(JobId, maps:get(jobs, Sim)) of
        error -> {<<>>, Sim};
        {ok, Job} -> {state_bin(maps:get(state, Job)), Sim}
    end.

assign(Sim) ->
    Queued = lists:sort(
        fun(A, B) ->
            PA = maps:get(priority, A),
            PB = maps:get(priority, B),
            if
                PA =/= PB -> PA > PB;
                true -> maps:get(seq, A) =< maps:get(seq, B)
            end
        end,
        [
            Job
         || Job <- maps:values(maps:get(jobs, Sim)), maps:get(state, Job) =:= queued
        ]
    ),
    place_first(Queued, Sim).

complete(Sim, JobId) ->
    case maps:find(JobId, maps:get(jobs, Sim)) of
        {ok, Job} ->
            case {maps:get(state, Job), maps:get(gpu_id, Job)} of
                {running, GpuId} when GpuId =/= undefined ->
                    Gpu = maps:get(GpuId, maps:get(gpus, Sim)),
                    Job1 = Job#{gpu_id := undefined, state := done},
                    Gpu1 = Gpu#{job_id := undefined},
                    {<<"true">>, put_gpu(put_job(Sim, Job1), Gpu1)};
                _ ->
                    {<<"invalid_request">>, Sim}
            end;
        error ->
            {<<"invalid_request">>, Sim}
    end.

cancel(Sim, JobId) ->
    case maps:find(JobId, maps:get(jobs, Sim)) of
        error ->
            {<<"invalid_request">>, Sim};
        {ok, Job} ->
            case maps:get(state, Job) of
                done ->
                    {<<"invalid_request">>, Sim};
                State ->
                    Sim1 =
                        case {State, maps:get(gpu_id, Job)} of
                            {running, GpuId} when GpuId =/= undefined ->
                                Gpu = maps:get(GpuId, maps:get(gpus, Sim)),
                                put_gpu(Sim, Gpu#{job_id := undefined});
                            _ ->
                                Sim
                        end,
                    Sim2 = Sim1#{jobs := maps:remove(JobId, maps:get(jobs, Sim1))},
                    Sim3 =
                        case State of
                            running ->
                                {_, Next} = assign(Sim2),
                                Next;
                            _ ->
                                Sim2
                        end,
                    {<<"true">>, Sim3}
            end
    end.

set_priority(Sim, JobId, Priority) ->
    case maps:find(JobId, maps:get(jobs, Sim)) of
        {ok, Job} ->
            case maps:get(state, Job) of
                queued ->
                    {<<"true">>, put_job(Sim, Job#{priority := Priority})};
                _ ->
                    {<<"invalid_request">>, Sim}
            end;
        error ->
            {<<"invalid_request">>, Sim}
    end.

place_first([], Sim) ->
    {<<>>, Sim};
place_first([Job | Rest], Sim) ->
    case find_gpu(maps:get(gpu_order, Sim), Job, Sim) of
        {ok, Gpu} ->
            Job1 = Job#{state := running, gpu_id := maps:get(gpu_id, Gpu)},
            Gpu1 = Gpu#{job_id := maps:get(job_id, Job)},
            {maps:get(job_id, Job), put_gpu(put_job(Sim, Job1), Gpu1)};
        error ->
            place_first(Rest, Sim)
    end.

find_gpu([], _Job, _Sim) ->
    error;
find_gpu([GpuId | Rest], Job, Sim) ->
    Gpu = maps:get(GpuId, maps:get(gpus, Sim)),
    case maps:get(job_id, Gpu) =:= undefined andalso maps:get(mem, Gpu) >= maps:get(mem, Job) of
        true -> {ok, Gpu};
        false -> find_gpu(Rest, Job, Sim)
    end.

put_job(Sim, Job) ->
    Sim#{jobs := maps:put(maps:get(job_id, Job), Job, maps:get(jobs, Sim))}.

put_gpu(Sim, Gpu) ->
    Sim#{gpus := maps:put(maps:get(gpu_id, Gpu), Gpu, maps:get(gpus, Sim))}.

state_bin(queued) -> <<"queued">>;
state_bin(running) -> <<"running">>;
state_bin(done) -> <<"done">>.

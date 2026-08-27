-module('Simulation').

-export([
    new/0,
    create_account/3,
    deposit/4,
    transfer/5,
    top_spenders/3,
    pay/4,
    get_payment_status/4,
    merge_accounts/4,
    get_balance/4
]).

-define(CASHBACK_DELAY, 86400000).

new() ->
    #{accounts => #{}, payment_counter => 0, pending_cashbacks => []}.

create_account(Sim0, Timestamp, AccountId) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    Accounts = maps:get(accounts, Sim),
    case maps:is_key(AccountId, Accounts) of
        true ->
            {false, Sim};
        false ->
            Acc = new_account(AccountId, Timestamp),
            {true, Sim#{accounts := maps:put(AccountId, Acc, Accounts)}}
    end.

deposit(Sim0, Timestamp, AccountId, Amount) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    case maps:find(AccountId, maps:get(accounts, Sim)) of
        error ->
            {null, Sim};
        {ok, Acc} ->
            Acc1 = record_balance(credit(Acc, Amount), Timestamp),
            {maps:get(balance, Acc1), put_account(Sim, AccountId, Acc1)}
    end.

transfer(Sim0, Timestamp, SourceId, TargetId, Amount) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    Accounts = maps:get(accounts, Sim),
    Source = maps:get(SourceId, Accounts, undefined),
    Target = maps:get(TargetId, Accounts, undefined),
    if
        Source =:= undefined; Target =:= undefined ->
            {null, Sim};
        SourceId =:= TargetId ->
            {null, Sim};
        true ->
            case withdraw(Source, Amount) of
                error ->
                    {null, Sim};
                {ok, Source1} ->
                    Target1 = credit(Target, Amount),
                    Source2 = record_balance(Source1, Timestamp),
                    Target2 = record_balance(Target1, Timestamp),
                    Sim1 = put_account(put_account(Sim, SourceId, Source2), TargetId, Target2),
                    {maps:get(balance, Source2), Sim1}
            end
    end.

top_spenders(Sim0, Timestamp, N) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    Accounts = maps:get(accounts, Sim),
    Sorted = lists:sort(
        fun(A, B) ->
            OutA = maps:get(outgoing, maps:get(A, Accounts)),
            OutB = maps:get(outgoing, maps:get(B, Accounts)),
            if
                OutA =/= OutB -> OutA > OutB;
                true -> A =< B
            end
        end,
        maps:keys(Accounts)
    ),
    Result = [
        iolist_to_binary([
            Id,
            $(,
            integer_to_binary(maps:get(outgoing, maps:get(Id, Accounts))),
            $)
        ])
     || Id <- lists:sublist(Sorted, N)
    ],
    {Result, Sim}.

pay(Sim0, Timestamp, AccountId, Amount) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    case maps:find(AccountId, maps:get(accounts, Sim)) of
        error ->
            {null, Sim};
        {ok, Acc} ->
            case withdraw(Acc, Amount) of
                error ->
                    {null, Sim};
                {ok, Acc1} ->
                    Counter = maps:get(payment_counter, Sim) + 1,
                    PaymentId = iolist_to_binary(["payment", integer_to_list(Counter)]),
                    Acc2 = Acc1#{
                        payments := maps:put(PaymentId, <<"IN_PROGRESS">>, maps:get(payments, Acc1))
                    },
                    Acc3 = record_balance(Acc2, Timestamp),
                    Cashback = {Timestamp + ?CASHBACK_DELAY, AccountId, Amount * 2 div 100, PaymentId},
                    Sim1 = Sim#{
                        payment_counter := Counter,
                        pending_cashbacks := maps:get(pending_cashbacks, Sim) ++ [Cashback]
                    },
                    {PaymentId, put_account(Sim1, AccountId, Acc3)}
            end
    end.

get_payment_status(Sim0, Timestamp, AccountId, Payment) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    case maps:find(AccountId, maps:get(accounts, Sim)) of
        error ->
            {null, Sim};
        {ok, Acc} ->
            {maps:get(Payment, maps:get(payments, Acc), null), Sim}
    end.

merge_accounts(Sim0, Timestamp, Id1, Id2) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    Accounts = maps:get(accounts, Sim),
    Acc1 = maps:get(Id1, Accounts, undefined),
    Acc2 = maps:get(Id2, Accounts, undefined),
    if
        Id1 =:= Id2 ->
            {false, Sim};
        Acc1 =:= undefined; Acc2 =:= undefined ->
            {false, Sim};
        true ->
            History = lists:keysort(
                1, maps:get(balance_history, Acc1) ++ maps:get(balance_history, Acc2)
            ),
            Merged = Acc1#{
                balance := maps:get(balance, Acc1) + maps:get(balance, Acc2),
                outgoing := maps:get(outgoing, Acc1) + maps:get(outgoing, Acc2),
                payments := maps:merge(maps:get(payments, Acc1), maps:get(payments, Acc2)),
                balance_history := History,
                created_at := min(maps:get(created_at, Acc1), maps:get(created_at, Acc2))
            },
            Acc1b = record_balance(Merged, Timestamp),
            Pending = [
                case Item of
                    {Ts, Id2, Amount, PaymentId} -> {Ts, Id1, Amount, PaymentId};
                    Other -> Other
                end
             || Item <- maps:get(pending_cashbacks, Sim)
            ],
            Sim1 = Sim#{
                accounts := maps:remove(Id2, maps:put(Id1, Acc1b, Accounts)),
                pending_cashbacks := Pending
            },
            {true, Sim1}
    end.

get_balance(Sim0, Timestamp, AccountId, TimeAt) ->
    Sim = process_cashbacks(Sim0, Timestamp),
    case maps:find(AccountId, maps:get(accounts, Sim)) of
        error ->
            {null, Sim};
        {ok, Acc} ->
            {balance_at(Acc, TimeAt), Sim}
    end.

new_account(AccountId, CreatedAt) ->
    #{
        account_id => AccountId,
        balance => 0,
        outgoing => 0,
        payments => #{},
        created_at => CreatedAt,
        balance_history => [{CreatedAt, 0}]
    }.

put_account(Sim, AccountId, Acc) ->
    Sim#{accounts := maps:put(AccountId, Acc, maps:get(accounts, Sim))}.

credit(Acc, Amount) ->
    Acc#{balance := maps:get(balance, Acc) + Amount}.

withdraw(Acc, Amount) ->
    Bal = maps:get(balance, Acc),
    case Bal < Amount of
        true ->
            error;
        false ->
            {ok, Acc#{
                balance := Bal - Amount,
                outgoing := maps:get(outgoing, Acc) + Amount
            }}
    end.

record_balance(Acc, Timestamp) ->
    Acc#{balance_history := maps:get(balance_history, Acc) ++ [{Timestamp, maps:get(balance, Acc)}]}.

balance_at(Acc, TimeAt) ->
    case TimeAt < maps:get(created_at, Acc) of
        true ->
            null;
        false ->
            pick_balance(maps:get(balance_history, Acc), TimeAt, null)
    end.

pick_balance([], _TimeAt, Last) ->
    Last;
pick_balance([{Ts, Bal} | Rest], TimeAt, _Last) when Ts =< TimeAt ->
    pick_balance(Rest, TimeAt, Bal);
pick_balance(_, _TimeAt, Last) ->
    Last.

process_cashbacks(#{pending_cashbacks := [{CbTs, AccountId, Amount, PaymentId} | Rest]} = Sim, Timestamp) when
    CbTs =< Timestamp
->
    Sim1 = Sim#{pending_cashbacks := Rest},
    Sim2 =
        case maps:find(AccountId, maps:get(accounts, Sim1)) of
            error ->
                Sim1;
            {ok, Acc} ->
                Acc1 = credit(Acc, Amount),
                Acc2 = Acc1#{
                    payments := maps:put(
                        PaymentId, <<"CASHBACK_RECEIVED">>, maps:get(payments, Acc1)
                    )
                },
                Acc3 = record_balance(Acc2, CbTs),
                put_account(Sim1, AccountId, Acc3)
        end,
    process_cashbacks(Sim2, Timestamp);
process_cashbacks(Sim, _Timestamp) ->
    Sim.

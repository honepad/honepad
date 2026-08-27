const CASHBACK_DELAY = 24 * 60 * 60 * 1000

mutable struct Account
    account_id::String
    balance::Int
    outgoing::Int
    payments::Dict{String,String}
    created_at::Int
    balance_history::Vector{Tuple{Int,Int}}
end

function Account(account_id::AbstractString, created_at::Integer)
    return Account(
        String(account_id),
        0,
        0,
        Dict{String,String}(),
        Int(created_at),
        [(Int(created_at), 0)],
    )
end

function record_balance!(account::Account, timestamp::Integer)
    push!(account.balance_history, (Int(timestamp), account.balance))
    return account
end

function deposit!(account::Account, amount::Integer)
    account.balance += Int(amount)
    return account.balance
end

function withdraw!(account::Account, amount::Integer)
    amount = Int(amount)
    if account.balance < amount
        return false
    end
    account.balance -= amount
    account.outgoing += amount
    return true
end

function get_balance_at(account::Account, time_at::Integer)
    time_at = Int(time_at)
    if time_at < account.created_at
        return nothing
    end
    result = nothing
    for (ts, balance) in account.balance_history
        if ts <= time_at
            result = balance
        else
            break
        end
    end
    return result
end

mutable struct Simulation
    accounts::Dict{String,Account}
    payment_counter::Int
    pending_cashbacks::Vector{Tuple{Int,String,Int,String}}
end

Simulation() = Simulation(Dict{String,Account}(), 0, Tuple{Int,String,Int,String}[])

function process_cashbacks!(sim::Simulation, timestamp::Integer)
    timestamp = Int(timestamp)
    while !isempty(sim.pending_cashbacks) && sim.pending_cashbacks[1][1] <= timestamp
        cb_timestamp, account_id, amount, payment_id = popfirst!(sim.pending_cashbacks)
        if haskey(sim.accounts, account_id)
            account = sim.accounts[account_id]
            deposit!(account, amount)
            account.payments[payment_id] = "CASHBACK_RECEIVED"
            record_balance!(account, cb_timestamp)
        end
    end
    return sim
end

function create_account(sim::Simulation, timestamp, account_id)
    process_cashbacks!(sim, timestamp)
    account_id = string(account_id)
    if haskey(sim.accounts, account_id)
        return false
    end
    sim.accounts[account_id] = Account(account_id, timestamp)
    return true
end

function deposit(sim::Simulation, timestamp, account_id, amount)
    process_cashbacks!(sim, timestamp)
    account_id = string(account_id)
    if !haskey(sim.accounts, account_id)
        return nothing
    end
    account = sim.accounts[account_id]
    result = deposit!(account, amount)
    record_balance!(account, timestamp)
    return result
end

function transfer(sim::Simulation, timestamp, source_account_id, target_account_id, amount)
    process_cashbacks!(sim, timestamp)
    source_account_id = string(source_account_id)
    target_account_id = string(target_account_id)
    if !haskey(sim.accounts, source_account_id) || !haskey(sim.accounts, target_account_id)
        return nothing
    end
    if source_account_id == target_account_id
        return nothing
    end
    source = sim.accounts[source_account_id]
    target = sim.accounts[target_account_id]
    if !withdraw!(source, amount)
        return nothing
    end
    deposit!(target, amount)
    record_balance!(source, timestamp)
    record_balance!(target, timestamp)
    return source.balance
end

function top_spenders(sim::Simulation, timestamp, n)
    process_cashbacks!(sim, timestamp)
    ids = sort!(collect(keys(sim.accounts)); by = acc -> (-sim.accounts[acc].outgoing, acc))
    n = min(Int(n), length(ids))
    return ["$(id)($(sim.accounts[id].outgoing))" for id in ids[1:n]]
end

function pay(sim::Simulation, timestamp, account_id, amount)
    process_cashbacks!(sim, timestamp)
    account_id = string(account_id)
    if !haskey(sim.accounts, account_id)
        return nothing
    end
    account = sim.accounts[account_id]
    if !withdraw!(account, amount)
        return nothing
    end
    sim.payment_counter += 1
    payment_id = "payment$(sim.payment_counter)"
    account.payments[payment_id] = "IN_PROGRESS"
    record_balance!(account, timestamp)
    cashback_amount = div(Int(amount) * 2, 100)
    push!(
        sim.pending_cashbacks,
        (Int(timestamp) + CASHBACK_DELAY, account_id, cashback_amount, payment_id),
    )
    return payment_id
end

function get_payment_status(sim::Simulation, timestamp, account_id, payment)
    process_cashbacks!(sim, timestamp)
    account_id = string(account_id)
    payment = string(payment)
    if !haskey(sim.accounts, account_id)
        return nothing
    end
    account = sim.accounts[account_id]
    if !haskey(account.payments, payment)
        return nothing
    end
    return account.payments[payment]
end

function merge_accounts(sim::Simulation, timestamp, account_id_1, account_id_2)
    process_cashbacks!(sim, timestamp)
    account_id_1 = string(account_id_1)
    account_id_2 = string(account_id_2)
    if account_id_1 == account_id_2
        return false
    end
    if !haskey(sim.accounts, account_id_1) || !haskey(sim.accounts, account_id_2)
        return false
    end
    account1 = sim.accounts[account_id_1]
    account2 = sim.accounts[account_id_2]
    account1.balance += account2.balance
    account1.outgoing += account2.outgoing
    merge!(account1.payments, account2.payments)
    append!(account1.balance_history, account2.balance_history)
    sort!(account1.balance_history; by = x -> x[1])
    account1.created_at = min(account1.created_at, account2.created_at)
    record_balance!(account1, timestamp)
    for i in eachindex(sim.pending_cashbacks)
        cb_ts, acc_id, amount, payment_id = sim.pending_cashbacks[i]
        if acc_id == account_id_2
            sim.pending_cashbacks[i] = (cb_ts, account_id_1, amount, payment_id)
        end
    end
    delete!(sim.accounts, account_id_2)
    return true
end

function get_balance(sim::Simulation, timestamp, account_id, time_at)
    process_cashbacks!(sim, timestamp)
    account_id = string(account_id)
    if !haskey(sim.accounts, account_id)
        return nothing
    end
    return get_balance_at(sim.accounts[account_id], time_at)
end

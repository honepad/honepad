import Base: get

mutable struct Worker
    worker_id::String
    position::String
    compensation::Int
    in_office::Bool
    entered_at::Union{Int,Nothing}
    finished::Vector{Tuple{Int,Int,Int,String}}
    pending_promo::Union{Tuple{String,Int,Int},Nothing}
end

function Worker(worker_id::AbstractString, position::AbstractString, compensation::Integer)
    return Worker(
        String(worker_id),
        String(position),
        Int(compensation),
        false,
        nothing,
        Tuple{Int,Int,Int,String}[],
        nothing,
    )
end

function total_time(worker::Worker)
    return sum(session[2] - session[1] for session in worker.finished; init = 0)
end

function position_time(worker::Worker, position::AbstractString)
    position = string(position)
    return sum(
        session[2] - session[1] for session in worker.finished if session[4] == position;
        init = 0,
    )
end

function apply_promo_on_enter!(worker::Worker, timestamp::Integer)
    worker.pending_promo === nothing && return worker
    new_pos, new_comp, start_ts = worker.pending_promo
    if Int(timestamp) >= start_ts
        worker.position = new_pos
        worker.compensation = new_comp
        worker.pending_promo = nothing
    end
    return worker
end

mutable struct Simulation
    workers::Dict{String,Worker}
end

Simulation() = Simulation(Dict{String,Worker}())

function add_worker(sim::Simulation, worker_id, position, compensation)
    worker_id = string(worker_id)
    if haskey(sim.workers, worker_id)
        return "false"
    end
    sim.workers[worker_id] = Worker(worker_id, position, compensation)
    return "true"
end

function register(sim::Simulation, worker_id, timestamp)
    worker_id = string(worker_id)
    timestamp = Int(timestamp)
    worker = get(sim.workers, worker_id, nothing)
    if worker === nothing
        return "invalid_request"
    end
    if worker.in_office
        push!(
            worker.finished,
            (worker.entered_at, timestamp, worker.compensation, worker.position),
        )
        worker.in_office = false
        worker.entered_at = nothing
        return "registered"
    end
    apply_promo_on_enter!(worker, timestamp)
    worker.in_office = true
    worker.entered_at = timestamp
    return "registered"
end

function get(sim::Simulation, worker_id)
    worker = get(sim.workers, string(worker_id), nothing)
    return worker === nothing ? "" : string(total_time(worker))
end

function top_n_workers(sim::Simulation, n, position)
    position = string(position)
    matched = [w for w in values(sim.workers) if w.position == position]
    sort!(matched; by = w -> (-position_time(w, position), w.worker_id))
    n = min(Int(n), length(matched))
    return join(
        ["$(w.worker_id)($(position_time(w, position)))" for w in matched[1:n]],
        ", ",
    )
end

function promote(sim::Simulation, worker_id, new_position, new_compensation, start_timestamp)
    worker = get(sim.workers, string(worker_id), nothing)
    if worker === nothing || worker.pending_promo !== nothing
        return "invalid_request"
    end
    worker.pending_promo = (string(new_position), Int(new_compensation), Int(start_timestamp))
    return "success"
end

function calc_salary(sim::Simulation, worker_id, start_timestamp, end_timestamp)
    worker = get(sim.workers, string(worker_id), nothing)
    worker === nothing && return ""
    start_timestamp = Int(start_timestamp)
    end_timestamp = Int(end_timestamp)
    total = 0
    for (session_start, session_end, rate, _pos) in worker.finished
        lo = max(session_start, start_timestamp)
        hi = min(session_end, end_timestamp)
        if hi > lo
            total += (hi - lo) * rate
        end
    end
    return string(total)
end

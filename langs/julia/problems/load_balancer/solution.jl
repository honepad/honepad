mutable struct Backend
    backend_id::String
    health::Bool
    weight::Int
    inflight::Int
end

Backend(backend_id) = Backend(string(backend_id), true, 1, 0)

mutable struct Simulation
    backends::Vector{Backend}
    by_id::Dict{String,Backend}
    cursor::Int
    sticky_map::Dict{String,String}
    use_least::Bool
end

Simulation() = Simulation(Backend[], Dict{String,Backend}(), 0, Dict{String,String}(), false)

function add_backend(sim::Simulation, backend_id)
    backend_id = string(backend_id)
    if haskey(sim.by_id, backend_id)
        return "false"
    end
    item = Backend(backend_id)
    push!(sim.backends, item)
    sim.by_id[backend_id] = item
    return "true"
end

function set_health(sim::Simulation, backend_id, flag)
    item = get(sim.by_id, string(backend_id), nothing)
    flag = Int(flag)
    if item === nothing || (flag != 0 && flag != 1)
        return "invalid_request"
    end
    item.health = flag == 1
    reset_cycle!(sim)
    return "true"
end

function set_weight(sim::Simulation, backend_id, weight)
    item = get(sim.by_id, string(backend_id), nothing)
    weight = Int(weight)
    if item === nothing || weight <= 0
        return "invalid_request"
    end
    item.weight = weight
    reset_cycle!(sim)
    return "true"
end

function route(sim::Simulation)
    return take!(sim)
end

function sticky(sim::Simulation, client_id)
    client_id = string(client_id)
    bound = get(sim.sticky_map, client_id, nothing)
    item = bound === nothing ? nothing : get(sim.by_id, bound, nothing)
    if item !== nothing && item.health
        item.inflight += 1
        return item.backend_id
    end
    chosen = take!(sim)
    if !isempty(chosen)
        sim.sticky_map[client_id] = chosen
    end
    return chosen
end

function done(sim::Simulation, backend_id)
    item = get(sim.by_id, string(backend_id), nothing)
    if item === nothing || item.inflight <= 0
        return "invalid_request"
    end
    item.inflight -= 1
    sim.use_least = true
    return "true"
end

function reset_cycle!(sim::Simulation)
    sim.cursor = 0
    sim.use_least = false
    for item in sim.backends
        item.inflight = 0
    end
end

function tickets(items)
    out = Backend[]
    for item in items
        for _ in 1:item.weight
            push!(out, item)
        end
    end
    return out
end

function pick!(sim::Simulation)
    healthy = [item for item in sim.backends if item.health]
    if isempty(healthy)
        return nothing
    end
    pool = healthy
    if sim.use_least
        least = minimum(item.inflight for item in healthy)
        pool = [item for item in healthy if item.inflight == least]
    end
    tix = tickets(pool)
    if isempty(tix)
        return nothing
    end
    chosen = tix[(sim.cursor % length(tix)) + 1]
    sim.cursor += 1
    return chosen
end

function take!(sim::Simulation)
    item = pick!(sim)
    if item === nothing
        return ""
    end
    item.inflight += 1
    return item.backend_id
end

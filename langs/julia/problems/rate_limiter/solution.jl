mutable struct KeyState
    limit::Int
    window::Int
    window_id::Union{Int,Nothing}
    used::Int
end

KeyState() = KeyState(3, 10, nothing, 0)

mutable struct Simulation
    keys::Dict{String,KeyState}
end

Simulation() = Simulation(Dict{String,KeyState}())

function state(sim::Simulation, key)
    key = string(key)
    item = get(sim.keys, key, nothing)
    if item === nothing
        item = KeyState()
        sim.keys[key] = item
    end
    return item
end

function used_at(item::KeyState, timestamp, persist)
    window_id = div(Int(timestamp), item.window)
    if item.window_id === nothing || window_id != item.window_id
        if persist
            item.window_id = window_id
            item.used = 0
        end
        return 0
    end
    return item.used
end

function allow(sim::Simulation, key, timestamp)
    return allow_weighted(sim, key, 1, timestamp)
end

function configure(sim::Simulation, key, limit, window)
    limit = Int(limit)
    window = Int(window)
    if limit <= 0 || window <= 0
        return "invalid_request"
    end
    item = state(sim, key)
    item.limit = limit
    item.window = window
    item.window_id = nothing
    item.used = 0
    return "true"
end

function remaining(sim::Simulation, key, timestamp)
    item = state(sim, key)
    used = used_at(item, timestamp, false)
    return string(item.limit - used)
end

function allow_weighted(sim::Simulation, key, cost, timestamp)
    cost = Int(cost)
    if cost <= 0
        return "invalid_request"
    end
    item = state(sim, key)
    used_at(item, timestamp, true)
    if item.used + cost > item.limit
        return "false"
    end
    item.used += cost
    return "true"
end

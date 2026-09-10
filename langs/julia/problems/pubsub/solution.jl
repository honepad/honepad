mutable struct Simulation
    subs::Dict{String,Vector{String}}
    inbox_map::Dict{String,Vector{String}}
    retained::Dict{String,String}
end

Simulation() = Simulation(Dict{String,Vector{String}}(), Dict{String,Vector{String}}(), Dict{String,String}())

function subscribe(sim::Simulation, topic, client)
    topic = string(topic)
    client = string(client)
    clients = get!(sim.subs, topic, String[])
    if client in clients
        return "false"
    end
    push!(clients, client)
    if haskey(sim.retained, topic)
        items = get!(sim.inbox_map, client, String[])
        push!(items, string(topic, ":", sim.retained[topic]))
    end
    return "true"
end

function unsubscribe(sim::Simulation, topic, client)
    topic = string(topic)
    client = string(client)
    clients = get(sim.subs, topic, nothing)
    if clients === nothing || !(client in clients)
        return "false"
    end
    filter!(x -> x != client, clients)
    if isempty(clients)
        delete!(sim.subs, topic)
    end
    return "true"
end

function publish(sim::Simulation, topic, message)
    topic = string(topic)
    message = string(message)
    clients = get(sim.subs, topic, String[])
    payload = string(topic, ":", message)
    for client in clients
        items = get!(sim.inbox_map, client, String[])
        push!(items, payload)
    end
    return string(Base.length(clients))
end

function inbox(sim::Simulation, client)
    items = get(sim.inbox_map, string(client), String[])
    return join(items, ", ")
end

function list_topics(sim::Simulation)
    return join(sort!(collect(keys(sim.subs))), ", ")
end

function subscribers(sim::Simulation, topic)
    clients = copy(get(sim.subs, string(topic), String[]))
    return join(sort!(clients), ", ")
end

function peek(sim::Simulation, client)
    items = get(sim.inbox_map, string(client), String[])
    return isempty(items) ? "" : items[1]
end

function ack(sim::Simulation, client, n)
    n = Int(n)
    client = string(client)
    if n <= 0 || !haskey(sim.inbox_map, client)
        return "invalid_request"
    end
    items = sim.inbox_map[client]
    if n > Base.length(items)
        return "invalid_request"
    end
    deleteat!(items, 1:n)
    return string(Base.length(items))
end

function retain(sim::Simulation, topic, message)
    sim.retained[string(topic)] = string(message)
    return ""
end

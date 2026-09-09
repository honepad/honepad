mutable struct Item
    sku::String
    name::String
    qty::Int
    reserved::Int
end

function Item(sku::AbstractString, name::AbstractString)
    return Item(String(sku), String(name), 0, 0)
end

mutable struct Simulation
    items::Dict{String,Item}
end

Simulation() = Simulation(Dict{String,Item}())

function create_item(sim::Simulation, sku, name)
    sku = string(sku)
    if haskey(sim.items, sku)
        return "false"
    end
    sim.items[sku] = Item(sku, name)
    return "true"
end

function stock(sim::Simulation, sku, delta)
    item = get(sim.items, string(sku), nothing)
    if item === nothing
        return ""
    end
    nxt = item.qty + Int(delta)
    if nxt < item.reserved
        return "invalid_request"
    end
    item.qty = nxt
    return string(item.qty)
end

function get_qty(sim::Simulation, sku)
    item = get(sim.items, string(sku), nothing)
    return item === nothing ? "" : string(item.qty)
end

function list_low(sim::Simulation, threshold)
    threshold = Int(threshold)
    matched = [item for item in values(sim.items) if item.qty <= threshold]
    sort!(matched; by = item -> (item.qty, item.sku))
    return join(["$(item.sku)($(item.qty))" for item in matched], ", ")
end

function reserve(sim::Simulation, sku, n)
    item = get(sim.items, string(sku), nothing)
    n = Int(n)
    if item === nothing || n <= 0 || item.reserved + n > item.qty
        return "invalid_request"
    end
    item.reserved += n
    return "true"
end

function release(sim::Simulation, sku, n)
    item = get(sim.items, string(sku), nothing)
    n = Int(n)
    if item === nothing || n <= 0 || n > item.reserved
        return "invalid_request"
    end
    item.reserved -= n
    return "true"
end

function ship(sim::Simulation, sku, n)
    item = get(sim.items, string(sku), nothing)
    n = Int(n)
    if item === nothing || n <= 0 || n > item.reserved
        return "invalid_request"
    end
    item.reserved -= n
    item.qty -= n
    return "true"
end

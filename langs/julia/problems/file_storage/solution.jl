mutable struct StoredFile
    name::String
    size::Int
    owner::String
end

mutable struct Simulation
    files::Dict{String,StoredFile}
    capacity::Dict{String,Union{Int,Nothing}}
    backups::Dict{String,Dict{String,Int}}
end

function Simulation()
    return Simulation(
        Dict{String,StoredFile}(),
        Dict{String,Union{Int,Nothing}}("admin" => nothing),
        Dict{String,Dict{String,Int}}(),
    )
end

function used(sim::Simulation, user_id)
    user_id = string(user_id)
    total = 0
    for item in values(sim.files)
        if item.owner == user_id
            total += item.size
        end
    end
    return total
end

function remaining(sim::Simulation, user_id)
    user_id = string(user_id)
    cap = get(sim.capacity, user_id, nothing)
    cap === nothing && return nothing
    return cap - used(sim, user_id)
end

function add_file(sim::Simulation, name, size)
    name = string(name)
    if haskey(sim.files, name)
        return "false"
    end
    sim.files[name] = StoredFile(name, Int(size), "admin")
    return "true"
end

function get_file_size(sim::Simulation, name)
    item = get(sim.files, string(name), nothing)
    return item === nothing ? "" : string(item.size)
end

function delete_file(sim::Simulation, name)
    item = pop!(sim.files, string(name), nothing)
    return item === nothing ? "" : string(item.size)
end

function get_n_largest(sim::Simulation, prefix, n)
    prefix = string(prefix)
    matched = [item for item in values(sim.files) if startswith(item.name, prefix)]
    sort!(matched; by = item -> (-item.size, item.name))
    n = min(Int(n), length(matched))
    top = matched[1:n]
    return join(["$(item.name)($(item.size))" for item in top], ", ")
end

function add_user(sim::Simulation, user_id, capacity)
    user_id = string(user_id)
    if haskey(sim.capacity, user_id)
        return "false"
    end
    sim.capacity[user_id] = Int(capacity)
    return "true"
end

function add_file_by(sim::Simulation, user_id, name, size)
    user_id = string(user_id)
    name = string(name)
    size = Int(size)
    if !haskey(sim.capacity, user_id) || haskey(sim.files, name)
        return ""
    end
    left = remaining(sim, user_id)
    if left !== nothing && size > left
        return ""
    end
    sim.files[name] = StoredFile(name, size, user_id)
    left = remaining(sim, user_id)
    return left === nothing ? "" : string(left)
end

function merge_user(sim::Simulation, user_id1, user_id2)
    user_id1 = string(user_id1)
    user_id2 = string(user_id2)
    if user_id1 == user_id2
        return ""
    end
    if !haskey(sim.capacity, user_id1) || !haskey(sim.capacity, user_id2)
        return ""
    end
    cap1 = sim.capacity[user_id1]
    cap2 = sim.capacity[user_id2]
    if cap1 === nothing || cap2 === nothing
        return ""
    end
    sim.capacity[user_id1] = cap1 + cap2
    for item in values(sim.files)
        if item.owner == user_id2
            item.owner = user_id1
        end
    end
    delete!(sim.capacity, user_id2)
    delete!(sim.backups, user_id2)
    left = remaining(sim, user_id1)
    return left === nothing ? "" : string(left)
end

function backup_user(sim::Simulation, user_id)
    user_id = string(user_id)
    if !haskey(sim.capacity, user_id)
        return ""
    end
    snapshot = Dict{String,Int}()
    for item in values(sim.files)
        if item.owner == user_id
            snapshot[item.name] = item.size
        end
    end
    sim.backups[user_id] = snapshot
    return string(length(snapshot))
end

function restore_user(sim::Simulation, user_id)
    user_id = string(user_id)
    if !haskey(sim.capacity, user_id)
        return ""
    end
    for name in [name for (name, item) in sim.files if item.owner == user_id]
        delete!(sim.files, name)
    end
    snapshot = get(sim.backups, user_id, nothing)
    if snapshot === nothing
        return "0"
    end
    restored = 0
    for (name, size) in snapshot
        haskey(sim.files, name) && continue
        left = remaining(sim, user_id)
        if left !== nothing && size > left
            continue
        end
        sim.files[name] = StoredFile(name, size, user_id)
        restored += 1
    end
    return string(restored)
end

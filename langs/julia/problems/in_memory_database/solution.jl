import Base: get

mutable struct InMemoryDatabase
    database::Dict{String,Dict{String,Tuple{String,Union{Int,Nothing}}}}
    backup_timestamps::Vector{Int}
    backup_states::Vector{Dict{String,Dict{String,Tuple{String,Union{Int,Nothing}}}}}
end

function InMemoryDatabase()
    return InMemoryDatabase(
        Dict{String,Dict{String,Tuple{String,Union{Int,Nothing}}}}(),
        Int[],
        Dict{String,Dict{String,Tuple{String,Union{Int,Nothing}}}}[],
    )
end

function set_internal!(db::InMemoryDatabase, key, field, value, expiry)
    key = string(key)
    field = string(field)
    value = string(value)
    fields = get!(Dict{String,Tuple{String,Union{Int,Nothing}}}, db.database, key)
    fields[field] = (value, expiry)
    return ""
end

function is_alive(db::InMemoryDatabase, key, field, timestamp)
    key = string(key)
    field = string(field)
    timestamp = Int(timestamp)
    if !haskey(db.database, key) || !haskey(db.database[key], field)
        return false
    end
    _value, expiry = db.database[key][field]
    return expiry === nothing || timestamp < expiry
end

function set(db::InMemoryDatabase, key, field, value)
    return set_internal!(db, key, field, value, nothing)
end

function get(db::InMemoryDatabase, key, field)
    key = string(key)
    field = string(field)
    if !haskey(db.database, key) || !haskey(db.database[key], field)
        return ""
    end
    return db.database[key][field][1]
end

function delete(db::InMemoryDatabase, key, field)
    key = string(key)
    field = string(field)
    if !haskey(db.database, key) || !haskey(db.database[key], field)
        return "false"
    end
    delete!(db.database[key], field)
    return "true"
end

function scan(db::InMemoryDatabase, key)
    key = string(key)
    if !haskey(db.database, key)
        return ""
    end
    items = sort!(collect(db.database[key]))
    return join(["$(field)($(value[1]))" for (field, value) in items], ", ")
end

function scan_by_prefix(db::InMemoryDatabase, key, prefix)
    key = string(key)
    prefix = string(prefix)
    if !haskey(db.database, key)
        return ""
    end
    items = [(field, value) for (field, value) in db.database[key] if startswith(field, prefix)]
    sort!(items)
    return join(["$(field)($(value[1]))" for (field, value) in items], ", ")
end

function set_at(db::InMemoryDatabase, key, field, value, timestamp)
    return set_internal!(db, key, field, value, nothing)
end

function set_at_with_ttl(db::InMemoryDatabase, key, field, value, timestamp, ttl)
    return set_internal!(db, key, field, value, Int(timestamp) + Int(ttl))
end

function delete_at(db::InMemoryDatabase, key, field, timestamp)
    if !is_alive(db, key, field, timestamp)
        return "false"
    end
    delete!(db.database[string(key)], string(field))
    return "true"
end

function get_at(db::InMemoryDatabase, key, field, timestamp)
    if !is_alive(db, key, field, timestamp)
        return ""
    end
    return db.database[string(key)][string(field)][1]
end

function scan_at(db::InMemoryDatabase, key, timestamp)
    key = string(key)
    if !haskey(db.database, key)
        return ""
    end
    items = [
        (field, value[1]) for (field, value) in db.database[key] if
        is_alive(db, key, field, timestamp)
    ]
    sort!(items)
    return join(["$(field)($(value))" for (field, value) in items], ", ")
end

function scan_by_prefix_at(db::InMemoryDatabase, key, prefix, timestamp)
    key = string(key)
    prefix = string(prefix)
    if !haskey(db.database, key)
        return ""
    end
    items = [
        (field, value[1]) for (field, value) in db.database[key] if
        startswith(field, prefix) && is_alive(db, key, field, timestamp)
    ]
    sort!(items)
    return join(["$(field)($(value))" for (field, value) in items], ", ")
end

function backup(db::InMemoryDatabase, timestamp)
    timestamp = Int(timestamp)
    state = Dict{String,Dict{String,Tuple{String,Union{Int,Nothing}}}}()
    for (key, fields) in db.database
        for (field, (value, expiry)) in fields
            if is_alive(db, key, field, timestamp)
                remaining = expiry === nothing ? nothing : expiry - timestamp
                bucket = get!(Dict{String,Tuple{String,Union{Int,Nothing}}}, state, key)
                bucket[field] = (value, remaining)
            end
        end
    end
    push!(db.backup_timestamps, timestamp)
    push!(db.backup_states, state)
    return string(length(state))
end

function restore(db::InMemoryDatabase, timestamp, timestamp_to_restore)
    idx = searchsortedlast(db.backup_timestamps, Int(timestamp_to_restore))
    backup_state = db.backup_states[idx]
    db.database = Dict{String,Dict{String,Tuple{String,Union{Int,Nothing}}}}()
    for (key, fields) in backup_state
        for (field, (value, remaining)) in fields
            expiry = remaining === nothing ? nothing : Int(timestamp) + remaining
            set_internal!(db, key, field, value, expiry)
        end
    end
    return ""
end

mutable struct Simulation
    buf::String
    pos::Int
    undo_stack::Vector{Tuple{String,Int}}
    redo_stack::Vector{Tuple{String,Int}}
    sel::Union{Nothing,Tuple{Int,Int}}
    clip::String
end

Simulation() = Simulation("", 0, Tuple{String,Int}[], Tuple{String,Int}[], nothing, "")

function _push!(sim::Simulation)
    push!(sim.undo_stack, (sim.buf, sim.pos))
    empty!(sim.redo_stack)
    sim.sel = nothing
end

function insert(sim::Simulation, pos, text)
    pos = Int(pos)
    text = string(text)
    if pos < 0 || pos > ncodeunits(sim.buf)
        return "invalid_request"
    end
    _push!(sim)
    sim.buf = string(SubString(sim.buf, 1, pos), text, SubString(sim.buf, pos + 1))
    return string(ncodeunits(sim.buf))
end

function erase(sim::Simulation, pos, n)
    pos = Int(pos)
    n = Int(n)
    if n <= 0 || pos < 0 || pos + n > ncodeunits(sim.buf)
        return "invalid_request"
    end
    _push!(sim)
    deleted = SubString(sim.buf, pos + 1, pos + n)
    sim.buf = string(SubString(sim.buf, 1, pos), SubString(sim.buf, pos + n + 1))
    if sim.pos > ncodeunits(sim.buf)
        sim.pos = ncodeunits(sim.buf)
    end
    return String(deleted)
end

function get_text(sim::Simulation)
    return sim.buf
end

function length(sim::Simulation)
    return string(ncodeunits(sim.buf))
end


function move(sim::Simulation, pos)
    pos = Int(pos)
    if pos < 0 || pos > ncodeunits(sim.buf)
        return "invalid_request"
    end
    sim.pos = pos
    return "true"
end

function type_text(sim::Simulation, text)
    text = string(text)
    _push!(sim)
    at = sim.pos
    sim.buf = string(SubString(sim.buf, 1, at), text, SubString(sim.buf, at + 1))
    sim.pos = at + ncodeunits(text)
    return string(ncodeunits(sim.buf))
end

function cursor(sim::Simulation)
    return string(sim.pos)
end

function undo(sim::Simulation)
    if isempty(sim.undo_stack)
        return "false"
    end
    push!(sim.redo_stack, (sim.buf, sim.pos))
    sim.buf, sim.pos = pop!(sim.undo_stack)
    sim.sel = nothing
    return "true"
end

function redo(sim::Simulation)
    if isempty(sim.redo_stack)
        return "false"
    end
    push!(sim.undo_stack, (sim.buf, sim.pos))
    sim.buf, sim.pos = pop!(sim.redo_stack)
    sim.sel = nothing
    return "true"
end

function select(sim::Simulation, start, last)
    start = Int(start)
    last = Int(last)
    if start < 0 || last < 0 || start > last || last > ncodeunits(sim.buf)
        return "invalid_request"
    end
    sim.sel = (start, last)
    return "true"
end

function cut(sim::Simulation)
    if sim.sel === nothing || sim.sel[1] == sim.sel[2]
        return "invalid_request"
    end
    start, last = sim.sel
    text = String(SubString(sim.buf, start + 1, last))
    sim.buf = string(SubString(sim.buf, 1, start), SubString(sim.buf, last + 1))
    sim.clip = text
    sim.pos = start
    sim.sel = nothing
    return text
end

function copy_sel(sim::Simulation)
    if sim.sel === nothing || sim.sel[1] == sim.sel[2]
        return "invalid_request"
    end
    start, last = sim.sel
    sim.clip = String(SubString(sim.buf, start + 1, last))
    return sim.clip
end

function paste(sim::Simulation)
    if sim.clip == ""
        return "invalid_request"
    end
    at = sim.pos
    sim.buf = string(SubString(sim.buf, 1, at), sim.clip, SubString(sim.buf, at + 1))
    sim.pos = at + ncodeunits(sim.clip)
    return string(ncodeunits(sim.buf))
end

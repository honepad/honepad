mutable struct Gpu
    gpu_id::String
    mem::Int
    job_id::Union{String,Nothing}
end

Gpu(gpu_id, mem) = Gpu(string(gpu_id), Int(mem), nothing)

mutable struct Job
    job_id::String
    mem::Int
    seq::Int
    priority::Int
    state::String
    gpu_id::Union{String,Nothing}
end

Job(job_id, mem, seq) = Job(string(job_id), Int(mem), Int(seq), 0, "queued", nothing)

mutable struct Simulation
    gpus::Dict{String,Gpu}
    gpu_order::Vector{String}
    jobs::Dict{String,Job}
    next_seq::Int
end

Simulation() = Simulation(Dict{String,Gpu}(), String[], Dict{String,Job}(), 0)

function add_gpu(sim::Simulation, gpu_id, mem)
    gpu_id = string(gpu_id)
    mem = Int(mem)
    if mem <= 0
        return "invalid_request"
    end
    if haskey(sim.gpus, gpu_id)
        return "false"
    end
    sim.gpus[gpu_id] = Gpu(gpu_id, mem)
    push!(sim.gpu_order, gpu_id)
    return "true"
end

function submit_job(sim::Simulation, job_id, mem)
    job_id = string(job_id)
    mem = Int(mem)
    if mem <= 0
        return "invalid_request"
    end
    if haskey(sim.jobs, job_id)
        return "false"
    end
    sim.jobs[job_id] = Job(job_id, mem, sim.next_seq)
    sim.next_seq += 1
    return "true"
end

function status(sim::Simulation, job_id)
    job = get(sim.jobs, string(job_id), nothing)
    return job === nothing ? "" : job.state
end

function place!(job::Job, gpu::Gpu)
    job.state = "running"
    job.gpu_id = gpu.gpu_id
    gpu.job_id = job.job_id
    return nothing
end

function assign(sim::Simulation)
    queued = [job for job in values(sim.jobs) if job.state == "queued"]
    sort!(queued, by = job -> (-job.priority, job.seq))
    for job in queued
        for gpu_id in sim.gpu_order
            gpu = sim.gpus[gpu_id]
            if gpu.job_id === nothing && gpu.mem >= job.mem
                place!(job, gpu)
                return job.job_id
            end
        end
    end
    return ""
end

function complete(sim::Simulation, job_id)
    job = get(sim.jobs, string(job_id), nothing)
    if job === nothing || job.state != "running" || job.gpu_id === nothing
        return "invalid_request"
    end
    sim.gpus[job.gpu_id].job_id = nothing
    job.gpu_id = nothing
    job.state = "done"
    return "true"
end

function cancel(sim::Simulation, job_id)
    job = get(sim.jobs, string(job_id), nothing)
    if job === nothing || job.state == "done"
        return "invalid_request"
    end
    if job.state == "running" && job.gpu_id !== nothing
        sim.gpus[job.gpu_id].job_id = nothing
    end
    delete!(sim.jobs, string(job_id))
    if job.state == "running"
        assign(sim)
    end
    return "true"
end

function set_priority(sim::Simulation, job_id, priority)
    job = get(sim.jobs, string(job_id), nothing)
    if job === nothing || job.state != "queued"
        return "invalid_request"
    end
    job.priority = Int(priority)
    return "true"
end

module Solution

open System.Collections.Generic

type Gpu(gpuId: string, mem: int) =
    member val GpuId = gpuId with get, set
    member val Mem = mem with get, set
    member val JobId: string option = None with get, set

type Job(jobId: string, mem: int, seq: int) =
    member val JobId = jobId with get, set
    member val Mem = mem with get, set
    member val Seq = seq with get, set
    member val Priority = 0 with get, set
    member val State = "queued" with get, set
    member val GpuId: string option = None with get, set

type Simulation() =
    let gpus = Dictionary<string, Gpu>()
    let gpuOrder = ResizeArray<string>()
    let jobs = Dictionary<string, Job>()
    let mutable nextSeq = 0

    let place (job: Job) (gpu: Gpu) =
        job.State <- "running"
        job.GpuId <- Some gpu.GpuId
        gpu.JobId <- Some job.JobId

    member this.addGpu(gpuId: string, mem: int) : string =
        if mem <= 0 then
            "invalid_request"
        elif gpus.ContainsKey(gpuId) then
            "false"
        else
            gpus[gpuId] <- Gpu(gpuId, mem)
            gpuOrder.Add(gpuId)
            "true"

    member this.submitJob(jobId: string, mem: int) : string =
        if mem <= 0 then
            "invalid_request"
        elif jobs.ContainsKey(jobId) then
            "false"
        else
            jobs[jobId] <- Job(jobId, mem, nextSeq)
            nextSeq <- nextSeq + 1
            "true"

    member this.status(jobId: string) : string =
        match jobs.TryGetValue(jobId) with
        | true, job -> job.State
        | _ -> ""

    member this.assign() : string =
        let queued = ResizeArray<Job>()

        for job in jobs.Values do
            if job.State = "queued" then
                queued.Add(job)

        queued.Sort(fun a b ->
            let byPriority = compare b.Priority a.Priority
            if byPriority <> 0 then byPriority else compare a.Seq b.Seq)

        let mutable found = ""

        for job in queued do
            if found = "" then
                for gpuId in gpuOrder do
                    if found = "" then
                        let gpu = gpus[gpuId]

                        match gpu.JobId with
                        | None when gpu.Mem >= job.Mem ->
                            place job gpu
                            found <- job.JobId
                        | _ -> ()

        found

    member this.complete(jobId: string) : string =
        match jobs.TryGetValue(jobId) with
        | true, job when job.State = "running" ->
            match job.GpuId with
            | Some gpuId ->
                gpus[gpuId].JobId <- None
                job.GpuId <- None
                job.State <- "done"
                "true"
            | None -> "invalid_request"
        | _ -> "invalid_request"

    member this.cancel(jobId: string) : string =
        match jobs.TryGetValue(jobId) with
        | false, _ -> "invalid_request"
        | true, job when job.State = "done" -> "invalid_request"
        | true, job ->
            let running = job.State = "running"

            if running then
                match job.GpuId with
                | Some gpuId -> gpus[gpuId].JobId <- None
                | None -> ()

            jobs.Remove(jobId) |> ignore

            if running then
                this.assign() |> ignore

            "true"

    member this.setPriority(jobId: string, priority: int) : string =
        match jobs.TryGetValue(jobId) with
        | true, job when job.State = "queued" ->
            job.Priority <- priority
            "true"
        | _ -> "invalid_request"

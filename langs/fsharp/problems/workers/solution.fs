module Solution

open System
open System.Collections.Generic

type WorkSession(start: int, endTime: int, rate: int, position: string) =
    member val Start = start with get, set
    member val End = endTime with get, set
    member val Rate = rate with get, set
    member val Position = position with get, set

[<AllowNullLiteral>]
type Promo(position: string, compensation: int, startTimestamp: int) =
    member val Position = position with get, set
    member val Compensation = compensation with get, set
    member val StartTimestamp = startTimestamp with get, set

type Worker(workerId: string, position: string, compensation: int) =
    member val WorkerId = workerId with get, set
    member val Position = position with get, set
    member val Compensation = compensation with get, set
    member val InOffice = false with get, set
    member val EnteredAt = Nullable() with get, set
    member val Finished = ResizeArray<WorkSession>() with get
    member val PendingPromo: Promo = null with get, set

    member this.TotalTime() =
        let mutable sum = 0

        for session in this.Finished do
            sum <- sum + (session.End - session.Start)

        sum

    member this.PositionTime(pos: string) =
        let mutable sum = 0

        for session in this.Finished do
            if session.Position = pos then
                sum <- sum + (session.End - session.Start)

        sum

    member this.ApplyPromoOnEnter(timestamp: int) =
        if not (isNull this.PendingPromo) && timestamp >= this.PendingPromo.StartTimestamp then
            this.Position <- this.PendingPromo.Position
            this.Compensation <- this.PendingPromo.Compensation
            this.PendingPromo <- null

type Simulation() =
    let workers = Dictionary<string, Worker>()

    member this.addWorker(workerId: string, position: string, compensation: int) : string =
        if workers.ContainsKey(workerId) then
            "false"
        else
            workers[workerId] <- Worker(workerId, position, compensation)
            "true"

    member this.register(workerId: string, timestamp: int) : string =
        match workers.TryGetValue(workerId) with
        | false, _ -> "invalid_request"
        | true, worker ->
            if worker.InOffice then
                worker.Finished.Add(
                    WorkSession(worker.EnteredAt.Value, timestamp, worker.Compensation, worker.Position)
                )

                worker.InOffice <- false
                worker.EnteredAt <- Nullable()
                "registered"
            else
                worker.ApplyPromoOnEnter(timestamp)
                worker.InOffice <- true
                worker.EnteredAt <- Nullable(timestamp)
                "registered"

    member this.get(workerId: string) : string =
        match workers.TryGetValue(workerId) with
        | false, _ -> ""
        | true, worker -> string (worker.TotalTime())

    member this.topNWorkers(n: int, position: string) : string =
        let matched =
            ResizeArray(workers.Values |> Seq.filter (fun worker -> worker.Position = position))

        matched.Sort(fun a b ->
            let d = b.PositionTime(position).CompareTo(a.PositionTime(position))
            if d <> 0 then d else String.CompareOrdinal(a.WorkerId, b.WorkerId))

        if n < matched.Count then
            matched.RemoveRange(n, matched.Count - n)

        String.Join(
            ", ",
            matched
            |> Seq.map (fun worker -> worker.WorkerId + "(" + string (worker.PositionTime(position)) + ")")
        )

    member this.promote
        (workerId: string, newPosition: string, newCompensation: int, startTimestamp: int)
        : string =
        match workers.TryGetValue(workerId) with
        | false, _ -> "invalid_request"
        | true, worker when not (isNull worker.PendingPromo) -> "invalid_request"
        | true, worker ->
            worker.PendingPromo <- Promo(newPosition, newCompensation, startTimestamp)
            "success"

    member this.calcSalary(workerId: string, startTimestamp: int, endTimestamp: int) : string =
        match workers.TryGetValue(workerId) with
        | false, _ -> ""
        | true, worker ->
            let mutable total = 0L

            for session in worker.Finished do
                let lo = Math.Max(session.Start, startTimestamp)
                let hi = Math.Min(session.End, endTimestamp)

                if hi > lo then
                    total <- total + int64 (hi - lo) * int64 session.Rate

            string total

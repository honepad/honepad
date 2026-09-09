module Solution

open System.Collections.Generic

type Backend(backendId: string) =
    member val BackendId = backendId with get, set
    member val Health = true with get, set
    member val Weight = 1 with get, set
    member val Inflight = 0 with get, set

type Simulation() =
    let backends = ResizeArray<Backend>()
    let byId = Dictionary<string, Backend>()
    let mutable cursor = 0
    let stickyMap = Dictionary<string, string>()
    let mutable useLeast = false

    let resetCycle () =
        cursor <- 0
        useLeast <- false
        for item in backends do
            item.Inflight <- 0

    let tickets (items: ResizeArray<Backend>) =
        let out = ResizeArray<Backend>()
        for item in items do
            for _ in 1 .. item.Weight do
                out.Add(item)
        out

    let pick () =
        let healthy = ResizeArray<Backend>()
        for item in backends do
            if item.Health then
                healthy.Add(item)

        if healthy.Count = 0 then
            None
        else
            let pool = ResizeArray<Backend>()
            if useLeast then
                let mutable least = healthy[0].Inflight
                for i in 1 .. healthy.Count - 1 do
                    if healthy[i].Inflight < least then
                        least <- healthy[i].Inflight
                for item in healthy do
                    if item.Inflight = least then
                        pool.Add(item)
            else
                pool.AddRange(healthy)

            let ticketList = tickets pool
            if ticketList.Count = 0 then
                None
            else
                let chosen = ticketList[cursor % ticketList.Count]
                cursor <- cursor + 1
                Some chosen

    let take () =
        match pick () with
        | None -> ""
        | Some item ->
            item.Inflight <- item.Inflight + 1
            item.BackendId

    member this.addBackend(backendId: string) : string =
        if byId.ContainsKey(backendId) then
            "false"
        else
            let item = Backend(backendId)
            backends.Add(item)
            byId[backendId] <- item
            "true"

    member this.setHealth(backendId: string, flag: int) : string =
        match byId.TryGetValue(backendId) with
        | false, _ -> "invalid_request"
        | true, _ when flag <> 0 && flag <> 1 -> "invalid_request"
        | true, item ->
            item.Health <- (flag = 1)
            resetCycle ()
            "true"

    member this.setWeight(backendId: string, weight: int) : string =
        match byId.TryGetValue(backendId) with
        | false, _ -> "invalid_request"
        | true, _ when weight <= 0 -> "invalid_request"
        | true, item ->
            item.Weight <- weight
            resetCycle ()
            "true"

    member this.route() : string = take ()

    member this.sticky(clientId: string) : string =
        match stickyMap.TryGetValue(clientId) with
        | true, bound ->
            match byId.TryGetValue(bound) with
            | true, item when item.Health ->
                item.Inflight <- item.Inflight + 1
                item.BackendId
            | _ ->
                let chosen = take ()
                if chosen <> "" then
                    stickyMap[clientId] <- chosen
                chosen
        | _ ->
            let chosen = take ()
            if chosen <> "" then
                stickyMap[clientId] <- chosen
            chosen

    member this.``done``(backendId: string) : string =
        match byId.TryGetValue(backendId) with
        | false, _ -> "invalid_request"
        | true, item when item.Inflight <= 0 -> "invalid_request"
        | true, item ->
            item.Inflight <- item.Inflight - 1
            useLeast <- true
            "true"

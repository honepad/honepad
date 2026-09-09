module Solution

open System.Collections.Generic

type KeyState() =
    member val Limit = 3 with get, set
    member val Window = 10 with get, set
    member val WindowId: int option = None with get, set
    member val Used = 0 with get, set

type Simulation() =
    let keys = Dictionary<string, KeyState>()

    let state key =
        match keys.TryGetValue(key) with
        | true, item -> item
        | _ ->
            let item = KeyState()
            keys[key] <- item
            item

    let usedAt (item: KeyState) timestamp persist =
        let windowId = timestamp / item.Window

        match item.WindowId with
        | Some id when id = windowId -> item.Used
        | _ ->
            if persist then
                item.WindowId <- Some windowId
                item.Used <- 0

            0

    member this.allow(key: string, timestamp: int) : string =
        this.allowWeighted (key, 1, timestamp)

    member this.configure(key: string, limit: int, window: int) : string =
        if limit <= 0 || window <= 0 then
            "invalid_request"
        else
            let item = state key
            item.Limit <- limit
            item.Window <- window
            item.WindowId <- None
            item.Used <- 0
            "true"

    member this.remaining(key: string, timestamp: int) : string =
        let item = state key
        let used = usedAt item timestamp false
        string (item.Limit - used)

    member this.allowWeighted(key: string, cost: int, timestamp: int) : string =
        if cost <= 0 then
            "invalid_request"
        else
            let item = state key
            usedAt item timestamp true |> ignore

            if item.Used + cost > item.Limit then
                "false"
            else
                item.Used <- item.Used + cost
                "true"

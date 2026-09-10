module Solution

open System.Collections.Generic

type Simulation() =
    let subs = Dictionary<string, ResizeArray<string>>()
    let inboxMap = Dictionary<string, ResizeArray<string>>()
    let retained = Dictionary<string, string>()

    member this.subscribe(topic: string, client: string) : string =
        let clients =
            match subs.TryGetValue(topic) with
            | true, existing -> existing
            | _ ->
                let created = ResizeArray<string>()
                subs[topic] <- created
                created

        if clients.Contains(client) then
            "false"
        else
            clients.Add(client)

            match retained.TryGetValue(topic) with
            | true, message ->
                let items =
                    match inboxMap.TryGetValue(client) with
                    | true, existing -> existing
                    | _ ->
                        let created = ResizeArray<string>()
                        inboxMap[client] <- created
                        created

                items.Add(topic + ":" + message)
            | _ -> ()

            "true"

    member this.unsubscribe(topic: string, client: string) : string =
        match subs.TryGetValue(topic) with
        | false, _ -> "false"
        | true, clients when not (clients.Contains(client)) -> "false"
        | true, clients ->
            clients.Remove(client) |> ignore

            if clients.Count = 0 then
                subs.Remove(topic) |> ignore

            "true"

    member this.publish(topic: string, message: string) : string =
        match subs.TryGetValue(topic) with
        | false, _ -> "0"
        | true, clients ->
            let payload = topic + ":" + message

            for client in clients do
                let items =
                    match inboxMap.TryGetValue(client) with
                    | true, existing -> existing
                    | _ ->
                        let created = ResizeArray<string>()
                        inboxMap[client] <- created
                        created

                items.Add(payload)

            string clients.Count

    member this.inbox(client: string) : string =
        match inboxMap.TryGetValue(client) with
        | true, items -> String.concat ", " items
        | _ -> ""

    member this.listTopics() : string =
        subs.Keys |> Seq.sort |> String.concat ", "

    member this.subscribers(topic: string) : string =
        match subs.TryGetValue(topic) with
        | true, clients -> clients |> Seq.sort |> String.concat ", "
        | _ -> ""

    member this.peek(client: string) : string =
        match inboxMap.TryGetValue(client) with
        | true, items when items.Count > 0 -> items[0]
        | _ -> ""

    member this.ack(client: string, n: int) : string =
        match inboxMap.TryGetValue(client) with
        | false, _ -> "invalid_request"
        | _ when n <= 0 -> "invalid_request"
        | true, items when n > items.Count -> "invalid_request"
        | true, items ->
            items.RemoveRange(0, n)
            string items.Count

    member this.retain(topic: string, message: string) : string =
        retained[topic] <- message
        ""

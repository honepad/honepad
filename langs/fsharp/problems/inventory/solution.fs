module Solution

open System.Collections.Generic

type Item(sku: string, name: string) =
    member val Sku = sku with get, set
    member val Name = name with get, set
    member val Qty = 0 with get, set
    member val Reserved = 0 with get, set

type Simulation() =
    let items = Dictionary<string, Item>()

    member this.createItem(sku: string, name: string) : string =
        if items.ContainsKey(sku) then
            "false"
        else
            items[sku] <- Item(sku, name)
            "true"

    member this.stock(sku: string, delta: int) : string =
        match items.TryGetValue(sku) with
        | false, _ -> ""
        | true, item ->
            let nxt = item.Qty + delta

            if nxt < item.Reserved then
                "invalid_request"
            else
                item.Qty <- nxt
                string item.Qty

    member this.getQty(sku: string) : string =
        match items.TryGetValue(sku) with
        | true, item -> string item.Qty
        | _ -> ""

    member this.listLow(threshold: int) : string =
        let matched = ResizeArray<Item>()

        for item in items.Values do
            if item.Qty <= threshold then
                matched.Add(item)

        matched.Sort(fun a b ->
            let d = a.Qty.CompareTo(b.Qty)
            if d <> 0 then d else compare a.Sku b.Sku)

        matched
        |> Seq.map (fun item -> item.Sku + "(" + string item.Qty + ")")
        |> String.concat ", "

    member this.reserve(sku: string, n: int) : string =
        match items.TryGetValue(sku) with
        | false, _ -> "invalid_request"
        | true, item when n <= 0 || item.Reserved + n > item.Qty -> "invalid_request"
        | true, item ->
            item.Reserved <- item.Reserved + n
            "true"

    member this.release(sku: string, n: int) : string =
        match items.TryGetValue(sku) with
        | false, _ -> "invalid_request"
        | true, item when n <= 0 || n > item.Reserved -> "invalid_request"
        | true, item ->
            item.Reserved <- item.Reserved - n
            "true"

    member this.ship(sku: string, n: int) : string =
        match items.TryGetValue(sku) with
        | false, _ -> "invalid_request"
        | true, item when n <= 0 || n > item.Reserved -> "invalid_request"
        | true, item ->
            item.Reserved <- item.Reserved - n
            item.Qty <- item.Qty - n
            "true"

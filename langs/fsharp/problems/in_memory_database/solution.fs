module Solution

open System
open System.Collections.Generic

type FieldVal(value: string, expiry: Nullable<int>) =
    member val Value = value with get, set
    member val Expiry = expiry with get, set

type BackupField(value: string, remaining: Nullable<int>) =
    member val Value = value with get, set
    member val Remaining = remaining with get, set

type InMemoryDatabase() =
    let database = Dictionary<string, Dictionary<string, FieldVal>>()
    let backupTimestamps = ResizeArray<int>()
    let backupStates = ResizeArray<Dictionary<string, Dictionary<string, BackupField>>>()

    let setInternal (key: string) (field: string) (value: string) (expiry: Nullable<int>) =
        let fields =
            match database.TryGetValue(key) with
            | true, existing -> existing
            | _ ->
                let created = Dictionary<string, FieldVal>()
                database[key] <- created
                created

        fields[field] <- FieldVal(value, expiry)
        ""

    let isAlive (key: string) (field: string) (timestamp: int) =
        match database.TryGetValue(key) with
        | false, _ -> false
        | true, fields ->
            if not (fields.ContainsKey(field)) then
                false
            else
                let expiry = fields[field].Expiry
                (not expiry.HasValue) || timestamp < expiry.Value

    member this.set(key: string, field: string, value: string) : string =
        setInternal key field value (Nullable())

    member this.get(key: string, field: string) : string =
        match database.TryGetValue(key) with
        | false, _ -> ""
        | true, fields ->
            if not (fields.ContainsKey(field)) then
                ""
            else
                fields[field].Value

    member this.delete(key: string, field: string) : string =
        match database.TryGetValue(key) with
        | false, _ -> "false"
        | true, fields ->
            if not (fields.ContainsKey(field)) then
                "false"
            else
                fields.Remove(field) |> ignore
                "true"

    member this.scan(key: string) : string =
        match database.TryGetValue(key) with
        | false, _ -> ""
        | true, fields ->
            let names = ResizeArray(fields.Keys)
            names.Sort(StringComparer.Ordinal)
            String.Join(", ", names |> Seq.map (fun field -> field + "(" + fields[field].Value + ")"))

    member this.scanByPrefix(key: string, prefix: string) : string =
        match database.TryGetValue(key) with
        | false, _ -> ""
        | true, fields ->
            let names =
                ResizeArray(
                    fields.Keys
                    |> Seq.filter (fun field -> field.StartsWith(prefix, StringComparison.Ordinal))
                )

            names.Sort(StringComparer.Ordinal)
            String.Join(", ", names |> Seq.map (fun field -> field + "(" + fields[field].Value + ")"))

    member this.setAt(key: string, field: string, value: string, timestamp: int) : string =
        ignore timestamp
        setInternal key field value (Nullable())

    member this.setAtWithTtl(key: string, field: string, value: string, timestamp: int, ttl: int) : string =
        setInternal key field value (Nullable(timestamp + ttl))

    member this.deleteAt(key: string, field: string, timestamp: int) : string =
        if not (isAlive key field timestamp) then
            "false"
        else
            database[key].Remove(field) |> ignore
            "true"

    member this.getAt(key: string, field: string, timestamp: int) : string =
        if not (isAlive key field timestamp) then
            ""
        else
            database[key].[field].Value

    member this.scanAt(key: string, timestamp: int) : string =
        match database.TryGetValue(key) with
        | false, _ -> ""
        | true, fields ->
            let names =
                ResizeArray(fields.Keys |> Seq.filter (fun field -> isAlive key field timestamp))

            names.Sort(StringComparer.Ordinal)
            String.Join(", ", names |> Seq.map (fun field -> field + "(" + fields[field].Value + ")"))

    member this.scanByPrefixAt(key: string, prefix: string, timestamp: int) : string =
        match database.TryGetValue(key) with
        | false, _ -> ""
        | true, fields ->
            let names =
                ResizeArray(
                    fields.Keys
                    |> Seq.filter (fun field ->
                        field.StartsWith(prefix, StringComparison.Ordinal)
                        && isAlive key field timestamp)
                )

            names.Sort(StringComparer.Ordinal)
            String.Join(", ", names |> Seq.map (fun field -> field + "(" + fields[field].Value + ")"))

    member this.backup(timestamp: int) : string =
        let state = Dictionary<string, Dictionary<string, BackupField>>()

        for keyEntry in database do
            let key = keyEntry.Key

            for fieldEntry in keyEntry.Value do
                let field = fieldEntry.Key

                if isAlive key field timestamp then
                    let pair = fieldEntry.Value

                    let remaining =
                        if pair.Expiry.HasValue then
                            Nullable(pair.Expiry.Value - timestamp)
                        else
                            Nullable()

                    let fields =
                        match state.TryGetValue(key) with
                        | true, existing -> existing
                        | _ ->
                            let created = Dictionary<string, BackupField>()
                            state[key] <- created
                            created

                    fields[field] <- BackupField(pair.Value, remaining)

        backupTimestamps.Add(timestamp)
        backupStates.Add(state)
        string state.Count

    member this.restore(timestamp: int, timestampToRestore: int) : string =
        let mutable idx = -1

        for i in 0 .. backupTimestamps.Count - 1 do
            if backupTimestamps[i] <= timestampToRestore then
                idx <- i

        let backup = backupStates[idx]
        database.Clear()

        for keyEntry in backup do
            for fieldEntry in keyEntry.Value do
                let pair = fieldEntry.Value

                let expiry =
                    if pair.Remaining.HasValue then
                        Nullable(timestamp + pair.Remaining.Value)
                    else
                        Nullable()

                setInternal keyEntry.Key fieldEntry.Key pair.Value expiry |> ignore

        ""

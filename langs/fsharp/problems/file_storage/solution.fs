module Solution

open System
open System.Collections.Generic

type StoredFile(name: string, size: int, owner: string) =
    member val Name = name with get, set
    member val Size = size with get, set
    member val Owner = owner with get, set

type Simulation() =
    let files = Dictionary<string, StoredFile>()
    let capacity = Dictionary<string, Nullable<int>>()
    let backups = Dictionary<string, Dictionary<string, int>>()

    do
        capacity["admin"] <- Nullable()

    let used (userId: string) =
        let mutable sum = 0

        for item in files.Values do
            if item.Owner = userId then
                sum <- sum + item.Size

        sum

    let remaining (userId: string) : Nullable<int> =
        match capacity.TryGetValue(userId) with
        | false, _ -> Nullable()
        | true, cap when cap.HasValue -> Nullable(cap.Value - used userId)
        | _ -> Nullable()

    member this.addFile(name: string, size: int) : string =
        if files.ContainsKey(name) then
            "false"
        else
            files[name] <- StoredFile(name, size, "admin")
            "true"

    member this.getFileSize(name: string) : string =
        match files.TryGetValue(name) with
        | true, item -> string item.Size
        | _ -> ""

    member this.deleteFile(name: string) : string =
        match files.TryGetValue(name) with
        | false, _ -> ""
        | true, item ->
            files.Remove(name) |> ignore
            string item.Size

    member this.copyFile(source: string, dest: string) : string =
        match files.TryGetValue(source) with
        | false, _ -> ""
        | true, src when source = dest -> string src.Size
        | true, src ->
            let destItem =
                match files.TryGetValue(dest) with
                | true, item -> Some item
                | _ -> None

            let owner =
                match destItem with
                | None -> src.Owner
                | Some item -> item.Owner

            let extra =
                match destItem with
                | None -> src.Size
                | Some item -> src.Size - item.Size

            let left = remaining owner

            if left.HasValue && extra > left.Value then
                ""
            else
                match destItem with
                | None -> files[dest] <- StoredFile(dest, src.Size, owner)
                | Some item -> item.Size <- src.Size

                string src.Size

    member this.getNLargest(prefix: string, n: int) : string =
        let matched =
            ResizeArray(
                files.Values
                |> Seq.filter (fun item -> item.Name.StartsWith(prefix, StringComparison.Ordinal))
            )

        matched.Sort(fun a b ->
            let d = b.Size.CompareTo(a.Size)
            if d <> 0 then d else String.CompareOrdinal(a.Name, b.Name))

        if n < matched.Count then
            matched.RemoveRange(n, matched.Count - n)

        String.Join(", ", matched |> Seq.map (fun item -> item.Name + "(" + string item.Size + ")"))

    member this.addUser(userId: string, cap: int) : string =
        if capacity.ContainsKey(userId) then
            "false"
        else
            capacity[userId] <- Nullable(cap)
            "true"

    member this.addFileBy(userId: string, name: string, size: int) : string =
        if not (capacity.ContainsKey(userId)) || files.ContainsKey(name) then
            ""
        else
            let left = remaining userId

            if left.HasValue && size > left.Value then
                ""
            else
                files[name] <- StoredFile(name, size, userId)
                let after = remaining userId
                if after.HasValue then string after.Value else ""

    member this.mergeUser(userId1: string, userId2: string) : string =
        if userId1 = userId2 then
            ""
        else
            match capacity.TryGetValue(userId1), capacity.TryGetValue(userId2) with
            | (true, cap1), (true, cap2) when cap1.HasValue && cap2.HasValue ->
                capacity[userId1] <- Nullable(cap1.Value + cap2.Value)

                for item in files.Values do
                    if item.Owner = userId2 then
                        item.Owner <- userId1

                capacity.Remove(userId2) |> ignore
                backups.Remove(userId2) |> ignore
                let left = remaining userId1
                if left.HasValue then string left.Value else ""
            | _ -> ""

    member this.backupUser(userId: string) : string =
        if not (capacity.ContainsKey(userId)) then
            ""
        else
            let snap = Dictionary<string, int>()

            for item in files.Values do
                if item.Owner = userId then
                    snap[item.Name] <- item.Size

            backups[userId] <- snap
            string snap.Count

    member this.restoreUser(userId: string) : string =
        if not (capacity.ContainsKey(userId)) then
            ""
        else
            let owned =
                files
                |> Seq.filter (fun pair -> pair.Value.Owner = userId)
                |> Seq.map (fun pair -> pair.Key)
                |> Seq.toList

            for name in owned do
                files.Remove(name) |> ignore

            match backups.TryGetValue(userId) with
            | false, _ -> "0"
            | true, snap ->
                let mutable restored = 0

                for entry in snap do
                    if not (files.ContainsKey(entry.Key)) then
                        let left = remaining userId

                        if not (left.HasValue && entry.Value > left.Value) then
                            files[entry.Key] <- StoredFile(entry.Key, entry.Value, userId)
                            restored <- restored + 1

                string restored

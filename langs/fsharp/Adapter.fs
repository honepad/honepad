module Adapter

open System
open System.Collections.Generic
open System.Reflection
open System.Text
open System.Text.Json

let private toCamel (snake: string) =
    let parts = snake.Split('_')
    let output = StringBuilder()
    let mutable first = true

    for part in parts do
        if part.Length > 0 then
            if first then
                output.Append(Char.ToLowerInvariant(part[0])) |> ignore
                first <- false
            else
                output.Append(Char.ToUpperInvariant(part[0])) |> ignore

            if part.Length > 1 then
                output.Append(part.Substring(1)) |> ignore

    output.ToString()

let rec private unwrap (exc: Exception) =
    match exc with
    | :? TargetInvocationException as tie when not (isNull tie.InnerException) -> unwrap tie.InnerException
    | _ -> exc

let private failRow (caseId: string) (index: int) (methodName: string) (expected: JsonElement) (actual: obj) =
    let row = Dictionary<string, obj>()
    row["case"] <- caseId
    row["index"] <- index
    row["method"] <- methodName
    row["expected"] <- expected
    row["actual"] <- actual
    row

let private findMethod (typ: Type) (name: string) (argc: int) =
    typ.GetMethods()
    |> Array.tryFind (fun method -> method.Name = name && method.GetParameters().Length = argc)

let private convertArg (arg: JsonElement) (dest: Type) : obj =
    let inner = Nullable.GetUnderlyingType(dest)
    let target = if isNull inner then dest else inner

    if arg.ValueKind = JsonValueKind.Null then
        if dest.IsValueType && isNull (Nullable.GetUnderlyingType(dest)) then
            raise (ArgumentException("null for non-nullable " + dest.Name))

        null
    elif target = typeof<string> then
        if arg.ValueKind <> JsonValueKind.String then
            raise (ArgumentException("cannot convert " + string arg.ValueKind + " to string"))

        box (arg.GetString())
    elif target = typeof<int> then
        if arg.ValueKind <> JsonValueKind.Number then
            raise (ArgumentException("cannot convert " + string arg.ValueKind + " to int"))

        box (arg.GetInt32())
    elif target = typeof<int64> then
        if arg.ValueKind <> JsonValueKind.Number then
            raise (ArgumentException("cannot convert " + string arg.ValueKind + " to long"))

        box (arg.GetInt64())
    elif target = typeof<bool> then
        if arg.ValueKind <> JsonValueKind.True && arg.ValueKind <> JsonValueKind.False then
            raise (ArgumentException("cannot convert " + string arg.ValueKind + " to bool"))

        box (arg.GetBoolean())
    else
        raise (ArgumentException("cannot convert " + string arg.ValueKind + " to " + dest.Name))

let private invoke (obj: obj) (name: string) (argv: JsonElement list) =
    match findMethod (obj.GetType()) name argv.Length with
    | None -> raise (MissingMethodException(name))
    | Some method ->
        let types = method.GetParameters()
        let converted =
            argv
            |> List.mapi (fun i arg -> convertArg arg types[i].ParameterType)
            |> List.toArray

        method.Invoke(obj, converted)

let private jsonEqual (actual: obj) (expected: JsonElement) =
    JsonSerializer.Serialize(actual) = JsonSerializer.Serialize(expected)

[<EntryPoint>]
let main (args: string[]) =
    let positional =
        args
        |> Array.toList
        |> List.filter (fun item -> item.Length > 0 && item <> "--" && not (item.StartsWith('-')))

    if positional.Length < 2 then
        eprintfn "usage: honepadrun cases.json ClassName"
        2
    else
        let casesPath = positional[0]
        let className = positional[1]
        use doc = JsonDocument.Parse(IO.File.ReadAllText(casesPath))

        if doc.RootElement.ValueKind <> JsonValueKind.Array then
            raise (InvalidOperationException("cases.json must be a JSON list"))

        let typ =
            Assembly.GetExecutingAssembly().GetTypes()
            |> Array.tryFind (fun item -> item.Name = className)
            |> Option.defaultWith (fun () -> raise (InvalidOperationException("missing type " + className)))

        let failed = ResizeArray<Dictionary<string, obj>>()
        let mutable passed = 0

        for row in doc.RootElement.EnumerateArray() do
            let instance = Activator.CreateInstance(typ)

            if isNull instance then
                raise (InvalidOperationException("could not construct " + className))

            let caseId =
                match row.GetProperty("id").GetString() with
                | null -> ""
                | value -> value

            let calls = row.GetProperty("calls")
            let mutable ok = true
            let mutable index = 0

            for call in calls.EnumerateArray() do
                if ok then
                    let methodSnake =
                        match call.GetProperty("m").GetString() with
                        | null -> ""
                        | value -> value

                    let name = toCamel methodSnake
                    let argv = call.GetProperty("a").EnumerateArray() |> Seq.toList
                    let expected = call.GetProperty("e")

                    try
                        let actual = invoke instance name argv

                        if not (jsonEqual actual expected) then
                            failed.Add(failRow caseId index methodSnake expected actual)
                            ok <- false
                    with exc ->
                        failed.Add(failRow caseId index methodSnake expected ("exc:" + (unwrap exc).GetType().Name))
                        ok <- false

                    if ok then
                        index <- index + 1

            if ok then
                passed <- passed + 1

        let report = Dictionary<string, obj>()
        report["passed"] <- passed
        report["failed"] <- failed
        printfn "%s" (JsonSerializer.Serialize(report))
        if failed.Count = 0 then 0 else 1

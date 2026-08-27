module Solution

open System
open System.Collections.Generic

type Account(accountId: string, createdAt: int) =
    member val AccountId = accountId with get, set
    member val Balance = 0 with get, set
    member val Outgoing = 0 with get, set
    member val Payments = Dictionary<string, string>() with get
    member val CreatedAt = createdAt with get, set
    member val BalanceHistory = ResizeArray<int[]>([| [| createdAt; 0 |] |]) with get

    member this.RecordBalance(timestamp: int) =
        this.BalanceHistory.Add([| timestamp; this.Balance |])

    member this.Deposit(amount: int) =
        this.Balance <- this.Balance + amount
        this.Balance

    member this.Withdraw(amount: int) =
        if this.Balance < amount then
            false
        else
            this.Balance <- this.Balance - amount
            this.Outgoing <- this.Outgoing + amount
            true

    member this.GetBalanceAt(timeAt: int) : Nullable<int> =
        if timeAt < this.CreatedAt then
            Nullable()
        else
            let mutable result = Nullable()

            for row in this.BalanceHistory do
                if row[0] <= timeAt then
                    result <- Nullable(row[1])

            result

type Cashback(timestamp: int, accountId: string, amount: int, paymentId: string) =
    member val Timestamp = timestamp with get, set
    member val AccountId = accountId with get, set
    member val Amount = amount with get, set
    member val PaymentId = paymentId with get, set

type Simulation() =
    let cashbackDelay = 24 * 60 * 60 * 1000
    let accounts = Dictionary<string, Account>()
    let mutable paymentCounter = 0
    let pendingCashbacks = ResizeArray<Cashback>()

    let processCashbacks (timestamp: int) =
        while pendingCashbacks.Count > 0 && pendingCashbacks[0].Timestamp <= timestamp do
            let cashback = pendingCashbacks[0]
            pendingCashbacks.RemoveAt(0)

            match accounts.TryGetValue(cashback.AccountId) with
            | true, account ->
                account.Deposit(cashback.Amount) |> ignore
                account.Payments[cashback.PaymentId] <- "CASHBACK_RECEIVED"
                account.RecordBalance(cashback.Timestamp)
            | _ -> ()

    member this.createAccount(timestamp: int, accountId: string) : bool =
        processCashbacks timestamp

        if accounts.ContainsKey(accountId) then
            false
        else
            accounts[accountId] <- Account(accountId, timestamp)
            true

    member this.deposit(timestamp: int, accountId: string, amount: int) : Nullable<int> =
        processCashbacks timestamp

        match accounts.TryGetValue(accountId) with
        | false, _ -> Nullable()
        | true, account ->
            let result = account.Deposit(amount)
            account.RecordBalance(timestamp)
            Nullable(result)

    member this.transfer
        (timestamp: int, sourceAccountId: string, targetAccountId: string, amount: int)
        : Nullable<int> =
        processCashbacks timestamp

        match accounts.TryGetValue(sourceAccountId), accounts.TryGetValue(targetAccountId) with
        | (true, source), (true, target) when sourceAccountId <> targetAccountId ->
            if not (source.Withdraw(amount)) then
                Nullable()
            else
                target.Deposit(amount) |> ignore
                source.RecordBalance(timestamp)
                target.RecordBalance(timestamp)
                Nullable(source.Balance)
        | _ -> Nullable()

    member this.topSpenders(timestamp: int, n: int) : ResizeArray<string> =
        processCashbacks timestamp
        let ids = ResizeArray(accounts.Keys)

        ids.Sort(fun a b ->
            let d = accounts[b].Outgoing.CompareTo(accounts[a].Outgoing)
            if d <> 0 then d else String.CompareOrdinal(a, b))

        if n < ids.Count then
            ids.RemoveRange(n, ids.Count - n)

        ResizeArray(ids |> Seq.map (fun id -> id + "(" + string accounts[id].Outgoing + ")"))

    member this.pay(timestamp: int, accountId: string, amount: int) : string =
        processCashbacks timestamp

        match accounts.TryGetValue(accountId) with
        | false, _ -> null
        | true, account ->
            if not (account.Withdraw(amount)) then
                null
            else
                paymentCounter <- paymentCounter + 1
                let paymentId = "payment" + string paymentCounter
                account.Payments[paymentId] <- "IN_PROGRESS"
                account.RecordBalance(timestamp)

                pendingCashbacks.Add(
                    Cashback(timestamp + cashbackDelay, accountId, (amount * 2) / 100, paymentId)
                )

                paymentId

    member this.getPaymentStatus(timestamp: int, accountId: string, payment: string) : string =
        processCashbacks timestamp

        match accounts.TryGetValue(accountId) with
        | false, _ -> null
        | true, account ->
            match account.Payments.TryGetValue(payment) with
            | true, status -> status
            | _ -> null

    member this.mergeAccounts(timestamp: int, accountId1: string, accountId2: string) : bool =
        processCashbacks timestamp

        if accountId1 = accountId2 then
            false
        else
            match accounts.TryGetValue(accountId1), accounts.TryGetValue(accountId2) with
            | (true, account1), (true, account2) ->
                account1.Balance <- account1.Balance + account2.Balance
                account1.Outgoing <- account1.Outgoing + account2.Outgoing

                for pair in account2.Payments do
                    account1.Payments[pair.Key] <- pair.Value

                account1.BalanceHistory.AddRange(account2.BalanceHistory)
                account1.BalanceHistory.Sort(fun a b -> a[0].CompareTo(b[0]))
                account1.CreatedAt <- Math.Min(account1.CreatedAt, account2.CreatedAt)
                account1.RecordBalance(timestamp)

                for cashback in pendingCashbacks do
                    if cashback.AccountId = accountId2 then
                        cashback.AccountId <- accountId1

                accounts.Remove(accountId2) |> ignore
                true
            | _ -> false

    member this.getBalance(timestamp: int, accountId: string, timeAt: int) : Nullable<int> =
        processCashbacks timestamp

        match accounts.TryGetValue(accountId) with
        | false, _ -> Nullable()
        | true, account -> account.GetBalanceAt(timeAt)

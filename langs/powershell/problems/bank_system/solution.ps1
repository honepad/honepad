class Account {
    [string] $AccountId
    [long] $Balance
    [long] $Outgoing
    [hashtable] $Payments
    [long] $CreatedAt
    [System.Collections.Generic.List[object]] $BalanceHistory

    Account([string] $AccountId, [long] $CreatedAt) {
        $this.AccountId = $AccountId
        $this.Balance = 0
        $this.Outgoing = 0
        $this.Payments = @{}
        $this.CreatedAt = $CreatedAt
        $this.BalanceHistory = [System.Collections.Generic.List[object]]::new()
        $this.BalanceHistory.Add(@($CreatedAt, [long]0))
    }

    [void] RecordBalance([long] $Timestamp) {
        $this.BalanceHistory.Add(@($Timestamp, $this.Balance))
    }

    [long] Deposit([long] $Amount) {
        $this.Balance += $Amount
        return $this.Balance
    }

    [bool] Withdraw([long] $Amount) {
        if ($this.Balance -lt $Amount) {
            return $false
        }
        $this.Balance -= $Amount
        $this.Outgoing += $Amount
        return $true
    }

    [object] GetBalanceAt([long] $TimeAt) {
        if ($TimeAt -lt $this.CreatedAt) {
            return $null
        }
        $result = $null
        foreach ($row in $this.BalanceHistory) {
            if ([long]$row[0] -le $TimeAt) {
                $result = [long]$row[1]
            }
            else {
                break
            }
        }
        return $result
    }
}

class Simulation {
    [hashtable] $Accounts
    [long] $PaymentCounter
    [System.Collections.Generic.List[object]] $PendingCashbacks
    [long] $CashbackDelay

    Simulation() {
        $this.Accounts = @{}
        $this.PaymentCounter = 0
        $this.PendingCashbacks = [System.Collections.Generic.List[object]]::new()
        $this.CashbackDelay = 24L * 60L * 60L * 1000L
    }

    [void] ProcessCashbacks([long] $Timestamp) {
        while ($this.PendingCashbacks.Count -gt 0 -and [long]$this.PendingCashbacks[0][0] -le $Timestamp) {
            $row = $this.PendingCashbacks[0]
            $this.PendingCashbacks.RemoveAt(0)
            $cbTs = [long]$row[0]
            $accountId = [string]$row[1]
            $amount = [long]$row[2]
            $paymentId = [string]$row[3]
            if ($this.Accounts.ContainsKey($accountId)) {
                $account = $this.Accounts[$accountId]
                [void] $account.Deposit($amount)
                $account.Payments[$paymentId] = 'CASHBACK_RECEIVED'
                $account.RecordBalance($cbTs)
            }
        }
    }

    [object] createAccount([long] $Timestamp, [string] $AccountId) {
        $this.ProcessCashbacks($Timestamp)
        if ($this.Accounts.ContainsKey($AccountId)) {
            return $false
        }
        $this.Accounts[$AccountId] = [Account]::new($AccountId, $Timestamp)
        return $true
    }

    [object] deposit([long] $Timestamp, [string] $AccountId, [long] $Amount) {
        $this.ProcessCashbacks($Timestamp)
        if (-not $this.Accounts.ContainsKey($AccountId)) {
            return $null
        }
        $account = $this.Accounts[$AccountId]
        $result = $account.Deposit($Amount)
        $account.RecordBalance($Timestamp)
        return $result
    }

    [object] transfer([long] $Timestamp, [string] $SourceAccountId, [string] $TargetAccountId, [long] $Amount) {
        $this.ProcessCashbacks($Timestamp)
        if (-not $this.Accounts.ContainsKey($SourceAccountId) -or -not $this.Accounts.ContainsKey($TargetAccountId)) {
            return $null
        }
        if ($SourceAccountId -eq $TargetAccountId) {
            return $null
        }
        $source = $this.Accounts[$SourceAccountId]
        $target = $this.Accounts[$TargetAccountId]
        if (-not $source.Withdraw($Amount)) {
            return $null
        }
        [void] $target.Deposit($Amount)
        $source.RecordBalance($Timestamp)
        $target.RecordBalance($Timestamp)
        return $source.Balance
    }

    [object] topSpenders([long] $Timestamp, [long] $N) {
        $this.ProcessCashbacks($Timestamp)
        $rows = foreach ($id in $this.Accounts.Keys) {
            [pscustomobject]@{
                Id  = [string]$id
                Out = [long]$this.Accounts[$id].Outgoing
            }
        }
        $ordered = @($rows | Sort-Object -Property @{ Expression = 'Out'; Descending = $true }, @{ Expression = 'Id'; Descending = $false })
        $top = @($ordered | Select-Object -First $N)
        return @($top | ForEach-Object { "$($_.Id)($($_.Out))" })
    }

    [object] pay([long] $Timestamp, [string] $AccountId, [long] $Amount) {
        $this.ProcessCashbacks($Timestamp)
        if (-not $this.Accounts.ContainsKey($AccountId)) {
            return $null
        }
        $account = $this.Accounts[$AccountId]
        if (-not $account.Withdraw($Amount)) {
            return $null
        }
        $this.PaymentCounter += 1
        $paymentId = "payment$($this.PaymentCounter)"
        $account.Payments[$paymentId] = 'IN_PROGRESS'
        $account.RecordBalance($Timestamp)
        $cashback = [long][Math]::Floor(($Amount * 2) / 100)
        $this.PendingCashbacks.Add(@(($Timestamp + $this.CashbackDelay), $AccountId, $cashback, $paymentId))
        return $paymentId
    }

    [object] getPaymentStatus([long] $Timestamp, [string] $AccountId, [string] $Payment) {
        $this.ProcessCashbacks($Timestamp)
        if (-not $this.Accounts.ContainsKey($AccountId)) {
            return $null
        }
        $account = $this.Accounts[$AccountId]
        if (-not $account.Payments.ContainsKey($Payment)) {
            return $null
        }
        return [string]$account.Payments[$Payment]
    }

    [object] mergeAccounts([long] $Timestamp, [string] $AccountId1, [string] $AccountId2) {
        $this.ProcessCashbacks($Timestamp)
        if ($AccountId1 -eq $AccountId2) {
            return $false
        }
        if (-not $this.Accounts.ContainsKey($AccountId1) -or -not $this.Accounts.ContainsKey($AccountId2)) {
            return $false
        }
        $keep = $this.Accounts[$AccountId1]
        $drop = $this.Accounts[$AccountId2]
        $keep.Balance += $drop.Balance
        $keep.Outgoing += $drop.Outgoing
        foreach ($key in @($drop.Payments.Keys)) {
            $keep.Payments[$key] = $drop.Payments[$key]
        }
        foreach ($row in $drop.BalanceHistory) {
            $keep.BalanceHistory.Add($row)
        }
        $sorted = [System.Collections.Generic.List[object]]::new()
        foreach ($row in ($keep.BalanceHistory | Sort-Object { [long]$_[0] })) {
            $sorted.Add($row)
        }
        $keep.BalanceHistory = $sorted
        if ($drop.CreatedAt -lt $keep.CreatedAt) {
            $keep.CreatedAt = $drop.CreatedAt
        }
        $keep.RecordBalance($Timestamp)
        for ($i = 0; $i -lt $this.PendingCashbacks.Count; $i++) {
            $row = $this.PendingCashbacks[$i]
            if ([string]$row[1] -eq $AccountId2) {
                $this.PendingCashbacks[$i] = @($row[0], $AccountId1, $row[2], $row[3])
            }
        }
        $this.Accounts.Remove($AccountId2)
        return $true
    }

    [object] getBalance([long] $Timestamp, [string] $AccountId, [long] $TimeAt) {
        $this.ProcessCashbacks($Timestamp)
        if (-not $this.Accounts.ContainsKey($AccountId)) {
            return $null
        }
        return $this.Accounts[$AccountId].GetBalanceAt($TimeAt)
    }
}

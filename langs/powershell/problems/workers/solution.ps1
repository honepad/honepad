class Worker {
    [string] $WorkerId
    [string] $Position
    [long] $Compensation
    [bool] $InOffice
    $EnteredAt
    [System.Collections.Generic.List[object]] $Finished
    $PendingPromo

    Worker([string] $WorkerId, [string] $Position, [long] $Compensation) {
        $this.WorkerId = $WorkerId
        $this.Position = $Position
        $this.Compensation = $Compensation
        $this.InOffice = $false
        $this.EnteredAt = $null
        $this.Finished = [System.Collections.Generic.List[object]]::new()
        $this.PendingPromo = $null
    }

    [long] TotalTime() {
        $sum = [long]0
        foreach ($row in $this.Finished) {
            $sum += [long]$row[1] - [long]$row[0]
        }
        return $sum
    }

    [long] PositionTime([string] $Position) {
        $sum = [long]0
        foreach ($row in $this.Finished) {
            if ([string]$row[3] -eq $Position) {
                $sum += [long]$row[1] - [long]$row[0]
            }
        }
        return $sum
    }

    [void] ApplyPromoOnEnter([long] $Timestamp) {
        if ($null -eq $this.PendingPromo) {
            return
        }
        $newPos = [string]$this.PendingPromo[0]
        $newComp = [long]$this.PendingPromo[1]
        $startTs = [long]$this.PendingPromo[2]
        if ($Timestamp -ge $startTs) {
            $this.Position = $newPos
            $this.Compensation = $newComp
            $this.PendingPromo = $null
        }
    }
}

class Simulation {
    [hashtable] $Workers

    Simulation() {
        $this.Workers = @{}
    }

    [object] addWorker([string] $WorkerId, [string] $Position, [long] $Compensation) {
        if ($this.Workers.ContainsKey($WorkerId)) {
            return 'false'
        }
        $this.Workers[$WorkerId] = [Worker]::new($WorkerId, $Position, $Compensation)
        return 'true'
    }

    [object] register([string] $WorkerId, [long] $Timestamp) {
        if (-not $this.Workers.ContainsKey($WorkerId)) {
            return 'invalid_request'
        }
        $worker = $this.Workers[$WorkerId]
        if ($worker.InOffice) {
            $worker.Finished.Add(@($worker.EnteredAt, $Timestamp, $worker.Compensation, $worker.Position))
            $worker.InOffice = $false
            $worker.EnteredAt = $null
            return 'registered'
        }
        $worker.ApplyPromoOnEnter($Timestamp)
        $worker.InOffice = $true
        $worker.EnteredAt = $Timestamp
        return 'registered'
    }

    [object] get([string] $WorkerId) {
        if (-not $this.Workers.ContainsKey($WorkerId)) {
            return ''
        }
        return [string]$this.Workers[$WorkerId].TotalTime()
    }

    [object] topNWorkers([long] $N, [string] $Position) {
        $matched = @(
            $this.Workers.Values |
                Where-Object { $_.Position -eq $Position } |
                ForEach-Object {
                    [pscustomobject]@{
                        Worker = $_
                        Time   = $_.PositionTime($Position)
                    }
                } |
                Sort-Object -Property @{ Expression = 'Time'; Descending = $true }, @{ Expression = { $_.Worker.WorkerId }; Descending = $false }
        )
        $top = @($matched | Select-Object -First $N)
        return (($top | ForEach-Object { "$($_.Worker.WorkerId)($($_.Time))" }) -join ', ')
    }

    [object] promote([string] $WorkerId, [string] $NewPosition, [long] $NewCompensation, [long] $StartTimestamp) {
        if (-not $this.Workers.ContainsKey($WorkerId)) {
            return 'invalid_request'
        }
        $worker = $this.Workers[$WorkerId]
        if ($null -ne $worker.PendingPromo) {
            return 'invalid_request'
        }
        $worker.PendingPromo = @($NewPosition, $NewCompensation, $StartTimestamp)
        return 'success'
    }

    [object] calcSalary([string] $WorkerId, [long] $StartTimestamp, [long] $EndTimestamp) {
        if (-not $this.Workers.ContainsKey($WorkerId)) {
            return ''
        }
        $worker = $this.Workers[$WorkerId]
        $total = [long]0
        foreach ($row in $worker.Finished) {
            $lo = [Math]::Max([long]$row[0], $StartTimestamp)
            $hi = [Math]::Min([long]$row[1], $EndTimestamp)
            if ($hi -gt $lo) {
                $total += ($hi - $lo) * [long]$row[2]
            }
        }
        return [string]$total
    }
}

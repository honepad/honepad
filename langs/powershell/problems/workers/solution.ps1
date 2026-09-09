class Worker {
    [string] $WorkerId
    [string] $Position
    [long] $Compensation
    [bool] $InOffice
    $EnteredAt
    [System.Collections.Generic.List[object]] $Finished
    $PendingPromo
    [System.Collections.Generic.List[object]] $DoublePay

    Worker([string] $WorkerId, [string] $Position, [long] $Compensation) {
        $this.WorkerId = $WorkerId
        $this.Position = $Position
        $this.Compensation = $Compensation
        $this.InOffice = $false
        $this.EnteredAt = $null
        $this.Finished = [System.Collections.Generic.List[object]]::new()
        $this.PendingPromo = $null
        $this.DoublePay = [System.Collections.Generic.List[object]]::new()
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

    [object] setDoublePay([string] $WorkerId, [long] $IntervalBegin, [long] $IntervalEnd) {
        if (-not $this.Workers.ContainsKey($WorkerId) -or $IntervalEnd -le $IntervalBegin) {
            return 'invalid_request'
        }
        $this.Workers[$WorkerId].DoublePay.Add(@($IntervalBegin, $IntervalEnd))
        return 'true'
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
                $bonus = [Simulation]::BonusOverlap($lo, $hi, $worker.DoublePay)
                $total += ($hi - $lo - $bonus) * [long]$row[2] + $bonus * [long]$row[2] * 2
            }
        }
        return [string]$total
    }

    static [long] BonusOverlap([long] $Lo, [long] $Hi, $Windows) {
        $segs = [System.Collections.Generic.List[object]]::new()
        foreach ($win in $Windows) {
            $start = [Math]::Max($Lo, [long]$win[0])
            $stop = [Math]::Min($Hi, [long]$win[1])
            if ($stop -gt $start) {
                $segs.Add(@($start, $stop))
            }
        }
        $ordered = @($segs | Sort-Object { $_[0] })
        $merged = [System.Collections.Generic.List[object]]::new()
        foreach ($seg in $ordered) {
            if ($merged.Count -eq 0 -or $seg[0] -ge $merged[$merged.Count - 1][1]) {
                $merged.Add(@([long]$seg[0], [long]$seg[1]))
            } else {
                $last = $merged[$merged.Count - 1]
                if ([long]$seg[1] -gt [long]$last[1]) {
                    $last[1] = [long]$seg[1]
                }
            }
        }
        $sum = [long]0
        foreach ($seg in $merged) {
            $sum += [long]$seg[1] - [long]$seg[0]
        }
        return $sum
    }
}

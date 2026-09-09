class Backend {
    [string] $BackendId
    [bool] $Health
    [long] $Weight
    [long] $Inflight

    Backend([string] $BackendId) {
        $this.BackendId = $BackendId
        $this.Health = $true
        $this.Weight = 1
        $this.Inflight = 0
    }
}

class Simulation {
    [System.Collections.Generic.List[Backend]] $Backends
    [hashtable] $ById
    [long] $Cursor
    [hashtable] $StickyMap
    [bool] $UseLeast

    Simulation() {
        $this.Backends = [System.Collections.Generic.List[Backend]]::new()
        $this.ById = @{}
        $this.Cursor = 0
        $this.StickyMap = @{}
        $this.UseLeast = $false
    }

    hidden [void] ResetCycle() {
        $this.Cursor = 0
        $this.UseLeast = $false
        foreach ($item in $this.Backends) {
            $item.Inflight = 0
        }
    }

    hidden [System.Collections.Generic.List[Backend]] Tickets([System.Collections.Generic.List[Backend]] $Items) {
        $out = [System.Collections.Generic.List[Backend]]::new()
        foreach ($item in $Items) {
            for ($i = 0; $i -lt $item.Weight; $i++) {
                $out.Add($item)
            }
        }
        return $out
    }

    hidden [Backend] Pick() {
        $healthy = [System.Collections.Generic.List[Backend]]::new()
        foreach ($item in $this.Backends) {
            if ($item.Health) {
                $healthy.Add($item)
            }
        }
        if ($healthy.Count -eq 0) {
            return $null
        }
        $pool = $healthy
        if ($this.UseLeast) {
            $least = $healthy[0].Inflight
            foreach ($item in $healthy) {
                if ($item.Inflight -lt $least) {
                    $least = $item.Inflight
                }
            }
            $pool = [System.Collections.Generic.List[Backend]]::new()
            foreach ($item in $healthy) {
                if ($item.Inflight -eq $least) {
                    $pool.Add($item)
                }
            }
        }
        $tickets = $this.Tickets($pool)
        if ($tickets.Count -eq 0) {
            return $null
        }
        $chosen = $tickets[$this.Cursor % $tickets.Count]
        $this.Cursor += 1
        return $chosen
    }

    hidden [string] Take() {
        $item = $this.Pick()
        if ($null -eq $item) {
            return ''
        }
        $item.Inflight += 1
        return $item.BackendId
    }

    [object] addBackend([string] $BackendId) {
        if ($this.ById.ContainsKey($BackendId)) {
            return 'false'
        }
        $item = [Backend]::new($BackendId)
        $this.Backends.Add($item)
        $this.ById[$BackendId] = $item
        return 'true'
    }

    [object] setHealth([string] $BackendId, [long] $Flag) {
        if (-not $this.ById.ContainsKey($BackendId) -or ($Flag -ne 0 -and $Flag -ne 1)) {
            return 'invalid_request'
        }
        $item = $this.ById[$BackendId]
        $item.Health = $Flag -eq 1
        $this.ResetCycle()
        return 'true'
    }

    [object] setWeight([string] $BackendId, [long] $Weight) {
        if (-not $this.ById.ContainsKey($BackendId) -or $Weight -le 0) {
            return 'invalid_request'
        }
        $item = $this.ById[$BackendId]
        $item.Weight = $Weight
        $this.ResetCycle()
        return 'true'
    }

    [object] route() {
        return $this.Take()
    }

    [object] sticky([string] $ClientId) {
        if ($this.StickyMap.ContainsKey($ClientId)) {
            $bound = [string] $this.StickyMap[$ClientId]
            if ($this.ById.ContainsKey($bound)) {
                $item = $this.ById[$bound]
                if ($item.Health) {
                    $item.Inflight += 1
                    return $item.BackendId
                }
            }
        }
        $chosen = $this.Take()
        if (-not [string]::IsNullOrEmpty($chosen)) {
            $this.StickyMap[$ClientId] = $chosen
        }
        return $chosen
    }

    [object] done([string] $BackendId) {
        if (-not $this.ById.ContainsKey($BackendId)) {
            return 'invalid_request'
        }
        $item = $this.ById[$BackendId]
        if ($item.Inflight -le 0) {
            return 'invalid_request'
        }
        $item.Inflight -= 1
        $this.UseLeast = $true
        return 'true'
    }
}

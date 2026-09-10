class Simulation {
    [hashtable] $Subs
    [hashtable] $InboxMap
    [hashtable] $Retained

    Simulation() {
        $this.Subs = @{}
        $this.InboxMap = @{}
        $this.Retained = @{}
    }

    [object] subscribe([string] $Topic, [string] $Client) {
        if (-not $this.Subs.ContainsKey($Topic)) {
            $this.Subs[$Topic] = [System.Collections.Generic.List[string]]::new()
        }
        $clients = $this.Subs[$Topic]
        if ($clients.Contains($Client)) {
            return 'false'
        }
        $clients.Add($Client)
        if ($this.Retained.ContainsKey($Topic)) {
            if (-not $this.InboxMap.ContainsKey($Client)) {
                $this.InboxMap[$Client] = [System.Collections.Generic.List[string]]::new()
            }
            $this.InboxMap[$Client].Add("${Topic}:$($this.Retained[$Topic])")
        }
        return 'true'
    }

    [object] unsubscribe([string] $Topic, [string] $Client) {
        if (-not $this.Subs.ContainsKey($Topic)) {
            return 'false'
        }
        $clients = $this.Subs[$Topic]
        if (-not $clients.Contains($Client)) {
            return 'false'
        }
        [void]$clients.Remove($Client)
        if ($clients.Count -eq 0) {
            $this.Subs.Remove($Topic)
        }
        return 'true'
    }

    [object] publish([string] $Topic, [string] $Message) {
        $clients = @()
        if ($this.Subs.ContainsKey($Topic)) {
            $clients = @($this.Subs[$Topic])
        }
        $payload = "${Topic}:${Message}"
        foreach ($client in $clients) {
            if (-not $this.InboxMap.ContainsKey($client)) {
                $this.InboxMap[$client] = [System.Collections.Generic.List[string]]::new()
            }
            $this.InboxMap[$client].Add($payload)
        }
        return [string]$clients.Count
    }

    [object] inbox([string] $Client) {
        if (-not $this.InboxMap.ContainsKey($Client)) {
            return ''
        }
        return ($this.InboxMap[$Client] -join ', ')
    }

    [object] listTopics() {
        $topics = @($this.Subs.Keys | Sort-Object)
        return ($topics -join ', ')
    }

    [object] subscribers([string] $Topic) {
        if (-not $this.Subs.ContainsKey($Topic)) {
            return ''
        }
        $clients = @($this.Subs[$Topic] | Sort-Object)
        return ($clients -join ', ')
    }

    [object] peek([string] $Client) {
        if (-not $this.InboxMap.ContainsKey($Client) -or $this.InboxMap[$Client].Count -eq 0) {
            return ''
        }
        return $this.InboxMap[$Client][0]
    }

    [object] ack([string] $Client, [long] $N) {
        if ($N -le 0 -or -not $this.InboxMap.ContainsKey($Client)) {
            return 'invalid_request'
        }
        $items = $this.InboxMap[$Client]
        if ($N -gt $items.Count) {
            return 'invalid_request'
        }
        $items.RemoveRange(0, [int]$N)
        return [string]$items.Count
    }

    [object] retain([string] $Topic, [string] $Message) {
        $this.Retained[$Topic] = $Message
        return ''
    }
}

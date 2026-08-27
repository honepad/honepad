class InMemoryDatabase {
    [hashtable] $Database
    [System.Collections.Generic.List[long]] $BackupTimestamps
    [System.Collections.Generic.List[object]] $BackupStates

    InMemoryDatabase() {
        $this.Database = @{}
        $this.BackupTimestamps = [System.Collections.Generic.List[long]]::new()
        $this.BackupStates = [System.Collections.Generic.List[object]]::new()
    }

    [string] SetInternal([string] $Key, [string] $Field, [string] $Value, $Expiry) {
        if (-not $this.Database.ContainsKey($Key)) {
            $this.Database[$Key] = @{}
        }
        $this.Database[$Key][$Field] = @($Value, $Expiry)
        return ''
    }

    [bool] IsAlive([string] $Key, [string] $Field, [long] $Timestamp) {
        if (-not $this.Database.ContainsKey($Key)) {
            return $false
        }
        $fields = $this.Database[$Key]
        if (-not $fields.ContainsKey($Field)) {
            return $false
        }
        $expiry = $fields[$Field][1]
        if ($null -eq $expiry) {
            return $true
        }
        return $Timestamp -lt [long]$expiry
    }

    [object] set([string] $Key, [string] $Field, [string] $Value) {
        return $this.SetInternal($Key, $Field, $Value, $null)
    }

    [object] get([string] $Key, [string] $Field) {
        if (-not $this.Database.ContainsKey($Key)) {
            return ''
        }
        $fields = $this.Database[$Key]
        if (-not $fields.ContainsKey($Field)) {
            return ''
        }
        return [string]$fields[$Field][0]
    }

    [object] delete([string] $Key, [string] $Field) {
        if (-not $this.Database.ContainsKey($Key)) {
            return 'false'
        }
        $fields = $this.Database[$Key]
        if (-not $fields.ContainsKey($Field)) {
            return 'false'
        }
        $fields.Remove($Field)
        return 'true'
    }

    [object] scan([string] $Key) {
        if (-not $this.Database.ContainsKey($Key)) {
            return ''
        }
        $fields = $this.Database[$Key]
        $names = @($fields.Keys | Sort-Object)
        return (($names | ForEach-Object { "$_($($fields[$_][0]))" }) -join ', ')
    }

    [object] scanByPrefix([string] $Key, [string] $Prefix) {
        if (-not $this.Database.ContainsKey($Key)) {
            return ''
        }
        $fields = $this.Database[$Key]
        $names = @($fields.Keys | Where-Object { $_.StartsWith($Prefix) } | Sort-Object)
        return (($names | ForEach-Object { "$_($($fields[$_][0]))" }) -join ', ')
    }

    [object] setAt([string] $Key, [string] $Field, [string] $Value, [long] $Timestamp) {
        return $this.SetInternal($Key, $Field, $Value, $null)
    }

    [object] setAtWithTtl([string] $Key, [string] $Field, [string] $Value, [long] $Timestamp, [long] $Ttl) {
        return $this.SetInternal($Key, $Field, $Value, ($Timestamp + $Ttl))
    }

    [object] deleteAt([string] $Key, [string] $Field, [long] $Timestamp) {
        if (-not $this.IsAlive($Key, $Field, $Timestamp)) {
            return 'false'
        }
        $this.Database[$Key].Remove($Field)
        return 'true'
    }

    [object] getAt([string] $Key, [string] $Field, [long] $Timestamp) {
        if (-not $this.IsAlive($Key, $Field, $Timestamp)) {
            return ''
        }
        return [string]$this.Database[$Key][$Field][0]
    }

    [object] scanAt([string] $Key, [long] $Timestamp) {
        if (-not $this.Database.ContainsKey($Key)) {
            return ''
        }
        $fields = $this.Database[$Key]
        $names = @($fields.Keys | Where-Object { $this.IsAlive($Key, $_, $Timestamp) } | Sort-Object)
        return (($names | ForEach-Object { "$_($($fields[$_][0]))" }) -join ', ')
    }

    [object] scanByPrefixAt([string] $Key, [string] $Prefix, [long] $Timestamp) {
        if (-not $this.Database.ContainsKey($Key)) {
            return ''
        }
        $fields = $this.Database[$Key]
        $names = @(
            $fields.Keys |
                Where-Object { $_.StartsWith($Prefix) -and $this.IsAlive($Key, $_, $Timestamp) } |
                Sort-Object
        )
        return (($names | ForEach-Object { "$_($($fields[$_][0]))" }) -join ', ')
    }

    [object] backup([long] $Timestamp) {
        $state = @{}
        foreach ($key in $this.Database.Keys) {
            $fields = $this.Database[$key]
            foreach ($field in $fields.Keys) {
                if ($this.IsAlive($key, $field, $Timestamp)) {
                    $value = [string]$fields[$field][0]
                    $expiry = $fields[$field][1]
                    $remaining = $null
                    if ($null -ne $expiry) {
                        $remaining = [long]$expiry - $Timestamp
                    }
                    if (-not $state.ContainsKey($key)) {
                        $state[$key] = @{}
                    }
                    $state[$key][$field] = @($value, $remaining)
                }
            }
        }
        $this.BackupTimestamps.Add($Timestamp)
        $this.BackupStates.Add($state)
        return [string]$state.Count
    }

    [object] restore([long] $Timestamp, [long] $TimestampToRestore) {
        $idx = -1
        for ($i = 0; $i -lt $this.BackupTimestamps.Count; $i++) {
            if ($this.BackupTimestamps[$i] -le $TimestampToRestore) {
                $idx = $i
            }
        }
        $backup = $this.BackupStates[$idx]
        $this.Database = @{}
        foreach ($key in $backup.Keys) {
            foreach ($field in $backup[$key].Keys) {
                $value = [string]$backup[$key][$field][0]
                $remaining = $backup[$key][$field][1]
                $expiry = $null
                if ($null -ne $remaining) {
                    $expiry = $Timestamp + [long]$remaining
                }
                [void] $this.SetInternal($key, $field, $value, $expiry)
            }
        }
        return ''
    }
}

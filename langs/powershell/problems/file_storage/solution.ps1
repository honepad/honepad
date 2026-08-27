class Simulation {
    [hashtable] $Files
    [hashtable] $Capacity
    [hashtable] $Backups

    Simulation() {
        $this.Files = @{}
        $this.Capacity = @{ admin = $null }
        $this.Backups = @{}
    }

    [long] Used([string] $UserId) {
        $sum = [long]0
        foreach ($item in $this.Files.Values) {
            if ([string]$item.Owner -eq $UserId) {
                $sum += [long]$item.Size
            }
        }
        return $sum
    }

    [object] Remaining([string] $UserId) {
        if (-not $this.Capacity.ContainsKey($UserId)) {
            return $null
        }
        $cap = $this.Capacity[$UserId]
        if ($null -eq $cap) {
            return $null
        }
        return ([long]$cap - $this.Used($UserId))
    }

    [object] addFile([string] $Name, [long] $Size) {
        if ($this.Files.ContainsKey($Name)) {
            return 'false'
        }
        $this.Files[$Name] = [pscustomobject]@{ Name = $Name; Size = $Size; Owner = 'admin' }
        return 'true'
    }

    [object] getFileSize([string] $Name) {
        if (-not $this.Files.ContainsKey($Name)) {
            return ''
        }
        return [string]$this.Files[$Name].Size
    }

    [object] deleteFile([string] $Name) {
        if (-not $this.Files.ContainsKey($Name)) {
            return ''
        }
        $size = [long]$this.Files[$Name].Size
        $this.Files.Remove($Name)
        return [string]$size
    }

    [object] copyFile([string] $Source, [string] $Dest) {
        if (-not $this.Files.ContainsKey($Source)) {
            return ''
        }
        $src = $this.Files[$Source]
        $srcSize = [long]$src.Size
        if ($Source -eq $Dest) {
            return [string]$srcSize
        }
        $destItem = $null
        if ($this.Files.ContainsKey($Dest)) {
            $destItem = $this.Files[$Dest]
        }
        $owner = if ($null -eq $destItem) { [string]$src.Owner } else { [string]$destItem.Owner }
        $extra = if ($null -eq $destItem) { $srcSize } else { $srcSize - [long]$destItem.Size }
        $left = $this.Remaining($owner)
        if ($null -ne $left -and $extra -gt [long]$left) {
            return ''
        }
        if ($null -eq $destItem) {
            $this.Files[$Dest] = [pscustomobject]@{ Name = $Dest; Size = $srcSize; Owner = $owner }
        } else {
            $destItem.Size = $srcSize
        }
        return [string]$srcSize
    }

    [object] getNLargest([string] $Prefix, [long] $N) {
        $matched = @(
            $this.Files.Values |
                Where-Object { $_.Name.StartsWith($Prefix) } |
                Sort-Object -Property @{ Expression = 'Size'; Descending = $true }, @{ Expression = 'Name'; Descending = $false }
        )
        $top = @($matched | Select-Object -First $N)
        return (($top | ForEach-Object { "$($_.Name)($($_.Size))" }) -join ', ')
    }

    [object] addUser([string] $UserId, [long] $Capacity) {
        if ($this.Capacity.ContainsKey($UserId)) {
            return 'false'
        }
        $this.Capacity[$UserId] = $Capacity
        return 'true'
    }

    [object] addFileBy([string] $UserId, [string] $Name, [long] $Size) {
        if (-not $this.Capacity.ContainsKey($UserId) -or $this.Files.ContainsKey($Name)) {
            return ''
        }
        $left = $this.Remaining($UserId)
        if ($null -ne $left -and $Size -gt [long]$left) {
            return ''
        }
        $this.Files[$Name] = [pscustomobject]@{ Name = $Name; Size = $Size; Owner = $UserId }
        $after = $this.Remaining($UserId)
        if ($null -eq $after) {
            return ''
        }
        return [string]$after
    }

    [object] mergeUser([string] $UserId1, [string] $UserId2) {
        if ($UserId1 -eq $UserId2) {
            return ''
        }
        if (-not $this.Capacity.ContainsKey($UserId1) -or -not $this.Capacity.ContainsKey($UserId2)) {
            return ''
        }
        $cap1 = $this.Capacity[$UserId1]
        $cap2 = $this.Capacity[$UserId2]
        if ($null -eq $cap1 -or $null -eq $cap2) {
            return ''
        }
        $this.Capacity[$UserId1] = [long]$cap1 + [long]$cap2
        foreach ($item in $this.Files.Values) {
            if ([string]$item.Owner -eq $UserId2) {
                $item.Owner = $UserId1
            }
        }
        $this.Capacity.Remove($UserId2)
        if ($this.Backups.ContainsKey($UserId2)) {
            $this.Backups.Remove($UserId2)
        }
        $left = $this.Remaining($UserId1)
        if ($null -eq $left) {
            return ''
        }
        return [string]$left
    }

    [object] backupUser([string] $UserId) {
        if (-not $this.Capacity.ContainsKey($UserId)) {
            return ''
        }
        $snap = @{}
        foreach ($item in $this.Files.Values) {
            if ([string]$item.Owner -eq $UserId) {
                $snap[[string]$item.Name] = [long]$item.Size
            }
        }
        $this.Backups[$UserId] = $snap
        return [string]$snap.Count
    }

    [object] restoreUser([string] $UserId) {
        if (-not $this.Capacity.ContainsKey($UserId)) {
            return ''
        }
        foreach ($name in @($this.Files.Keys)) {
            if ([string]$this.Files[$name].Owner -eq $UserId) {
                $this.Files.Remove($name)
            }
        }
        if (-not $this.Backups.ContainsKey($UserId)) {
            return '0'
        }
        $snap = $this.Backups[$UserId]
        $restored = 0
        foreach ($name in $snap.Keys) {
            if ($this.Files.ContainsKey($name)) {
                continue
            }
            $size = [long]$snap[$name]
            $left = $this.Remaining($UserId)
            if ($null -ne $left -and $size -gt [long]$left) {
                continue
            }
            $this.Files[$name] = [pscustomobject]@{ Name = $name; Size = $size; Owner = $UserId }
            $restored += 1
        }
        return [string]$restored
    }
}

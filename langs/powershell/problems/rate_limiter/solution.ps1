class KeyState {
    [long] $Limit
    [long] $Window
    [nullable[long]] $WindowId
    [long] $Used

    KeyState() {
        $this.Limit = 3
        $this.Window = 10
        $this.WindowId = $null
        $this.Used = 0
    }
}

class Simulation {
    [hashtable] $Keys

    Simulation() {
        $this.Keys = @{}
    }

    hidden [KeyState] State([string] $Key) {
        if (-not $this.Keys.ContainsKey($Key)) {
            $this.Keys[$Key] = [KeyState]::new()
        }
        return $this.Keys[$Key]
    }

    hidden [long] UsedAt([KeyState] $Item, [long] $Timestamp, [bool] $Persist) {
        $windowId = [long][math]::Floor($Timestamp / $Item.Window)
        if ($null -eq $Item.WindowId -or $windowId -ne $Item.WindowId) {
            if ($Persist) {
                $Item.WindowId = $windowId
                $Item.Used = 0
            }
            return 0
        }
        return $Item.Used
    }

    [object] allow([string] $Key, [long] $Timestamp) {
        return $this.allowWeighted($Key, 1, $Timestamp)
    }

    [object] configure([string] $Key, [long] $Limit, [long] $Window) {
        if ($Limit -le 0 -or $Window -le 0) {
            return 'invalid_request'
        }
        $item = $this.State($Key)
        $item.Limit = $Limit
        $item.Window = $Window
        $item.WindowId = $null
        $item.Used = 0
        return 'true'
    }

    [object] remaining([string] $Key, [long] $Timestamp) {
        $item = $this.State($Key)
        $used = $this.UsedAt($item, $Timestamp, $false)
        return [string]($item.Limit - $used)
    }

    [object] allowWeighted([string] $Key, [long] $Cost, [long] $Timestamp) {
        if ($Cost -le 0) {
            return 'invalid_request'
        }
        $item = $this.State($Key)
        $this.UsedAt($item, $Timestamp, $true)
        if ($item.Used + $Cost -gt $item.Limit) {
            return 'false'
        }
        $item.Used += $Cost
        return 'true'
    }
}

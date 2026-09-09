class Item {
    [string] $Sku
    [string] $Name
    [long] $Qty
    [long] $Reserved

    Item([string] $Sku, [string] $Name) {
        $this.Sku = $Sku
        $this.Name = $Name
        $this.Qty = 0
        $this.Reserved = 0
    }
}

class Simulation {
    [hashtable] $Items

    Simulation() {
        $this.Items = @{}
    }

    [object] createItem([string] $Sku, [string] $Name) {
        if ($this.Items.ContainsKey($Sku)) {
            return 'false'
        }
        $this.Items[$Sku] = [Item]::new($Sku, $Name)
        return 'true'
    }

    [object] stock([string] $Sku, [long] $Delta) {
        if (-not $this.Items.ContainsKey($Sku)) {
            return ''
        }
        $item = $this.Items[$Sku]
        $nxt = $item.Qty + $Delta
        if ($nxt -lt $item.Reserved) {
            return 'invalid_request'
        }
        $item.Qty = $nxt
        return [string]$item.Qty
    }

    [object] getQty([string] $Sku) {
        if (-not $this.Items.ContainsKey($Sku)) {
            return ''
        }
        return [string]$this.Items[$Sku].Qty
    }

    [object] listLow([long] $Threshold) {
        $matched = @(
            $this.Items.Values |
                Where-Object { $_.Qty -le $Threshold } |
                Sort-Object -Property @{ Expression = 'Qty' }, @{ Expression = 'Sku' }
        )
        return (($matched | ForEach-Object { "$($_.Sku)($($_.Qty))" }) -join ', ')
    }

    [object] reserve([string] $Sku, [long] $N) {
        if (-not $this.Items.ContainsKey($Sku)) {
            return 'invalid_request'
        }
        $item = $this.Items[$Sku]
        if ($N -le 0 -or $item.Reserved + $N -gt $item.Qty) {
            return 'invalid_request'
        }
        $item.Reserved += $N
        return 'true'
    }

    [object] release([string] $Sku, [long] $N) {
        if (-not $this.Items.ContainsKey($Sku)) {
            return 'invalid_request'
        }
        $item = $this.Items[$Sku]
        if ($N -le 0 -or $N -gt $item.Reserved) {
            return 'invalid_request'
        }
        $item.Reserved -= $N
        return 'true'
    }

    [object] ship([string] $Sku, [long] $N) {
        if (-not $this.Items.ContainsKey($Sku)) {
            return 'invalid_request'
        }
        $item = $this.Items[$Sku]
        if ($N -le 0 -or $N -gt $item.Reserved) {
            return 'invalid_request'
        }
        $item.Reserved -= $N
        $item.Qty -= $N
        return 'true'
    }
}

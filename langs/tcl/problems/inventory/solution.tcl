oo::class create Simulation {
    variable items
    constructor {} {
        set items [dict create]
    }

    method create_item {sku name} {
        if {[dict exists $items $sku]} {
            return [json::str false]
        }
        dict set items $sku [dict create sku $sku name $name qty 0 reserved 0]
        return [json::str true]
    }

    method stock {sku delta} {
        if {![dict exists $items $sku]} {
            return [json::str ""]
        }
        set item [dict get $items $sku]
        set nxt [expr {[dict get $item qty] + $delta}]
        if {$nxt < [dict get $item reserved]} {
            return [json::str invalid_request]
        }
        dict set item qty $nxt
        dict set items $sku $item
        return [json::str $nxt]
    }

    method get_qty {sku} {
        if {![dict exists $items $sku]} {
            return [json::str ""]
        }
        return [json::str [dict get $items $sku qty]]
    }

    method list_low {threshold} {
        set pairs {}
        dict for {_ item} $items {
            set qty [dict get $item qty]
            if {$qty <= $threshold} {
                lappend pairs [list $qty [dict get $item sku]]
            }
        }
        set pairs [lsort -index 1 $pairs]
        set pairs [lsort -integer -index 0 $pairs]
        set parts {}
        foreach row $pairs {
            lassign $row qty sku
            lappend parts [format {%s(%d)} $sku $qty]
        }
        return [json::str [join $parts ", "]]
    }

    method reserve {sku n} {
        if {![dict exists $items $sku]} {
            return [json::str invalid_request]
        }
        set item [dict get $items $sku]
        if {$n <= 0 || [dict get $item reserved] + $n > [dict get $item qty]} {
            return [json::str invalid_request]
        }
        dict set item reserved [expr {[dict get $item reserved] + $n}]
        dict set items $sku $item
        return [json::str true]
    }

    method release {sku n} {
        if {![dict exists $items $sku]} {
            return [json::str invalid_request]
        }
        set item [dict get $items $sku]
        if {$n <= 0 || $n > [dict get $item reserved]} {
            return [json::str invalid_request]
        }
        dict set item reserved [expr {[dict get $item reserved] - $n}]
        dict set items $sku $item
        return [json::str true]
    }

    method ship {sku n} {
        if {![dict exists $items $sku]} {
            return [json::str invalid_request]
        }
        set item [dict get $items $sku]
        if {$n <= 0 || $n > [dict get $item reserved]} {
            return [json::str invalid_request]
        }
        dict set item reserved [expr {[dict get $item reserved] - $n}]
        dict set item qty [expr {[dict get $item qty] - $n}]
        dict set items $sku $item
        return [json::str true]
    }
}

oo::class create Simulation {
    variable keys
    constructor {} {
        set keys [dict create]
    }

    method _state {key} {
        if {![dict exists $keys $key]} {
            dict set keys $key [dict create limit 3 window 10 window_id "" used 0]
        }
        return [dict get $keys $key]
    }

    method _used_at {key timestamp persist} {
        set item [my _state $key]
        set window [dict get $item window]
        set window_id [expr {$timestamp / $window}]
        set cur [dict get $item window_id]
        if {$cur eq "" || $cur != $window_id} {
            if {$persist} {
                dict set item window_id $window_id
                dict set item used 0
                dict set keys $key $item
            }
            return 0
        }
        return [dict get $item used]
    }

    method allow {key timestamp} {
        return [my allow_weighted $key 1 $timestamp]
    }

    method configure {key limit window} {
        if {$limit <= 0 || $window <= 0} {
            return [json::str invalid_request]
        }
        dict set keys $key [dict create limit $limit window $window window_id "" used 0]
        return [json::str true]
    }

    method remaining {key timestamp} {
        set item [my _state $key]
        set used [my _used_at $key $timestamp 0]
        return [json::str [expr {[dict get $item limit] - $used}]]
    }

    method allow_weighted {key cost timestamp} {
        if {$cost <= 0} {
            return [json::str invalid_request]
        }
        my _used_at $key $timestamp 1
        set item [dict get $keys $key]
        if {[dict get $item used] + $cost > [dict get $item limit]} {
            return [json::str false]
        }
        dict set item used [expr {[dict get $item used] + $cost}]
        dict set keys $key $item
        return [json::str true]
    }
}

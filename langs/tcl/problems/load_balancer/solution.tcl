oo::class create Simulation {
    variable backends by_id cursor sticky_map use_least
    constructor {} {
        set backends {}
        set by_id [dict create]
        set cursor 0
        set sticky_map [dict create]
        set use_least 0
    }

    method add_backend {backend_id} {
        if {[dict exists $by_id $backend_id]} {
            return [json::str false]
        }
        set item [dict create backend_id $backend_id health 1 weight 1 inflight 0]
        lappend backends $item
        dict set by_id $backend_id [expr {[llength $backends] - 1}]
        return [json::str true]
    }

    method _get {idx} {
        return [lindex $backends $idx]
    }

    method _put {idx item} {
        set backends [lreplace $backends $idx $idx $item]
    }

    method set_health {backend_id flag} {
        if {![dict exists $by_id $backend_id] || ($flag != 0 && $flag != 1)} {
            return [json::str invalid_request]
        }
        set idx [dict get $by_id $backend_id]
        set item [my _get $idx]
        dict set item health $flag
        my _put $idx $item
        my _reset_cycle
        return [json::str true]
    }

    method set_weight {backend_id weight} {
        if {![dict exists $by_id $backend_id] || $weight <= 0} {
            return [json::str invalid_request]
        }
        set idx [dict get $by_id $backend_id]
        set item [my _get $idx]
        dict set item weight $weight
        my _put $idx $item
        my _reset_cycle
        return [json::str true]
    }

    method _reset_cycle {} {
        set cursor 0
        set use_least 0
        set next {}
        foreach item $backends {
            dict set item inflight 0
            lappend next $item
        }
        set backends $next
    }

    method _pick {} {
        set healthy {}
        foreach item $backends {
            if {[dict get $item health]} {
                lappend healthy $item
            }
        }
        if {[llength $healthy] == 0} {
            return ""
        }
        set pool $healthy
        if {$use_least} {
            set least [dict get [lindex $healthy 0] inflight]
            foreach item $healthy {
                set inf [dict get $item inflight]
                if {$inf < $least} {
                    set least $inf
                }
            }
            set pool {}
            foreach item $healthy {
                if {[dict get $item inflight] == $least} {
                    lappend pool $item
                }
            }
        }
        set tickets {}
        foreach item $pool {
            set w [dict get $item weight]
            for {set i 0} {$i < $w} {incr i} {
                lappend tickets $item
            }
        }
        if {[llength $tickets] == 0} {
            return ""
        }
        set chosen [lindex $tickets [expr {$cursor % [llength $tickets]}]]
        incr cursor
        return $chosen
    }

    method _take {} {
        set item [my _pick]
        if {$item eq ""} {
            return ""
        }
        set bid [dict get $item backend_id]
        set idx [dict get $by_id $bid]
        set stored [my _get $idx]
        dict set stored inflight [expr {[dict get $stored inflight] + 1}]
        my _put $idx $stored
        return $bid
    }

    method route {} {
        return [json::str [my _take]]
    }

    method sticky {client_id} {
        if {[dict exists $sticky_map $client_id]} {
            set bound [dict get $sticky_map $client_id]
            if {[dict exists $by_id $bound]} {
                set idx [dict get $by_id $bound]
                set item [my _get $idx]
                if {[dict get $item health]} {
                    dict set item inflight [expr {[dict get $item inflight] + 1}]
                    my _put $idx $item
                    return [json::str $bound]
                }
            }
        }
        set chosen [my _take]
        if {$chosen ne ""} {
            dict set sticky_map $client_id $chosen
        }
        return [json::str $chosen]
    }

    method done {backend_id} {
        if {![dict exists $by_id $backend_id]} {
            return [json::str invalid_request]
        }
        set idx [dict get $by_id $backend_id]
        set item [my _get $idx]
        if {[dict get $item inflight] <= 0} {
            return [json::str invalid_request]
        }
        dict set item inflight [expr {[dict get $item inflight] - 1}]
        my _put $idx $item
        set use_least 1
        return [json::str true]
    }
}

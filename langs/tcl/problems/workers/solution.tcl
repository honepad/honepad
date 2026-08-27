oo::class create Simulation {
    variable workers
    constructor {} {
        set workers [dict create]
    }

    method add_worker {worker_id position compensation} {
        if {[dict exists $workers $worker_id]} {
            return [json::str false]
        }
        dict set workers $worker_id [dict create \
            worker_id $worker_id \
            position $position \
            compensation $compensation \
            in_office 0 \
            entered_at "" \
            finished {} \
            pending_promo ""]
        return [json::str true]
    }

    method apply_promo_on_enter {worker_id timestamp} {
        set worker [dict get $workers $worker_id]
        set promo [dict get $worker pending_promo]
        if {$promo eq ""} {
            return
        }
        lassign $promo new_pos new_comp start_ts
        if {$timestamp < $start_ts} {
            return
        }
        dict set worker position $new_pos
        dict set worker compensation $new_comp
        dict set worker pending_promo ""
        dict set workers $worker_id $worker
    }

    method total_time {worker} {
        set total 0
        foreach row [dict get $worker finished] {
            incr total [expr {[lindex $row 1] - [lindex $row 0]}]
        }
        return $total
    }

    method position_time {worker position} {
        set total 0
        foreach row [dict get $worker finished] {
            if {[lindex $row 3] eq $position} {
                incr total [expr {[lindex $row 1] - [lindex $row 0]}]
            }
        }
        return $total
    }

    method register {worker_id timestamp} {
        if {![dict exists $workers $worker_id]} {
            return [json::str invalid_request]
        }
        set worker [dict get $workers $worker_id]
        if {[dict get $worker in_office]} {
            dict lappend worker finished [list \
                [dict get $worker entered_at] \
                $timestamp \
                [dict get $worker compensation] \
                [dict get $worker position]]
            dict set worker in_office 0
            dict set worker entered_at ""
            dict set workers $worker_id $worker
            return [json::str registered]
        }
        my apply_promo_on_enter $worker_id $timestamp
        set worker [dict get $workers $worker_id]
        dict set worker in_office 1
        dict set worker entered_at $timestamp
        dict set workers $worker_id $worker
        return [json::str registered]
    }

    method get {worker_id} {
        if {![dict exists $workers $worker_id]} {
            return [json::str ""]
        }
        return [json::str [my total_time [dict get $workers $worker_id]]]
    }

    method top_n_workers {n position} {
        set pairs {}
        dict for {_ worker} $workers {
            if {[dict get $worker position] eq $position} {
                lappend pairs [list \
                    [my position_time $worker $position] \
                    [dict get $worker worker_id]]
            }
        }
        set pairs [lsort -index 1 $pairs]
        set pairs [lsort -integer -decreasing -index 0 $pairs]
        if {[llength $pairs] > $n} {
            set pairs [lrange $pairs 0 [expr {$n - 1}]]
        }
        set parts {}
        foreach row $pairs {
            lassign $row t worker_id
            lappend parts [format {%s(%d)} $worker_id $t]
        }
        return [json::str [join $parts ", "]]
    }

    method promote {worker_id new_position new_compensation start_timestamp} {
        if {![dict exists $workers $worker_id]} {
            return [json::str invalid_request]
        }
        set worker [dict get $workers $worker_id]
        if {[dict get $worker pending_promo] ne ""} {
            return [json::str invalid_request]
        }
        dict set worker pending_promo [list $new_position $new_compensation $start_timestamp]
        dict set workers $worker_id $worker
        return [json::str success]
    }

    method calc_salary {worker_id start_timestamp end_timestamp} {
        if {![dict exists $workers $worker_id]} {
            return [json::str ""]
        }
        set total 0
        foreach row [dict get [dict get $workers $worker_id] finished] {
            lassign $row session_start session_end rate
            set lo $session_start
            if {$start_timestamp > $lo} {
                set lo $start_timestamp
            }
            set hi $session_end
            if {$end_timestamp < $hi} {
                set hi $end_timestamp
            }
            if {$hi > $lo} {
                incr total [expr {($hi - $lo) * $rate}]
            }
        }
        return [json::str $total]
    }
}

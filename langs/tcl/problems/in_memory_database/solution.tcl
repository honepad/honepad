oo::class create InMemoryDatabase {
    variable database backup_timestamps backup_states
    constructor {} {
        set database [dict create]
        set backup_timestamps [list]
        set backup_states [list]
    }

    method set_internal {key field value expiry} {
        dict set database $key $field [list $value $expiry]
        return [json::str ""]
    }

    method alive {key field timestamp} {
        if {![dict exists $database $key $field]} {
            return 0
        }
        set expiry [lindex [dict get $database $key $field] 1]
        if {$expiry eq ""} {
            return 1
        }
        return [expr {$timestamp < $expiry}]
    }

    method set {key field value} {
        return [my set_internal $key $field $value ""]
    }

    method get {key field} {
        if {![dict exists $database $key $field]} {
            return [json::str ""]
        }
        return [json::str [lindex [dict get $database $key $field] 0]]
    }

    method delete {key field} {
        if {![dict exists $database $key $field]} {
            return [json::str false]
        }
        dict unset database $key $field
        return [json::str true]
    }

    method _sorted_fields {key} {
        if {![dict exists $database $key]} {
            return {}
        }
        return [lsort [dict keys [dict get $database $key]]]
    }

    method scan {key} {
        if {![dict exists $database $key]} {
            return [json::str ""]
        }
        set parts {}
        foreach field [my _sorted_fields $key] {
            set value [lindex [dict get $database $key $field] 0]
            lappend parts [format {%s(%s)} $field $value]
        }
        return [json::str [join $parts ", "]]
    }

    method scan_by_prefix {key prefix} {
        if {![dict exists $database $key]} {
            return [json::str ""]
        }
        set parts {}
        foreach field [my _sorted_fields $key] {
            if {[string first $prefix $field] == 0} {
                set value [lindex [dict get $database $key $field] 0]
                lappend parts [format {%s(%s)} $field $value]
            }
        }
        return [json::str [join $parts ", "]]
    }

    method set_at {key field value timestamp} {
        return [my set_internal $key $field $value ""]
    }

    method set_at_with_ttl {key field value timestamp ttl} {
        return [my set_internal $key $field $value [expr {$timestamp + $ttl}]]
    }

    method delete_at {key field timestamp} {
        if {![my alive $key $field $timestamp]} {
            return [json::str false]
        }
        dict unset database $key $field
        return [json::str true]
    }

    method get_at {key field timestamp} {
        if {![my alive $key $field $timestamp]} {
            return [json::str ""]
        }
        return [json::str [lindex [dict get $database $key $field] 0]]
    }

    method scan_at {key timestamp} {
        if {![dict exists $database $key]} {
            return [json::str ""]
        }
        set parts {}
        foreach field [my _sorted_fields $key] {
            if {[my alive $key $field $timestamp]} {
                set value [lindex [dict get $database $key $field] 0]
                lappend parts [format {%s(%s)} $field $value]
            }
        }
        return [json::str [join $parts ", "]]
    }

    method scan_by_prefix_at {key prefix timestamp} {
        if {![dict exists $database $key]} {
            return [json::str ""]
        }
        set parts {}
        foreach field [my _sorted_fields $key] {
            if {[string first $prefix $field] == 0 && [my alive $key $field $timestamp]} {
                set value [lindex [dict get $database $key $field] 0]
                lappend parts [format {%s(%s)} $field $value]
            }
        }
        return [json::str [join $parts ", "]]
    }

    method backup {timestamp} {
        set state [dict create]
        set count 0
        dict for {key fields} $database {
            dict for {field row} $fields {
                if {![my alive $key $field $timestamp]} {
                    continue
                }
                if {![dict exists $state $key]} {
                    dict set state $key [dict create]
                    incr count
                }
                set expiry [lindex $row 1]
                set remaining ""
                if {$expiry ne ""} {
                    set remaining [expr {$expiry - $timestamp}]
                }
                dict set state $key $field [list [lindex $row 0] $remaining]
            }
        }
        lappend backup_timestamps $timestamp
        lappend backup_states $state
        return [json::str $count]
    }

    method restore {timestamp timestamp_to_restore} {
        set idx -1
        set i 0
        foreach ts $backup_timestamps {
            if {$ts <= $timestamp_to_restore} {
                set idx $i
            }
            incr i
        }
        set backup_state [lindex $backup_states $idx]
        set database [dict create]
        dict for {key fields} $backup_state {
            dict for {field row} $fields {
                lassign $row value remaining
                set expiry ""
                if {$remaining ne ""} {
                    set expiry [expr {$timestamp + $remaining}]
                }
                my set_internal $key $field $value $expiry
            }
        }
        return [json::str ""]
    }
}

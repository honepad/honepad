oo::class create Simulation {
    variable files order capacity backups
    constructor {} {
        set files [dict create]
        set order [list]
        set capacity [dict create admin ""]
        set backups [dict create]
    }

    method used {user_id} {
        set total 0
        foreach name $order {
            set item [dict get $files $name]
            if {[dict get $item owner] eq $user_id} {
                incr total [dict get $item size]
            }
        }
        return $total
    }

    method remaining {user_id} {
        if {![dict exists $capacity $user_id]} {
            return ""
        }
        set cap [dict get $capacity $user_id]
        if {$cap eq ""} {
            return ""
        }
        return [expr {$cap - [my used $user_id]}]
    }

    method _add {name size owner} {
        dict set files $name [dict create name $name size $size owner $owner]
        lappend order $name
    }

    method _delete_name {name} {
        dict unset files $name
        set next {}
        foreach existing $order {
            if {$existing ne $name} {
                lappend next $existing
            }
        }
        set order $next
    }

    method add_file {name size} {
        if {[dict exists $files $name]} {
            return [json::str false]
        }
        my _add $name $size admin
        return [json::str true]
    }

    method get_file_size {name} {
        if {![dict exists $files $name]} {
            return [json::str ""]
        }
        return [json::str [dict get $files $name size]]
    }

    method delete_file {name} {
        if {![dict exists $files $name]} {
            return [json::str ""]
        }
        set size [dict get $files $name size]
        my _delete_name $name
        return [json::str $size]
    }

    method get_n_largest {prefix n} {
        set pairs {}
        foreach name $order {
            set item [dict get $files $name]
            if {[string first $prefix [dict get $item name]] == 0} {
                lappend pairs [list [dict get $item size] [dict get $item name]]
            }
        }
        set pairs [lsort -index 1 $pairs]
        set pairs [lsort -integer -decreasing -index 0 $pairs]
        if {[llength $pairs] > $n} {
            set pairs [lrange $pairs 0 [expr {$n - 1}]]
        }
        set parts {}
        foreach row $pairs {
            lassign $row size name
            lappend parts [format {%s(%d)} $name $size]
        }
        return [json::str [join $parts ", "]]
    }

    method add_user {user_id capacity_value} {
        if {[dict exists $capacity $user_id]} {
            return [json::str false]
        }
        dict set capacity $user_id $capacity_value
        return [json::str true]
    }

    method add_file_by {user_id name size} {
        if {![dict exists $capacity $user_id] || [dict exists $files $name]} {
            return [json::str ""]
        }
        set left [my remaining $user_id]
        if {$left ne "" && $size > $left} {
            return [json::str ""]
        }
        my _add $name $size $user_id
        set left [my remaining $user_id]
        if {$left eq ""} {
            return [json::str ""]
        }
        return [json::str $left]
    }

    method merge_user {user_id1 user_id2} {
        if {$user_id1 eq $user_id2} {
            return [json::str ""]
        }
        if {![dict exists $capacity $user_id1] || ![dict exists $capacity $user_id2]} {
            return [json::str ""]
        }
        set cap1 [dict get $capacity $user_id1]
        set cap2 [dict get $capacity $user_id2]
        if {$cap1 eq "" || $cap2 eq ""} {
            return [json::str ""]
        }
        dict set capacity $user_id1 [expr {$cap1 + $cap2}]
        foreach name $order {
            set item [dict get $files $name]
            if {[dict get $item owner] eq $user_id2} {
                dict set item owner $user_id1
                dict set files $name $item
            }
        }
        dict unset capacity $user_id2
        dict unset backups $user_id2
        set left [my remaining $user_id1]
        if {$left eq ""} {
            return [json::str ""]
        }
        return [json::str $left]
    }

    method backup_user {user_id} {
        if {![dict exists $capacity $user_id]} {
            return [json::str ""]
        }
        set snap {}
        foreach name $order {
            set item [dict get $files $name]
            if {[dict get $item owner] eq $user_id} {
                lappend snap [list $name [dict get $item size]]
            }
        }
        dict set backups $user_id $snap
        return [json::str [llength $snap]]
    }

    method restore_user {user_id} {
        if {![dict exists $capacity $user_id]} {
            return [json::str ""]
        }
        set keep {}
        foreach name $order {
            set item [dict get $files $name]
            if {[dict get $item owner] eq $user_id} {
                dict unset files $name
            } else {
                lappend keep $name
            }
        }
        set order $keep
        if {![dict exists $backups $user_id]} {
            return [json::str 0]
        }
        set snapshot [dict get $backups $user_id]
        set restored 0
        foreach row $snapshot {
            lassign $row name size
            if {[dict exists $files $name]} {
                continue
            }
            set left [my remaining $user_id]
            if {$left ne "" && $size > $left} {
                continue
            }
            my _add $name $size $user_id
            incr restored
        }
        return [json::str $restored]
    }
}

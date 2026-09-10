oo::class create Simulation {
    variable subs inbox retained
    constructor {} {
        set subs [dict create]
        set inbox [dict create]
        set retained [dict create]
    }

    method subscribe {topic client} {
        if {![dict exists $subs $topic]} {
            dict set subs $topic [list]
        }
        set clients [dict get $subs $topic]
        if {$client in $clients} {
            return [json::str false]
        }
        lappend clients $client
        dict set subs $topic $clients
        if {[dict exists $retained $topic]} {
            set items {}
            if {[dict exists $inbox $client]} {
                set items [dict get $inbox $client]
            }
            lappend items "$topic:[dict get $retained $topic]"
            dict set inbox $client $items
        }
        return [json::str true]
    }

    method unsubscribe {topic client} {
        if {![dict exists $subs $topic]} {
            return [json::str false]
        }
        set clients [dict get $subs $topic]
        set idx [lsearch -exact $clients $client]
        if {$idx < 0} {
            return [json::str false]
        }
        set clients [lreplace $clients $idx $idx]
        if {[llength $clients] == 0} {
            dict unset subs $topic
        } else {
            dict set subs $topic $clients
        }
        return [json::str true]
    }

    method publish {topic message} {
        set clients {}
        if {[dict exists $subs $topic]} {
            set clients [dict get $subs $topic]
        }
        set payload "$topic:$message"
        foreach client $clients {
            set items {}
            if {[dict exists $inbox $client]} {
                set items [dict get $inbox $client]
            }
            lappend items $payload
            dict set inbox $client $items
        }
        return [json::str [llength $clients]]
    }

    method inbox {client} {
        if {![dict exists $inbox $client]} {
            return [json::str ""]
        }
        return [json::str [join [dict get $inbox $client] ", "]]
    }

    method list_topics {} {
        return [json::str [join [lsort [dict keys $subs]] ", "]]
    }

    method subscribers {topic} {
        if {![dict exists $subs $topic]} {
            return [json::str ""]
        }
        return [json::str [join [lsort [dict get $subs $topic]] ", "]]
    }

    method peek {client} {
        if {![dict exists $inbox $client]} {
            return [json::str ""]
        }
        set items [dict get $inbox $client]
        if {[llength $items] == 0} {
            return [json::str ""]
        }
        return [json::str [lindex $items 0]]
    }

    method ack {client n} {
        if {$n <= 0 || ![dict exists $inbox $client]} {
            return [json::str invalid_request]
        }
        set items [dict get $inbox $client]
        if {$n > [llength $items]} {
            return [json::str invalid_request]
        }
        set items [lrange $items $n end]
        dict set inbox $client $items
        return [json::str [llength $items]]
    }

    method retain {topic message} {
        dict set retained $topic $message
        return [json::str ""]
    }
}

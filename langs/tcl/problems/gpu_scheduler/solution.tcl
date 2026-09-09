oo::class create Simulation {
    variable gpus gpu_order jobs next_seq
    constructor {} {
        set gpus [dict create]
        set gpu_order {}
        set jobs [dict create]
        set next_seq 0
    }

    method add_gpu {gpu_id mem} {
        if {$mem <= 0} {
            return [json::str invalid_request]
        }
        if {[dict exists $gpus $gpu_id]} {
            return [json::str false]
        }
        dict set gpus $gpu_id [dict create gpu_id $gpu_id mem $mem job_id ""]
        lappend gpu_order $gpu_id
        return [json::str true]
    }

    method submit_job {job_id mem} {
        if {$mem <= 0} {
            return [json::str invalid_request]
        }
        if {[dict exists $jobs $job_id]} {
            return [json::str false]
        }
        dict set jobs $job_id [dict create job_id $job_id mem $mem seq $next_seq priority 0 state queued gpu_id ""]
        incr next_seq
        return [json::str true]
    }

    method status {job_id} {
        if {![dict exists $jobs $job_id]} {
            return [json::str ""]
        }
        return [json::str [dict get $jobs $job_id state]]
    }

    method assign {} {
        set queued {}
        dict for {jid job} $jobs {
            if {[dict get $job state] eq "queued"} {
                lappend queued $job
            }
        }
        set queued [lsort -command [list apply {{a b} {
            set pa [dict get $a priority]
            set pb [dict get $b priority]
            if {$pa != $pb} {
                return [expr {$pb - $pa}]
            }
            return [expr {[dict get $a seq] - [dict get $b seq]}]
        }}] $queued]
        foreach job $queued {
            foreach gpu_id $gpu_order {
                set gpu [dict get $gpus $gpu_id]
                if {[dict get $gpu job_id] eq "" && [dict get $gpu mem] >= [dict get $job mem]} {
                    set jid [dict get $job job_id]
                    dict set job state running
                    dict set job gpu_id $gpu_id
                    dict set gpu job_id $jid
                    dict set jobs $jid $job
                    dict set gpus $gpu_id $gpu
                    return [json::str $jid]
                }
            }
        }
        return [json::str ""]
    }

    method complete {job_id} {
        if {![dict exists $jobs $job_id]} {
            return [json::str invalid_request]
        }
        set job [dict get $jobs $job_id]
        set gpu_id [dict get $job gpu_id]
        if {[dict get $job state] ne "running" || $gpu_id eq ""} {
            return [json::str invalid_request]
        }
        dict set gpus $gpu_id job_id ""
        dict set job gpu_id ""
        dict set job state done
        dict set jobs $job_id $job
        return [json::str true]
    }

    method cancel {job_id} {
        if {![dict exists $jobs $job_id]} {
            return [json::str invalid_request]
        }
        set job [dict get $jobs $job_id]
        if {[dict get $job state] eq "done"} {
            return [json::str invalid_request]
        }
        set was_running [expr {[dict get $job state] eq "running"}]
        if {$was_running && [dict get $job gpu_id] ne ""} {
            dict set gpus [dict get $job gpu_id] job_id ""
        }
        dict unset jobs $job_id
        if {$was_running} {
            my assign
        }
        return [json::str true]
    }

    method set_priority {job_id priority} {
        if {![dict exists $jobs $job_id]} {
            return [json::str invalid_request]
        }
        set job [dict get $jobs $job_id]
        if {[dict get $job state] ne "queued"} {
            return [json::str invalid_request]
        }
        dict set job priority $priority
        dict set jobs $job_id $job
        return [json::str true]
    }
}

#!/usr/bin/env tclsh
# argv: tclsh adapter.tcl <src> <class> <cases.json>

set adapterDir [file dirname [file normalize [info script]]]
source [file join $adapterDir json.tcl]

proc honepad_read {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set raw [read $fh]
    close $fh
    return $raw
}

proc honepad_fail {case_id index method expected actual} {
    return [json::obj \
        case [json::str $case_id] \
        index [json::num $index] \
        method [json::str $method] \
        expected $expected \
        actual $actual]
}

proc main {} {
    global argv
    lassign $argv file className casesPath
    set reportChan [open /dev/stdout w]
    close stdout
    open /dev/null w
    source $file
    if {[info commands $className] eq ""} {
        error "missing class $className"
    }
    set cases [json::decode [honepad_read $casesPath]]
    set failed {}
    set passed 0
    set caseValues [lindex $cases 1]
    foreach caseVal $caseValues {
        set caseObj [lindex $caseVal 1]
        set caseId ""
        set calls {}
        foreach {k v} $caseObj {
            if {$k eq "id"} {
                set caseId [json::native $v]
            } elseif {$k eq "calls"} {
                set calls [lindex $v 1]
            }
        }
        set obj [$className new]
        set ok 1
        set i 0
        foreach callVal $calls {
            set callObj [lindex $callVal 1]
            set method ""
            set args {}
            set expected $::json::null
            foreach {k v} $callObj {
                if {$k eq "m"} {
                    set method [json::native $v]
                } elseif {$k eq "a"} {
                    set args [json::native $v]
                } elseif {$k eq "e"} {
                    set expected $v
                }
            }
            set actual ""
            if {[catch {set actual [$obj $method {*}$args]} err]} {
                set err [string trim $err]
                lappend failed [honepad_fail $caseId $i $method $expected \
                    [json::str "exc:$err"]]
                set ok 0
                break
            }
            if {[json::encode $actual] ne [json::encode $expected]} {
                lappend failed [honepad_fail $caseId $i $method $expected $actual]
                set ok 0
                break
            }
            incr i
        }
        if {$ok} {
            incr passed
        }
    }
    set parts {}
    foreach row $failed {
        lappend parts [json::encode $row]
    }
    puts $reportChan [format {{"passed":%d,"failed":[%s]}} $passed [join $parts ,]]
    if {[llength $failed] > 0} {
        exit 1
    }
    exit 0
}

main

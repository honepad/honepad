oo::class create Simulation {
    variable buf pos undoStack redoStack selStart selEnd clip
    constructor {} {
        set buf ""
        set pos 0
        set undoStack [list]
        set redoStack [list]
        set selStart -1
        set selEnd -1
        set clip ""
    }

    method _push {} {
        lappend undoStack [list $buf $pos]
        set redoStack [list]
        set selStart -1
        set selEnd -1
    }

    method insert {at text} {
        if {$at < 0 || $at > [string length $buf]} {
            return [json::str invalid_request]
        }
        my _push
        set buf [string range $buf 0 [expr {$at - 1}]]$text[string range $buf $at end]
        return [json::str [string length $buf]]
    }

    method erase {at n} {
        if {$n <= 0 || $at < 0 || $at + $n > [string length $buf]} {
            return [json::str invalid_request]
        }
        my _push
        set last [expr {$at + $n - 1}]
        set deleted [string range $buf $at $last]
        set buf [string range $buf 0 [expr {$at - 1}]][string range $buf [expr {$at + $n}] end]
        if {$pos > [string length $buf]} {
            set pos [string length $buf]
        }
        return [json::str $deleted]
    }

    method get_text {} {
        return [json::str $buf]
    }

    method length {} {
        return [json::str [string length $buf]]
    }

    method move {at} {
        if {$at < 0 || $at > [string length $buf]} {
            return [json::str invalid_request]
        }
        set pos $at
        return [json::str true]
    }

    method type_text {text} {
        my _push
        set at $pos
        set buf [string range $buf 0 [expr {$at - 1}]]$text[string range $buf $at end]
        set pos [expr {$at + [string length $text]}]
        return [json::str [string length $buf]]
    }

    method cursor {} {
        return [json::str $pos]
    }

    method undo {} {
        if {[llength $undoStack] == 0} {
            return [json::str false]
        }
        lappend redoStack [list $buf $pos]
        set snap [lindex $undoStack end]
        set undoStack [lrange $undoStack 0 end-1]
        lassign $snap buf pos
        set selStart -1
        set selEnd -1
        return [json::str true]
    }

    method redo {} {
        if {[llength $redoStack] == 0} {
            return [json::str false]
        }
        lappend undoStack [list $buf $pos]
        set snap [lindex $redoStack end]
        set redoStack [lrange $redoStack 0 end-1]
        lassign $snap buf pos
        set selStart -1
        set selEnd -1
        return [json::str true]
    }

    method select {start end} {
        if {$start < 0 || $end < 0 || $start > $end || $end > [string length $buf]} {
            return [json::str invalid_request]
        }
        set selStart $start
        set selEnd $end
        return [json::str true]
    }

    method cut {} {
        if {$selStart < 0 || $selStart == $selEnd} {
            return [json::str invalid_request]
        }
        set text [string range $buf $selStart [expr {$selEnd - 1}]]
        set buf [string range $buf 0 [expr {$selStart - 1}]][string range $buf $selEnd end]
        set clip $text
        set pos $selStart
        set selStart -1
        set selEnd -1
        return [json::str $text]
    }

    method copy_sel {} {
        if {$selStart < 0 || $selStart == $selEnd} {
            return [json::str invalid_request]
        }
        set clip [string range $buf $selStart [expr {$selEnd - 1}]]
        return [json::str $clip]
    }

    method paste {} {
        if {$clip eq ""} {
            return [json::str invalid_request]
        }
        set at $pos
        set buf [string range $buf 0 [expr {$at - 1}]]$clip[string range $buf $at end]
        set pos [expr {$at + [string length $clip]}]
        return [json::str [string length $buf]]
    }
}

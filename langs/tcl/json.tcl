# Tiny JSON encode/decode for the honepad trace schema.
# Enough for objects, arrays, strings, numbers, booleans, and null.
# Typed values use a leading tag so Tcl strings and numbers stay distinct.

namespace eval json {
    variable true [list ::json::T]
    variable false [list ::json::F]
    variable null [list ::json::Z]
    variable _text
    variable _i
    variable _n
}

proc json::str {s} {
    return [list ::json::S $s]
}

proc json::num {n} {
    return [list ::json::N $n]
}

proc json::array {items} {
    return [list ::json::A $items]
}

proc json::obj {args} {
    if {[llength $args] == 1} {
        set args [lindex $args 0]
    }
    return [list ::json::O $args]
}

proc json::_tag {v} {
    if {[llength $v] >= 1} {
        set head [lindex $v 0]
        if {[string match ::json::* $head]} {
            return $head
        }
    }
    return ""
}

proc json::native {v} {
    switch -exact -- [json::_tag $v] {
        ::json::S { return [lindex $v 1] }
        ::json::N { return [lindex $v 1] }
        ::json::T { return 1 }
        ::json::F { return 0 }
        ::json::Z { return "" }
        ::json::A {
            set out {}
            foreach item [lindex $v 1] {
                lappend out [json::native $item]
            }
            return $out
        }
        ::json::O {
            set out [dict create]
            foreach {k item} [lindex $v 1] {
                dict set out $k [json::native $item]
            }
            return $out
        }
        default { return $v }
    }
}

proc json::_encode_string {s} {
    set out {"}
    set n [string length $s]
    for {set i 0} {$i < $n} {incr i} {
        set c [string index $s $i]
        switch -exact -- $c {
            "\"" { append out {\"} }
            "\\" { append out {\\} }
            "\b" { append out {\b} }
            "\f" { append out {\f} }
            "\n" { append out {\n} }
            "\r" { append out {\r} }
            "\t" { append out {\t} }
            default {
                set b [scan $c %c]
                if {$b < 32} {
                    append out [format {\u%04x} $b]
                } else {
                    append out $c
                }
            }
        }
    }
    append out {"}
    return $out
}

proc json::_encode_number {n} {
    if {![string is double -strict $n]} {
        error "cannot encode non-numeric $n"
    }
    if {![string is integer -strict $n]} {
        return $n
    }
    if {[catch {expr {entier($n)}} w]} {
        return $n
    }
    return $w
}

proc json::encode {value} {
    switch -exact -- [json::_tag $value] {
        ::json::T { return true }
        ::json::F { return false }
        ::json::Z { return null }
        ::json::S { return [json::_encode_string [lindex $value 1]] }
        ::json::N { return [json::_encode_number [lindex $value 1]] }
        ::json::A {
            set parts {}
            foreach item [lindex $value 1] {
                lappend parts [json::encode $item]
            }
            return "\[[join $parts ,]\]"
        }
        ::json::O {
            set parts {}
            foreach {k item} [lindex $value 1] {
                lappend parts "[json::_encode_string $k]:[json::encode $item]"
            }
            return "\{[join $parts ,]\}"
        }
    }
    if {$value eq ""} {
        return {""}
    }
    if {[string is integer -strict $value]} {
        return [json::_encode_number $value]
    }
    if {[string is double -strict $value]} {
        return $value
    }
    return [json::_encode_string $value]
}

proc json::_peek {} {
    variable _text
    variable _i
    return [string index $_text $_i]
}

proc json::_skip {} {
    variable _text
    variable _i
    variable _n
    while {$_i < $_n && [string is space -strict [string index $_text $_i]]} {
        incr _i
    }
}

proc json::_parse_string {} {
    variable _text
    variable _i
    variable _n
    incr _i
    set parts {}
    while {$_i < $_n} {
        set c [string index $_text $_i]
        if {$c eq {"}} {
            incr _i
            return $parts
        }
        if {$c eq "\\"} {
            set nxt [string index $_text [expr {$_i + 1}]]
            if {$nxt eq "u"} {
                set hex [string range $_text [expr {$_i + 2}] [expr {$_i + 5}]]
                append parts [format %c [scan $hex %x]]
                incr _i 6
            } else {
                switch -exact -- $nxt {
                    "\"" { append parts {"} }
                    "\\" { append parts "\\" }
                    "/" { append parts "/" }
                    b { append parts "\b" }
                    f { append parts "\f" }
                    n { append parts "\n" }
                    r { append parts "\r" }
                    t { append parts "\t" }
                    default { append parts $nxt }
                }
                incr _i 2
            }
        } else {
            append parts $c
            incr _i
        }
    }
    error "unterminated string"
}

proc json::_parse_number {} {
    variable _text
    variable _i
    variable _n
    set start $_i
    if {[json::_peek] eq "-"} {
        incr _i
    }
    while {$_i < $_n && [string match {[0-9]} [string index $_text $_i]]} {
        incr _i
    }
    if {[json::_peek] eq "."} {
        incr _i
        while {$_i < $_n && [string match {[0-9]} [string index $_text $_i]]} {
            incr _i
        }
    }
    set exp [json::_peek]
    if {$exp eq "e" || $exp eq "E"} {
        incr _i
        set sign [json::_peek]
        if {$sign eq "+" || $sign eq "-"} {
            incr _i
        }
        while {$_i < $_n && [string match {[0-9]} [string index $_text $_i]]} {
            incr _i
        }
    }
    set raw [string range $_text $start [expr {$_i - 1}]]
    return [json::num $raw]
}

proc json::_parse_array {} {
    variable _i
    incr _i
    json::_skip
    if {[json::_peek] eq {]}} {
        incr _i
        return [json::array {}]
    }
    set arr {}
    while {1} {
        lappend arr [json::_parse_value]
        json::_skip
        set c [json::_peek]
        if {$c eq {]}} {
            incr _i
            return [json::array $arr]
        }
        if {$c ne ","} {
            error "expected comma or ]"
        }
        incr _i
        json::_skip
    }
}

proc json::_parse_object {} {
    variable _i
    incr _i
    json::_skip
    if {[json::_peek] eq "\}"} {
        incr _i
        return [json::obj {}]
    }
    set obj {}
    while {1} {
        if {[json::_peek] ne {"}} {
            error "expected string key"
        }
        set key [json::_parse_string]
        json::_skip
        if {[json::_peek] ne ":"} {
            error "expected colon"
        }
        incr _i
        json::_skip
        lappend obj $key [json::_parse_value]
        json::_skip
        set c [json::_peek]
        if {$c eq "\}"} {
            incr _i
            return [json::obj $obj]
        }
        if {$c ne ","} {
            error "expected comma or \}"
        }
        incr _i
        json::_skip
    }
}

proc json::_parse_value {} {
    variable _text
    variable _i
    json::_skip
    set c [json::_peek]
    if {$c eq {"}} {
        return [json::str [json::_parse_string]]
    }
    if {$c eq "\{"} {
        return [json::_parse_object]
    }
    if {$c eq {[}} {
        return [json::_parse_array]
    }
    if {$c eq "-" || [string match {[0-9]} $c]} {
        return [json::_parse_number]
    }
    if {[string range $_text $_i [expr {$_i + 3}]] eq "true"} {
        incr _i 4
        return $::json::true
    }
    if {[string range $_text $_i [expr {$_i + 4}]] eq "false"} {
        incr _i 5
        return $::json::false
    }
    if {[string range $_text $_i [expr {$_i + 3}]] eq "null"} {
        incr _i 4
        return $::json::null
    }
    error "unexpected token at $_i"
}

proc json::decode {text} {
    variable _text
    variable _i
    variable _n
    set _text $text
    set _i 0
    set _n [string length $text]
    set value [json::_parse_value]
    json::_skip
    if {$_i < $_n} {
        error "trailing data"
    }
    return $value
}

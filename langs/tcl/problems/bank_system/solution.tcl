oo::class create Simulation {
    variable accounts payment_counter pending_cashbacks
    constructor {} {
        set accounts [dict create]
        set payment_counter 0
        set pending_cashbacks [list]
    }

    method process_cashbacks {timestamp} {
        while {[llength $pending_cashbacks] > 0 && \
                [lindex $pending_cashbacks 0 0] <= $timestamp} {
            set row [lindex $pending_cashbacks 0]
            set pending_cashbacks [lrange $pending_cashbacks 1 end]
            lassign $row cb_timestamp account_id amount payment_id
            if {![dict exists $accounts $account_id]} {
                continue
            }
            set account [dict get $accounts $account_id]
            dict incr account balance $amount
            dict set account payments $payment_id CASHBACK_RECEIVED
            dict lappend account balance_history [list $cb_timestamp [dict get $account balance]]
            dict set accounts $account_id $account
        }
    }

    method create_account {timestamp account_id} {
        my process_cashbacks $timestamp
        if {[dict exists $accounts $account_id]} {
            return $::json::false
        }
        dict set accounts $account_id [dict create \
            account_id $account_id \
            balance 0 \
            outgoing 0 \
            payments [dict create] \
            created_at $timestamp \
            balance_history [list [list $timestamp 0]]]
        return $::json::true
    }

    method deposit {timestamp account_id amount} {
        my process_cashbacks $timestamp
        if {![dict exists $accounts $account_id]} {
            return $::json::null
        }
        set account [dict get $accounts $account_id]
        dict incr account balance $amount
        dict lappend account balance_history [list $timestamp [dict get $account balance]]
        dict set accounts $account_id $account
        return [dict get $account balance]
    }

    method transfer {timestamp source_account_id target_account_id amount} {
        my process_cashbacks $timestamp
        if {![dict exists $accounts $source_account_id] || \
                ![dict exists $accounts $target_account_id]} {
            return $::json::null
        }
        if {$source_account_id eq $target_account_id} {
            return $::json::null
        }
        set source [dict get $accounts $source_account_id]
        if {[dict get $source balance] < $amount} {
            return $::json::null
        }
        set target [dict get $accounts $target_account_id]
        dict incr source balance [expr {-$amount}]
        dict incr source outgoing $amount
        dict incr target balance $amount
        dict lappend source balance_history [list $timestamp [dict get $source balance]]
        dict lappend target balance_history [list $timestamp [dict get $target balance]]
        dict set accounts $source_account_id $source
        dict set accounts $target_account_id $target
        return [dict get $source balance]
    }

    method top_spenders {timestamp n} {
        my process_cashbacks $timestamp
        set pairs {}
        dict for {account_id account} $accounts {
            lappend pairs [list [dict get $account outgoing] $account_id]
        }
        set pairs [lsort -index 1 $pairs]
        set pairs [lsort -integer -decreasing -index 0 $pairs]
        if {[llength $pairs] > $n} {
            set pairs [lrange $pairs 0 [expr {$n - 1}]]
        }
        set result {}
        foreach row $pairs {
            lassign $row outgoing account_id
            lappend result [format {%s(%d)} $account_id $outgoing]
        }
        return [json::array $result]
    }

    method pay {timestamp account_id amount} {
        my process_cashbacks $timestamp
        if {![dict exists $accounts $account_id]} {
            return $::json::null
        }
        set account [dict get $accounts $account_id]
        if {[dict get $account balance] < $amount} {
            return $::json::null
        }
        dict incr account balance [expr {-$amount}]
        dict incr account outgoing $amount
        incr payment_counter
        set payment_id "payment$payment_counter"
        dict set account payments $payment_id IN_PROGRESS
        dict lappend account balance_history [list $timestamp [dict get $account balance]]
        dict set accounts $account_id $account
        set cashback_amount [expr {$amount * 2 / 100}]
        lappend pending_cashbacks [list \
            [expr {$timestamp + 24 * 60 * 60 * 1000}] \
            $account_id $cashback_amount $payment_id]
        return [json::str $payment_id]
    }

    method get_payment_status {timestamp account_id payment} {
        my process_cashbacks $timestamp
        if {![dict exists $accounts $account_id]} {
            return $::json::null
        }
        set account [dict get $accounts $account_id]
        if {![dict exists $account payments $payment]} {
            return $::json::null
        }
        return [json::str [dict get $account payments $payment]]
    }

    method merge_accounts {timestamp account_id_1 account_id_2} {
        my process_cashbacks $timestamp
        if {$account_id_1 eq $account_id_2} {
            return $::json::false
        }
        if {![dict exists $accounts $account_id_1] || \
                ![dict exists $accounts $account_id_2]} {
            return $::json::false
        }
        set account1 [dict get $accounts $account_id_1]
        set account2 [dict get $accounts $account_id_2]
        dict incr account1 balance [dict get $account2 balance]
        dict incr account1 outgoing [dict get $account2 outgoing]
        dict for {payment_id status} [dict get $account2 payments] {
            dict set account1 payments $payment_id $status
        }
        foreach row [dict get $account2 balance_history] {
            dict lappend account1 balance_history $row
        }
        set history [lsort -integer -index 0 [dict get $account1 balance_history]]
        dict set account1 balance_history $history
        if {[dict get $account2 created_at] < [dict get $account1 created_at]} {
            dict set account1 created_at [dict get $account2 created_at]
        }
        dict lappend account1 balance_history [list $timestamp [dict get $account1 balance]]
        dict set accounts $account_id_1 $account1
        set next {}
        foreach cb $pending_cashbacks {
            if {[lindex $cb 1] eq $account_id_2} {
                lset cb 1 $account_id_1
            }
            lappend next $cb
        }
        set pending_cashbacks $next
        dict unset accounts $account_id_2
        return $::json::true
    }

    method get_balance {timestamp account_id time_at} {
        my process_cashbacks $timestamp
        if {![dict exists $accounts $account_id]} {
            return $::json::null
        }
        set account [dict get $accounts $account_id]
        if {$time_at < [dict get $account created_at]} {
            return $::json::null
        }
        set result $::json::null
        foreach row [dict get $account balance_history] {
            if {[lindex $row 0] > $time_at} {
                break
            }
            set result [lindex $row 1]
        }
        return $result
    }
}

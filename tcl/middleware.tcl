# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2024 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

namespace eval ::tratelimit::middleware {
    variable config {
        window_millis 60000
        limit 100
        store valkeystore
    }

    array set global_limits {}
    array set route_limits {}
}

proc ::tratelimit::middleware::init {config_dict} {
    variable config
    variable store
    variable global_limits
    variable route_limits

    set config [dict merge $config $config_dict]

    dict for {store store_config} [dict get $config store] {
        ${store}::init $store_config
    }

    array set global_limits [dict get $config global_limits]
    array set route_limits [dict get $config route_limits]
}

proc ::tratelimit::middleware::rate_limit {config key current_time error_resVar} {
    variable store

    set window_millis [dict get $config window_millis]
    set limit [dict get $config limit]

    set window_start [expr { $current_time - $window_millis }]
    set requests_made [${store}::get_requests_made $key $window_start $current_time]
    if { $requests_made >= $limit } {
        upvar $error_resVar error_res
        set error_res [::twebserver::build_response 429 text/plain "Too Many Requests"]
        set error_res [::twebserver::add_header $error_res "Retry-After" [expr { $window_millis / 1000 }]]

        return 1
    }

    puts key=$key,requests_made=$requests_made,limit=$limit
    ${store}::add_request $key $window_start $current_time

    return 0
}

proc ::tratelimit::middleware::enter { ctx req } {
    variable global_limits
    variable route_limits

    set current_time [clock milliseconds]

    set addr [dict get $ctx addr]
    set session_id ""
    if { [dict exists $req loggedin] } {
        set session_id [dict get $req session id]
    }

    # check global limits by ip address
    if { [info exists global_limits(by_ip)] } {
        set key "__RL__/__GLOBAL__/ip/$addr"
        if { [rate_limit $global_limits(by_ip) $key $current_time error_res] } {
            return -code error -options $error_res
        }
    }
    return $req

    # check global limits by session
    if { $session_id ne {} && [info exists global_limits(by_session)] } {
        set key "__RL__/__GLOBAL__/sid/$session_id"
        if { [rate_limit $global_limits(by_session) $key $current_time error_res] } {
            return -code error -options $error_res
        }
    }

    # check route limit by ip address
    set route_name [dict get $ctx route_name]
    if { [info exists route_limits($route_name)] } {
        array set given_route_limits $route_limits($route_name)

        if { [info exists given_route_limits(by_ip)] } {
            set route_key "__RL__/${route_name}/ip/$addr"
            if { [rate_limit $given_route_limits(by_ip) $route_key $current_time error_res] } {
                return -code error -options $error_res
            }
        }

        if { $session_id ne {} && [info exists given_route_limits(by_session)] } {
            set route_key "__RL__/${route_name}/sid/$session_id"
            if { [rate_limit $given_route_limits(by_session) $route_key $current_time error_res] } {
                return -code error -options $error_res
            }
        }
    }

    return $req
}

proc ::tratelimit::middleware::leave { ctx req res } {
    return $res
}
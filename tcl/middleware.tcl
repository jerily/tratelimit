# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2024 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

namespace eval ::tratelimit::middleware {
    variable config {
        window_millis 60000
        limit 100
        store valkeystore
    }

    array set routes {}
}

proc ::tratelimit::middleware::init {config_dict} {
    variable config
    variable store
    variable window_millis
    variable limit
    variable routes

    set config [dict merge $config $config_dict]

    dict for {store store_config} [dict get $config store] {
        ${store}::init $store_config
    }

    set window_millis [dict get $config window_millis]
    set limit [dict get $config limit]
    array set routes [dict get $config routes]
}

proc ::tratelimit::middleware::enter { ctx req } {
    variable store
    variable window_millis
    variable limit
    variable routes

    set current_time [clock milliseconds]

    set addr [dict get $ctx addr]

    # check global limit by ip address
    set key "__RL__/__GLOBAL__/ip/$addr"
    set window_start [expr { $current_time - $window_millis }]
    set requests_made [${store}::get_requests_made $key $window_start $current_time]
    if { $requests_made >= $limit } {
        set res [::twebserver::build_response 429 text/plain "Too Many Requests"]
        set res [::twebserver::add_header $res "Retry-After" [expr { $window_millis / 1000 }]]
        return -code error -options $res
    }

    puts requests_made=$requests_made,limit=$limit
    ${store}::add_request $key $window_start $current_time

    # check route limit
    set route_name [dict get $ctx route_name]
    if { [info exists routes($route_name)] } {
        set route_config $routes($route_name)
        set route_window_millis [dict get $route_config window_millis]
        set route_limit [dict get $route_config limit]

        set route_key "__RL__/${route_name}/ip/$addr"
        set route_window_start [expr { $current_time - $route_window_millis }]
        set route_requests_made [${store}::get_requests_made $route_key $route_window_start $current_time]
        if { $route_requests_made >= $route_limit } {
            #puts route_limit_exceeded,$route_requests_made>=$route_limit
            set res [::twebserver::build_response 429 text/plain "Too Many Requests"]
            set res [::twebserver::add_header $res "Retry-After" [expr { $route_window_millis / 1000 }]]
            return -code error -options $res
        }

        puts route=$route_name,route_requests_made=$route_requests_made,route_limit=$route_limit
        ${store}::add_request $route_key $route_window_start $current_time

    }

    return $req
}

proc ::tratelimit::middleware::leave { ctx req res } {
    return $res
}
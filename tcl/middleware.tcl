# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2024 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

namespace eval ::tratelimit::middleware {
    variable config {
        window_millis 60000
        limit 100
        store valkeystore
    }
}

proc ::tratelimit::middleware::init {config_dict} {
    variable config
    variable store
    variable window_millis
    variable limit

    set config [dict merge $config $config_dict]

    dict for {store store_config} [dict get $config store] {
        ${store}::init $store_config
    }

    set window_millis [dict get $config window_millis]
    set limit [dict get $config limit]
}

proc ::tratelimit::middleware::enter { ctx req } {
    variable store
    variable window_millis
    variable limit

    set current_time [clock milliseconds]
    set window_start [expr { $current_time - $window_millis }]

    set addr [dict get $ctx addr]
    set key "ip:$addr"
    set requests_made [${store}::get_requests_made $key $window_start $current_time]
    if { $requests_made >= $limit } {
        set res [::twebserver::build_response 429 text/plain "Too Many Requests"]
        set res [::twebserver::add_header $res "Retry-After" [expr { $window_millis / 1000 }]]
        return -code error -options $res
    }

    puts requests_made=$requests_made

    ${store}::add_request $key $window_start $current_time
    return $req
}

proc ::tratelimit::middleware::leave { ctx req res } {
    return $res
}
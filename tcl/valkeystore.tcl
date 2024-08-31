namespace eval ::tratelimit::valkeystore {}

proc ::tratelimit::valkeystore::init_main {output_configVar config} {
    upvar $output_configVar output_config

    set outconf [list \
        host [dict get $config host] \
        port [dict get $config port]]

    if {[dict exists $config password]} {
        lappend outconf password [dict get $config password]
    }

    dict set output_config store "valkeystore" $outconf

}

namespace eval ::tratelimit::middleware::valkeystore {
    variable valkey_client
    variable config {
        host "localhost"
        port 6379
    }
}

proc ::tratelimit::middleware::valkeystore::init {config_dict} {
    variable valkey_client
    variable config

    package require valkey

    set config [dict merge $config $config_dict]
    set host [dict get $config host]
    set port [dict get $config port]
    set vk_args {}
    if {[dict exists $config password]} {
        set password [dict get $config password]
        set vk_args [list -password $password]
    }

    set valkey_client [valkey -host $host -port $port {*}${vk_args}]

}

proc ::tratelimit::middleware::valkeystore::shutdown {} {
    variable valkey_client
    #$valkey_client DEL history_events
    $valkey_client destroy
    return
}

proc ::tratelimit::valkeystore::shutdown_main {} {}

proc ::tratelimit::middleware::valkeystore::get_requests_made {key start_millis end_millis} {
    variable valkey_client

    set requests_made [$valkey_client ZCOUNT $key $start_millis $end_millis]
    if { $requests_made eq {} } {
        return 0
    }

    return $requests_made
}

proc ::tratelimit::middleware::valkeystore::add_request {key window_start current_time} {
    variable valkey_client

    $valkey_client ZADD $key $current_time $current_time
    $valkey_client ZREMRANGEBYSCORE $key -inf $window_start
    return
}
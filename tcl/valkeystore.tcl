namespace eval ::tratelimit::valkeystore {}

proc ::tratelimit::valkeystore::init_main {output_configVar config} {
    upvar $output_configVar output_config

    set outconf [list \
        host [dict get $config host] \
        port [dict get $config port]]

    foreach key {ssl username password ssl_ca_file ssl_cert_file ssl_key_file timeout} {
        if {[dict exists $config $key]} {
            lappend outconf $key [dict get $config $key]
        }
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

    package require valkey 1.0.1

    set config [dict merge $config $config_dict]
    set host [dict get $config host]
    set port [dict get $config port]
    set vk_args {}
    if {[dict exists $config ssl] && [dict get $config ssl]} {
        lappend vk_args -ssl
    }
    foreach key {username password ssl_ca_file ssl_cert_file ssl_key_file timeout} {
        if {[dict exists $config $key]} {
            lappend vk_args -$key [dict get $config $key]
        }
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

# Use the server clock and one atomic script for all workers. Random members
# preserve every request, including multiple arrivals in the same millisecond.
proc ::tratelimit::middleware::valkeystore::consume {key window_millis limit} {
    variable valkey_client
    set member [binary encode hex [::twebserver::random_bytes 16]]
    $valkey_client EVAL {
        local clock = redis.call('TIME')
        local now = tonumber(clock[1]) * 1000 + math.floor(tonumber(clock[2]) / 1000)
        local window = tonumber(ARGV[1])
        redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now - window)
        if redis.call('ZCARD', KEYS[1]) >= tonumber(ARGV[2]) then
            return 0
        end
        redis.call('ZADD', KEYS[1], now, ARGV[3])
        redis.call('PEXPIRE', KEYS[1], window)
        return 1
    } 1 $key $window_millis $limit $member
}

proc ::tratelimit::middleware::valkeystore::get_requests_made {key start_millis end_millis} {
    variable valkey_client

    set requests_made [$valkey_client ZCOUNT $key ($start_millis $end_millis]
    if { $requests_made eq {} } {
        return 0
    }

    return $requests_made
}

proc ::tratelimit::middleware::valkeystore::add_request {key window_start current_time} {
    variable valkey_client

    set member [binary encode hex [::twebserver::random_bytes 16]]
    $valkey_client ZADD $key $current_time $member
    $valkey_client ZREMRANGEBYSCORE $key -inf $window_start
    $valkey_client PEXPIRE $key [expr {$current_time - $window_start}]
    return
}

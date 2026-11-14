# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2024 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

package require twebserver

set tratelimit_config {
    store {
        valkeystore {
            host "localhost"
            port 6379
            password "foobared"
        }
    }
    global_limits {
        by_ip {
            window_millis 10000
            limit 10
        }
        by_session {
            window_millis 60000
            limit 5
        }
    }
    route_limits {
        get_index {
            by_ip {
                window_millis 10000
                limit 10
            }
        }
        get_stats {
            by_ip {
                window_millis 10000
                limit 5
            }
        }
        get_catchall {
            by_ip {
                window_millis 10000
                limit 15
            }
        }
    }
}

set init_script {
    package require twebserver
    package require tratelimit
    package require tpathexp 1.2.0

    set config_dict [::twebserver::get_config_dict]

    ::tratelimit::init_middleware [dict get $config_dict tratelimit]

    set router [::tpathexp::router]
    ::tratelimit::mount $router
    foreach {path name handler} {
        / get_index get_index_handler
        /stats get_stats get_stats_handler
        /:path(.*) get_catchall get_catchall_handler
    } {
        $router add GET $path $handler -strict true \
            -enter_proc [list ::tratelimit::middleware::enter_route $name]
    }

    proc process_conn {ctx req} {
        dict set req method [dict get $req httpMethod]
        set res [$::router dispatch $req $ctx]
        ::twebserver::return_response [dict get $ctx conn] $res
    }

    proc get_stats_handler {req ctx params} {
        return [::twebserver::build_response 200 text/plain "This route allows five requests per ten seconds."]
    }

    proc get_index_handler {req ctx params} {
        set html "Hello [dict get $req path]<br /><br /><a href=\"/stats\">Stats</a>"
        set res [::twebserver::build_response 200 "text/html; charset=utf-8" $html]
        return $res
    }

    proc get_catchall_handler {req ctx params} {
        set html "Hello [dict get $req path]<br /><br />. Page Not Found."
        set res [::twebserver::build_response 404 "text/html; charset=utf-8" $html]
        return $res
    }

}

set config_dict [dict create \
    rootdir [file dirname [info script]] \
    gzip on \
    gzip_types [list text/html text/plain application/json] \
    gzip_min_length 8192 \
    conn_timeout_millis 10000 \
    tratelimit $tratelimit_config]

set server_handle [::twebserver::create_server $config_dict process_conn $init_script]
::twebserver::listen_server -http -num_threads 4 $server_handle 8080

puts "Server is running, go to http://localhost:8080/"

::twebserver::wait_signal
::twebserver::destroy_server $server_handle

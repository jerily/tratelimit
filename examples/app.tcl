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
    package require thtml

    ::thtml::init [dict create \
        debug 1 \
        cache 1 \
        rootdir [::twebserver::get_rootdir] \
        bundle_outdir [file join [::twebserver::get_rootdir] public bundle]]

    set config_dict [::twebserver::get_config_dict]

    ::tratelimit::init_middleware [dict get $config_dict tratelimit]

    ::twebserver::create_router -command_name process_conn router

    ::twebserver::add_middleware \
        -enter_proc ::tratelimit::middleware::enter \
        $router

    ::twebserver::add_route -name get_index $router GET "/" get_index_handler
    ::twebserver::add_route -name get_stats $router GET "/stats" get_stats_handler
    ::twebserver::add_route -name get_catchall $router GET "*" get_catchall_handler

    #interp alias {} process_conn {} $router

    proc get_stats_handler {ctx req} {
        set data [dict merge $req [list bundle_js_url_prefix "/bundle" bundle_css_url_prefix "/bundle"]]
        set html [::thtml::renderfile app.thtml $data]
        set res [::twebserver::build_response 200 "text/html; charset=utf-8" $html]
        return $res
    }

    proc get_index_handler {ctx req} {
        set html "Hello [dict get $req path]<br /><br /><a href=\"/stats\">Stats</a>"
        set res [::twebserver::build_response 200 "text/html; charset=utf-8" $html]
        return $res
    }

    proc get_catchall_handler {ctx req} {
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

set server_handle [::twebserver::create_server -with_router $config_dict process_conn $init_script]
::twebserver::listen_server -http -num_threads 4 $server_handle 8080

puts "Server is running, go to http://localhost:8080/"

::twebserver::wait_signal
::twebserver::destroy_server $server_handle
::treqmon::shutdown_main
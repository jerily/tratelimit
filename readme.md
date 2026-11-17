# tratelimit

Rate limiting middleware for [tpathexp](https://github.com/jerily/tpathexp) routers
and [twebserver](https://github.com/jerily/twebserver).

## Principles

Keep storage in the configured store; pass connection settings to valkey-tcl.

## Prerequisites

- [twebserver](https://github.com/jerily/twebserver) (version 1.47.53 and above)
- [valkey-tcl](https://github.com/jerily/valkey-tcl) (version 1.0.1 and above)
- [tpathexp](https://github.com/jerily/tpathexp) (version 1.2.0 and above)

## Installation

```bash
# It installs to /usr/local/lib
# To install elsewhere, change the prefix
# e.g. make install PREFIX=/path/to/install
make install
```

## Usage

The following are supported configuration options:

* **global_limits** - Global rate limits.
* **route_limits** - Limits keyed by route enter-hook names (or named routes in twebserver).
* **store** - The store to use together with its config. Default is "valkeystore".

Initialize once per worker, mount global middleware once per router, and attach
named limits when registering custom routes:

```tcl
package require tratelimit
::tratelimit::init_middleware $config
set router [::tpathexp::router]
::tratelimit::mount $router
$router add GET /stats stats_handler -strict true \
    -enter_proc [list ::tratelimit::middleware::enter_route get_stats]
# stats_handler receives request, context, and path parameters.
set response [$router dispatch {method GET path /stats} {addr 127.0.0.1}]
```

Global limits also apply to 404/405 responses. Route hooks enforce only that
route's limits, without counting global limits twice. Names absent from
`route_limits` have only global limits. Both scopes support `by_ip` (trusted
`context addr`) and `by_session` (`request session id`, when present). Mount
session middleware before rate limiting so the session is available. Existing
twebserver middleware uses `context route_name`. Rejections return HTTP 429 with
`Retry-After` through normal router response handling.

The Valkey store (1.1.1+) checks and records requests atomically using the
server clock, counts simultaneous arrivals separately, and expires idle buckets.
Its ACL must permit EVAL, TIME, ZREMRANGEBYSCORE, ZCARD, ZADD and PEXPIRE.
Custom shared stores should implement `consume key window_millis limit`, returning
1 only when the request was recorded. The older `get_requests_made` / `add_request`
interface remains available for single-interpreter stores, but is not atomic.

Mount treqmon before tratelimit to record rejected requests too.
The file-based scripts in `ttrek.json` run tests and the HTTP example with
`ttrek run -script test` and `ttrek run -script example`. Set `TCLSH` to select
your interpreter. The example needs Valkey configured as in `example/app.tcl`.

## Example Configuration

```tcl
    store {
        valkeystore {
            host "localhost"
            port 6379
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
```

## TLS

For `valkeystore`, set `ssl true`, `username` and `password`. Optional settings:
`ssl_ca_file`, `ssl_cert_file`, `ssl_key_file`, and `timeout` (milliseconds).
Build valkey-tcl and libvalkey with `-DENABLE_SSL=ON`.

## Security

### Surface

Valkey connections and stored request data.

### Protections

With `ssl true`, valkey-tcl verifies certificates and server identity, including reconnects.

### Pending

Configure TLS and credentials for your deployment.

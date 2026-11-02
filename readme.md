# tratelimit

Rate limiting middleware for [twebserver](https://github.com/jerily/twebserver).

## Principles

Keep storage in the configured store; pass connection settings to valkey-tcl.

## Prerequisites

- [twebserver](https://github.com/jerily/twebserver) (version 1.47.53 and above)
- [valkey-tcl](https://github.com/jerily/valkey-tcl) (version 1.0.1 and above)

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
* **route_limits** - Route rate limits. Makes use of named routes in twebserver.
* **store** - The store to use together with its config. Default is "valkeystore".

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

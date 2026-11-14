# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2024 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

namespace eval ::tratelimit {}

package require tpathexp 1.2.0
package require twebserver

proc ::tratelimit::mount {router} {
    $router add_middleware -enter_proc ::tratelimit::middleware::enter
}


proc ::tratelimit::init_middleware {config} {
    middleware::init $config
}

# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2024 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

package provide tratelimit 1.0.0

set dir [file dirname [info script]]

source [file join $dir tratelimit.tcl]
source [file join $dir middleware.tcl]
source [file join $dir valkeystore.tcl]

namespace eval ::tratelimit {
    variable __thtml__ [file join $::dir .. templates]
}
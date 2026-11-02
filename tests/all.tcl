package require tcltest
::tcltest::configure {*}$argv -testdir [file dirname [info script]]
exit [::tcltest::runAllTests]

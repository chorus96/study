#!/usr/bin/tclsh

namespace eval MyNamespace {
    variable myVar 10
    proc myProc {} {
        puts "Hello from MyNamespace"
    }
}

puts $MyNamespace::myVar
MyNamespace::myProc

puts [namespace current]
puts [namespace children ::]

if {[namespace exists MyNamespace]} {
    puts "MyNamespace exists"
}

namespace delete MyNamespace

namespace eval Outer {
    namespace eval Inner {
        variable innerVar 20
        proc innerProc {} {
            puts "Inner procedure"
        }
    }
}

puts $Outer::Inner::innerVar
Outer::Inner::innerProc

namespace eval MyNS {
    namespace export myCmd
    proc myCmd {} {
        puts "MyNS command"
    }
}

namespace import MyNS::myCmd
myCmd 

namespace eval MyNS {
    proc myProc {} {
        puts "MyNS procedure"
    }
}

namespace eval OtherNS {
    namespace path ::MyNS
    myProc
}

namespace eval MyNS {
    variable myVar 30
}

puts $MyNS::myVar

namespace eval MyNS {
    puts $myVar
}

namespace eval math {
    namespace export add subtract
    proc add {a b} {return [expr {$a + $b}]}
    proc subtract {a b} {return [expr {$a - $b}]}
    namespace ensemble create -command math -subcommands {add subtract}
}

puts [math::add 5 3]
puts [math::subtract 10 4]
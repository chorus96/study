#!/usr/bin/tclsh

# # 12장: 인자, argument

# ### 1. argc와 argv 개요

# TCL에서 `argc`와 `argv`는 스크립트에 전달된 명령줄 인자를 처리하는 데 사용되는 특별한 변수입니다.

# * `argc`: 인자의 개수 (argument count)
# * `argv`: 인자들의 리스트 (argument values)

# ### 2. argc 사용하기

# `argc`는 스크립트에 전달된 인자의 개수를 나타냅니다.

# ```tcl
# puts "Number of arguments: $argc"
# ```

# ### 3. argv 사용하기

# `argv`는 스크립트에 전달된 인자들의 리스트입니다.

# ```tcl
# puts "Arguments: $argv"
# puts "First argument: [lindex $argv 0]"
# puts "Second argument: [lindex $argv 1]"
# ```

# ### 4. argv0 변수

# `argv0`는 스크립트 이름 자체를 포함합니다.

# ```tcl
# puts "Script name: $argv0"
# ```

# ### 5. 명령줄 인자 처리 예제

# #### filename: argument.tcl

# ```tcl
# if {$argc < 2} {
#     puts "Usage: $argv0 <arg1> <arg2>"
#     exit 1
# }

# set arg1 [lindex $argv 0]
# set arg2 [lindex $argv 1]

# puts "Argument 1: $arg1"
# puts "Argument 2: $arg2"
# ```

# #### % tclsh argument.tcl 10 20

# Argument 1: 10

# Argument 2: 20

# #### 5.2 옵션 처리 예제

# ```tcl
# for {set i 0} {$i < $argc} {incr i} {
#     set arg [lindex $argv $i]
#     switch -glob -- $arg {
#         -v      {puts "Verbose mode on"}
#         -o*     {puts "Output file: [string range $arg 2 end]"}
#         --help  {puts "Help message"; exit 0}
#         default {puts "Unknown option: $arg"}
#     }
# }
# ```

# ###

#!/bin/tclsh
proc runtimer { seconds } {
set x 0
set timerstop 0
while {!$timerstop} {
incr x
after 1000
  if { ![ expr {$x % 60} ] } {
          set y [ expr $x / 60 ]
          puts "Timer: $y minutes elapsed"
  }
update
if {  [ vucomplete ] || $x eq $seconds } { set timerstop 1 }
    }
return
}
puts "SETTING CONFIGURATION"
dbset db mssqls
diset connection mssqls_server <sqlip>
#diset connection mssqls_linux_server <sqlip>
diset connection mssqls_tcp true
diset connection mssqls_port <sqlport>
diset connection mssqls_authentication sql
diset connection mssqls_odbc_driver {ODBC Driver 18 for SQL Server}
diset connection mssqls_uid <sqluser>
diset connection mssqls_pass <sqlpass>
diset tpcc mssqls_dbase <sqldb>

diset tpcc mssqls_total_iterations = 1000000
diset tpcc mssqls_driver timed
# Added key and think for more realistic workload
# diset tpcc mssqls_keyandthink true 
#Changed duration from 9 to 30
##also in the loop below - runtimer from 660 to 1800
diset tpcc mssqls_rampup <rampuptime>
diset tpcc mssqls_duration <testduration> 
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_timeprofile true

vuset logtotemp 1
tcset logtotemp 1
tcset timestamps 1

#Note. 1 user is logged as a Monitor user.
#Meaning 5 users against the tpcc is actually 6.
loadscript
puts "SEQUENCE STARTED"
foreach z { <userload> } {
puts "$z VU TEST"
vuset vu $z
vucreate
puts "TCOUNTER STARTED"
tcstart
tcstatus
vurun
#Runtimer, set in seconds, must exceed rampup + duration 660 = 11 min
#Rampup 1, Duration 9, 1 extra minute to capture TPM
runtimer <singleruntimeinsec>
vudestroy
after 5000
}
puts "TEST SEQUENCE COMPLETE"
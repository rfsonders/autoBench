#!/bin/tclsh
# maintainer: Sanjeev Ranjan

puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-C

#diset connection mssqls_server <sqlip>
diset connection mssqls_linux_server <sqlip>
diset connection mssqls_tcp true
diset connection mssqls_port <sqlport>
diset connection mssqls_linux_authent sql
diset connection mssqls_uid <sqluser>
diset connection mssqls_pass <sqlpass>
diset connection mssqls_linux_odbc {ODBC Driver 18 for SQL Server}
diset connection mssqls_encrypt_connection true
diset connection mssqls_trust_server_cert true

diset tpcc mssqls_dbase <sqldb>
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup <rampuptime>
diset tpcc mssqls_duration <testduration> 
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true
vuset logtotemp 1
tcset logtotemp 1
tcset timestamps 1

loadscript
puts "TEST STARTED"

foreach z { <userload> } {
puts "$z VU TEST"
vuset vu $z
vucreate
puts "TCOUNTER STARTED"
tcstart
tcstatus
vurun
runtimer <singleruntimeinsec>
vudestroy
after 5000
}
puts "TEST SEQUENCE COMPLETE"
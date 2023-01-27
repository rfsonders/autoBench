#!/bin/tclsh
# maintainer: Sanjeev Ranjan

puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-C

#diset connection mssqls_server 10.129.80.57
diset connection mssqls_linux_server 10.129.80.57
diset connection mssqls_tcp true
diset connection mssqls_port 1433
diset connection mssqls_linux_authent sql
diset connection mssqls_uid miadmin
diset connection mssqls_pass !!123abc
diset connection mssqls_linux_odbc {ODBC Driver 18 for SQL Server}
diset connection mssqls_encrypt_connection true
diset connection mssqls_trust_server_cert true

diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 1
diset tpcc mssqls_duration 2 
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true
vuset logtotemp 1
tcset logtotemp 1
tcset timestamps 1

loadscript
puts "TEST STARTED"

foreach z { 2 4 6 } {
puts "$z VU TEST"
vuset vu $z
vucreate
puts "TCOUNTER STARTED"
tcstart
tcstatus
vurun
runtimer 120
vudestroy
after 5000
}
puts "TEST SEQUENCE COMPLETE"
